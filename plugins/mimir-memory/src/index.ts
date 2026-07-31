import {
  spawn,
  type ChildProcessWithoutNullStreams,
} from "node:child_process";
import { randomUUID } from "node:crypto";
import { constants as fsConstants } from "node:fs";
import { open } from "node:fs/promises";
import { Type } from "typebox";
import {
  definePluginEntry,
  type OpenClawPluginDefinition,
} from "openclaw/plugin-sdk/plugin-entry";

const NODE_BINARY = "/usr/bin/node";
const SEARCH_SCRIPT =
  "/var/lib/openclaw/workspace/tools/memory/" +
  "mimir-semantic-search.mjs";
const SHADOW_EVALUATOR =
  "/var/lib/openclaw/workspace/tools/memory/" +
  "mimir-evidence-shadow-evaluate.mjs";
const SHADOW_LOG =
  "/var/log/openclaw/mimir-evidence-shadow.jsonl";

const EXECUTION_TIMEOUT_MS = 300_000;
const SHADOW_TIMEOUT_MS = 170_000;
const TERMINATION_GRACE_MS = 1_500;
const MAX_OUTPUT_LENGTH = 8 * 1024 * 1024;
const MAX_EVALUATOR_OUTPUT_LENGTH = 128 * 1024;
const MAX_LOG_BYTES = 20 * 1024 * 1024;
const MAX_QUEUE_LENGTH = 3;
const MAX_QUEUE_AGE_MS = 60_000;
const DROP_FLUSH_INTERVAL_MS = 30_000;

type SearchPayload = {
  query: string;
  model: string;
  dimensions: number;
  limit: number;
  min_similarity: number;
  result_count: number;
  results: unknown[];
};

type ShadowDiagnostic = {
  schema_version: number;
  shadow_only: true;
  observed_at: string;
  observation_id: string;
  decision: string;
  matched_scope: string;
  memory_key: string;
  top_similarity: number | null;
  candidate_count: number;
  query_chars: number;
  dropped_count: number;
  timing_ms: {
    embedding: number;
    postgresql: number;
    search_total: number;
    verifier: number;
    total: number;
  };
  reason: string;
};

type ShadowQueueItem = {
  query: string;
  receivedAt: string;
  receivedAtMs: number;
};

type DropAggregate = {
  count: number;
  maxQueryChars: number;
  firstObservedAt: string;
};

function isObject(
  value: unknown,
): value is Record<string, unknown> {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value)
  );
}

function createChildEnv(
  applicationName: string,
): NodeJS.ProcessEnv {
  return {
    HOME: "/var/lib/openclaw",
    USER: "openclaw",
    LOGNAME: "openclaw",
    PATH: "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    LANG: "C.UTF-8",
    LC_ALL: "C.UTF-8",
    PGHOST: "/run/postgresql",
    PGDATABASE: "mimir_memory",
    PGUSER: "mimir_search",
    PGAPPNAME: applicationName,
    PGCONNECT_TIMEOUT: "5",
    PGOPTIONS:
      "-c default_transaction_read_only=on " +
      "-c statement_timeout=60000 " +
      "-c lock_timeout=5000",
  };
}

function signalProcessTree(
  child: ChildProcessWithoutNullStreams,
  signal: NodeJS.Signals,
): void {
  if (child.pid !== undefined) {
    try {
      process.kill(-child.pid, signal);
      return;
    } catch {
      // O grupo já terminou ou a plataforma não oferece grupos POSIX.
    }
  }

  try {
    child.kill(signal);
  } catch {
    // O processo já terminou.
  }
}

function terminateChild(
  child: ChildProcessWithoutNullStreams,
): Promise<void> {
  if (
    child.exitCode !== null ||
    child.signalCode !== null
  ) {
    return Promise.resolve();
  }

  return new Promise((resolve) => {
    let settled = false;
    let killTimer: NodeJS.Timeout | undefined;
    let giveUpTimer: NodeJS.Timeout | undefined;

    const finish = () => {
      if (settled) {
        return;
      }

      settled = true;
      if (killTimer !== undefined) {
        clearTimeout(killTimer);
      }
      if (giveUpTimer !== undefined) {
        clearTimeout(giveUpTimer);
      }
      child.off("close", finish);
      resolve();
    };

    child.once("close", finish);
    signalProcessTree(child, "SIGTERM");

    killTimer = setTimeout(() => {
      signalProcessTree(child, "SIGKILL");
    }, TERMINATION_GRACE_MS);

    giveUpTimer = setTimeout(
      finish,
      TERMINATION_GRACE_MS + 2_000,
    );
  });
}

function validateSearchPayload(
  value: unknown,
): SearchPayload {
  if (!isObject(value)) {
    throw new Error(
      "A consulta semântica não retornou um objeto JSON.",
    );
  }

  if (
    typeof value.query !== "string" ||
    typeof value.model !== "string" ||
    typeof value.dimensions !== "number" ||
    typeof value.limit !== "number" ||
    typeof value.min_similarity !== "number" ||
    typeof value.result_count !== "number" ||
    !Array.isArray(value.results)
  ) {
    throw new Error(
      "A consulta semântica retornou uma estrutura inválida.",
    );
  }

  if (value.dimensions !== 768) {
    throw new Error(
      `Embedding retornado com ${value.dimensions} dimensões.`,
    );
  }

  if (
    !Number.isInteger(value.limit) ||
    value.limit < 1 ||
    value.limit > 10 ||
    value.result_count !== value.results.length ||
    value.results.length > value.limit
  ) {
    throw new Error(
      "A quantidade declarada de resultados é inconsistente.",
    );
  }

  return {
    query: value.query,
    model: value.model,
    dimensions: value.dimensions,
    limit: value.limit,
    min_similarity: value.min_similarity,
    result_count: value.result_count,
    results: value.results,
  };
}

function runSemanticSearch(
  query: string,
  limit: number,
  minSimilarity: number,
): Promise<SearchPayload> {
  return new Promise((resolve, reject) => {
    const child = spawn(
      NODE_BINARY,
      [
        SEARCH_SCRIPT,
        "--json",
        "--limit",
        String(limit),
        "--min-similarity",
        String(minSimilarity),
      ],
      {
        shell: false,
        detached: true,
        stdio: ["pipe", "pipe", "pipe"],
        env: createChildEnv("mimir-memory-plugin"),
      },
    );

    let stdout = "";
    let stderr = "";
    let timedOut = false;
    let outputExceeded = false;
    let settled = false;

    const settle = (
      callback: () => void,
    ) => {
      if (settled) {
        return;
      }
      settled = true;
      callback();
    };

    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");

    child.stdout.on("data", (chunk: string) => {
      if (
        stdout.length + chunk.length >
        MAX_OUTPUT_LENGTH
      ) {
        outputExceeded = true;
        void terminateChild(child);
        return;
      }

      stdout += chunk;
    });

    child.stderr.on("data", (chunk: string) => {
      if (
        stderr.length + chunk.length <=
        MAX_OUTPUT_LENGTH
      ) {
        stderr += chunk;
      }
    });

    const timer = setTimeout(() => {
      timedOut = true;
      void terminateChild(child);
    }, EXECUTION_TIMEOUT_MS);

    child.on("error", (error) => {
      clearTimeout(timer);
      settle(() => {
        reject(
          new Error(
            `Não foi possível iniciar a consulta: ${error.message}`,
          ),
        );
      });
    });

    child.on("close", (code, signal) => {
      clearTimeout(timer);
      settle(() => {
        if (timedOut) {
          reject(
            new Error(
              "A consulta semântica excedeu 300 segundos.",
            ),
          );
          return;
        }

        if (outputExceeded) {
          reject(
            new Error(
              "A consulta semântica excedeu o limite de saída.",
            ),
          );
          return;
        }

        if (code !== 0) {
          const diagnostic =
            stderr.trim() ||
            stdout.trim() ||
            `código=${String(code)}, sinal=${String(signal)}`;

          reject(
            new Error(
              `Consulta semântica encerrada com erro: ${diagnostic}`,
            ),
          );
          return;
        }

        const text = stdout.trim();

        if (!text) {
          reject(
            new Error(
              "A consulta semântica não retornou conteúdo.",
            ),
          );
          return;
        }

        try {
          const parsed: unknown = JSON.parse(text);
          resolve(validateSearchPayload(parsed));
        } catch (error) {
          const message =
            error instanceof Error
              ? error.message
              : String(error);

          reject(
            new Error(
              `Não foi possível interpretar a resposta: ${message}`,
            ),
          );
        }
      });
    });

    child.stdin.on("error", (error) => {
      const errorCode =
        (error as NodeJS.ErrnoException).code;

      if (errorCode !== "EPIPE") {
        void terminateChild(child);
      }
    });

    child.stdin.end(query, "utf8");
  });
}

const allowedDecisions = new Set([
  "supported",
  "no_evidence",
  "blocked_sensitive",
  "invalid_output",
  "error",
  "dropped",
]);

const allowedScopes = new Set([
  "not_present",
  "central_agent_name",
  "project_title",
  "primary_llm",
  "execution_platform",
  "critical_change_requirements",
]);

const scopeToKey: Record<string, string> = {
  central_agent_name: "projeto.identidade.nome",
  project_title: "projeto.identidade.titulo",
  primary_llm: "projeto.modelos.principal",
  execution_platform: "projeto.plataforma.execucao",
  critical_change_requirements:
    "projeto.seguranca.principio",
};

const allowedKeys = new Set([
  "",
  ...Object.values(scopeToKey),
]);

const allowedReasons = new Set([
  "",
  "qualifier_blocked",
  "relation_blocked",
  "deterministic_scope_conflict",
  "mapped_key_not_candidate",
  "search_json_invalid",
  "semantic_search_failed",
  "verifier_unavailable",
  "verifier_output_too_large",
  "outer_json_invalid",
  "finish_reason_not_stop",
  "inner_json_invalid",
  "properties_invalid",
  "requested_scope_invalid",
  "supporting_key_invalid",
  "candidate_content_empty",
  "evaluator_timeout",
  "evaluator_output_invalid",
  "evaluator_failed",
  "queue_full",
  "queue_expired",
  "gateway_stopping",
]);

function boundedNumber(
  value: unknown,
  minimum: number,
  maximum: number,
): number {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value)
  ) {
    return 0;
  }

  const bounded = Math.min(
    maximum,
    Math.max(minimum, value),
  );

  return Math.round(bounded * 1000) / 1000;
}

function normalizeObservedAt(value: string): string {
  const parsed = Date.parse(value);
  return Number.isFinite(parsed)
    ? new Date(parsed).toISOString()
    : new Date().toISOString();
}

function sanitizeShadowDiagnostic(
  value: unknown,
  observedAt = new Date().toISOString(),
): ShadowDiagnostic {
  const input = isObject(value) ? value : {};
  const timing =
    isObject(input.timing_ms) ? input.timing_ms : {};

  let decision =
    typeof input.decision === "string" &&
    allowedDecisions.has(input.decision)
      ? input.decision
      : "error";

  let matchedScope =
    typeof input.matched_scope === "string" &&
    allowedScopes.has(input.matched_scope)
      ? input.matched_scope
      : "not_present";

  let memoryKey =
    typeof input.memory_key === "string" &&
    allowedKeys.has(input.memory_key)
      ? input.memory_key
      : "";

  let reason =
    typeof input.reason === "string" &&
    allowedReasons.has(input.reason)
      ? input.reason
      : "evaluator_output_invalid";

  let similarity =
    typeof input.top_similarity === "number" &&
    Number.isFinite(input.top_similarity)
      ? boundedNumber(input.top_similarity, 0, 1)
      : null;

  let candidateCount = Math.trunc(
    boundedNumber(input.candidate_count, 0, 5),
  );
  let droppedCount = Math.trunc(
    boundedNumber(input.dropped_count, 0, 1_000_000),
  );

  const supportedCombination =
    decision === "supported" &&
    matchedScope !== "not_present" &&
    scopeToKey[matchedScope] === memoryKey &&
    similarity !== null &&
    reason === "";

  const simpleCombination =
    decision !== "supported" &&
    matchedScope === "not_present" &&
    memoryKey === "";

  const droppedCombination =
    decision !== "dropped" || droppedCount > 0;

  const validReasonByDecision: Record<string, Set<string>> = {
    supported: new Set([""]),
    no_evidence: new Set([
      "",
      "qualifier_blocked",
      "relation_blocked",
      "deterministic_scope_conflict",
      "mapped_key_not_candidate",
      "supporting_key_invalid",
    ]),
    blocked_sensitive: new Set([""]),
    invalid_output: new Set([
      "outer_json_invalid",
      "finish_reason_not_stop",
      "inner_json_invalid",
      "properties_invalid",
      "requested_scope_invalid",
      "supporting_key_invalid",
      "candidate_content_empty",
      "search_json_invalid",
    ]),
    error: new Set([
      "search_json_invalid",
      "semantic_search_failed",
      "verifier_unavailable",
      "verifier_output_too_large",
      "outer_json_invalid",
      "evaluator_timeout",
      "evaluator_output_invalid",
      "evaluator_failed",
    ]),
    dropped: new Set([
      "queue_full",
      "queue_expired",
      "gateway_stopping",
    ]),
  };

  const reasonCombination =
    validReasonByDecision[decision]?.has(reason) === true;

  if (
    (!supportedCombination && !simpleCombination) ||
    !droppedCombination ||
    !reasonCombination
  ) {
    decision = "error";
    matchedScope = "not_present";
    memoryKey = "";
    similarity = null;
    candidateCount = 0;
    droppedCount = 0;
    reason = "evaluator_output_invalid";
  }

  if (decision === "blocked_sensitive") {
    similarity = null;
    candidateCount = 0;
    droppedCount = 0;
  } else if (decision !== "dropped") {
    droppedCount = 0;
  }

  const normalizedTiming = {
    embedding: boundedNumber(
      timing.embedding,
      0,
      SHADOW_TIMEOUT_MS,
    ),
    postgresql: boundedNumber(
      timing.postgresql,
      0,
      SHADOW_TIMEOUT_MS,
    ),
    search_total: boundedNumber(
      timing.search_total,
      0,
      SHADOW_TIMEOUT_MS,
    ),
    verifier: boundedNumber(
      timing.verifier,
      0,
      SHADOW_TIMEOUT_MS,
    ),
    total: boundedNumber(
      timing.total,
      0,
      SHADOW_TIMEOUT_MS,
    ),
  };

  if (
    decision === "blocked_sensitive" ||
    decision === "dropped"
  ) {
    normalizedTiming.embedding = 0;
    normalizedTiming.postgresql = 0;
    normalizedTiming.search_total = 0;
    normalizedTiming.verifier = 0;
  }

  return {
    schema_version: 2,
    shadow_only: true,
    observed_at: normalizeObservedAt(observedAt),
    observation_id: randomUUID(),
    decision,
    matched_scope: matchedScope,
    memory_key: memoryKey,
    top_similarity: similarity,
    candidate_count: candidateCount,
    query_chars: Math.trunc(
      boundedNumber(input.query_chars, 0, 4000),
    ),
    dropped_count: droppedCount,
    timing_ms: normalizedTiming,
    reason,
  };
}

async function appendShadowDiagnostic(
  value: unknown,
  observedAt: string,
): Promise<void> {
  const diagnostic = sanitizeShadowDiagnostic(
    value,
    observedAt,
  );
  const line = `${JSON.stringify(diagnostic)}\n`;
  const handle = await open(
    SHADOW_LOG,
    fsConstants.O_WRONLY |
      fsConstants.O_APPEND |
      fsConstants.O_CREAT |
      fsConstants.O_NOFOLLOW,
    0o600,
  );

  try {
    await handle.chmod(0o600);
    const metadata = await handle.stat();
    if (
      metadata.size + Buffer.byteLength(line, "utf8") >
      MAX_LOG_BYTES
    ) {
      throw new Error("shadow_log_size_limit");
    }
    await handle.write(line, null, "utf8");
  } finally {
    await handle.close();
  }
}

let logWriteChain: Promise<void> = Promise.resolve();

function queueDiagnosticWrite(
  value: unknown,
  observedAt: string,
): Promise<void> {
  const write = logWriteChain.then(() =>
    appendShadowDiagnostic(value, observedAt),
  );
  logWriteChain = write.catch(() => {});
  return write;
}

const shadowQueue: ShadowQueueItem[] = [];
const dropAggregates = new Map<string, DropAggregate>();
let drainingShadowQueue = false;
let activeEvaluator:
  ChildProcessWithoutNullStreams | null = null;
let activeEvaluation: Promise<unknown> | null = null;
let stopping = false;
let queueSweepTimer: NodeJS.Timeout | null = null;
let dropFlushTimer: NodeJS.Timeout | null = null;

function evaluatorFailure(
  queryChars: number,
  reason: string,
): Record<string, unknown> {
  return {
    decision: "error",
    matched_scope: "not_present",
    memory_key: "",
    top_similarity: null,
    candidate_count: 0,
    query_chars: queryChars,
    dropped_count: 0,
    timing_ms: {},
    reason,
  };
}

function runShadowEvaluator(
  query: string,
): Promise<unknown> {
  return new Promise((resolve) => {
    const child = spawn(
      NODE_BINARY,
      [SHADOW_EVALUATOR],
      {
        shell: false,
        detached: true,
        stdio: ["pipe", "pipe", "pipe"],
        env: createChildEnv("mimir-evidence-shadow"),
      },
    );

    activeEvaluator = child;
    let stdout = "";
    let timedOut = false;
    let outputExceeded = false;
    let settled = false;

    const settle = (value: unknown) => {
      if (settled) {
        return;
      }
      settled = true;
      if (activeEvaluator === child) {
        activeEvaluator = null;
      }
      resolve(value);
    };

    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");

    child.stdout.on("data", (chunk: string) => {
      if (
        stdout.length + chunk.length >
        MAX_EVALUATOR_OUTPUT_LENGTH
      ) {
        outputExceeded = true;
        void terminateChild(child);
        return;
      }

      stdout += chunk;
    });

    child.stderr.on("data", () => {
      // A saída de erro não é persistida.
    });

    const timer = setTimeout(() => {
      timedOut = true;
      void terminateChild(child);
    }, SHADOW_TIMEOUT_MS);

    child.on("error", () => {
      clearTimeout(timer);
      settle(evaluatorFailure(query.length, "evaluator_failed"));
    });

    child.on("close", (code) => {
      clearTimeout(timer);

      if (timedOut) {
        settle(evaluatorFailure(query.length, "evaluator_timeout"));
        return;
      }

      if (outputExceeded || code !== 0) {
        settle(evaluatorFailure(query.length, "evaluator_failed"));
        return;
      }

      try {
        settle(JSON.parse(stdout));
      } catch {
        settle(
          evaluatorFailure(
            query.length,
            "evaluator_output_invalid",
          ),
        );
      }
    });

    child.stdin.on("error", (error) => {
      const errorCode =
        (error as NodeJS.ErrnoException).code;

      if (errorCode !== "EPIPE") {
        void terminateChild(child);
      }
    });

    child.stdin.end(query, "utf8");
  });
}

function recordDrop(
  item: ShadowQueueItem,
  reason: "queue_full" | "queue_expired" | "gateway_stopping",
): void {
  const current = dropAggregates.get(reason);
  if (current === undefined) {
    dropAggregates.set(reason, {
      count: 1,
      maxQueryChars: item.query.length,
      firstObservedAt: item.receivedAt,
    });
  } else {
    current.count += 1;
    current.maxQueryChars = Math.max(
      current.maxQueryChars,
      item.query.length,
    );
  }

  if (dropFlushTimer === null && !stopping) {
    dropFlushTimer = setTimeout(() => {
      dropFlushTimer = null;
      void flushDropAggregates();
    }, DROP_FLUSH_INTERVAL_MS);
    dropFlushTimer.unref();
  }
}

async function flushDropAggregates(): Promise<void> {
  const entries = [...dropAggregates.entries()];
  dropAggregates.clear();

  for (const [reason, aggregate] of entries) {
    try {
      await queueDiagnosticWrite(
        {
          decision: "dropped",
          matched_scope: "not_present",
          memory_key: "",
          top_similarity: null,
          candidate_count: 0,
          query_chars: aggregate.maxQueryChars,
          dropped_count: aggregate.count,
          timing_ms: {},
          reason,
        },
        aggregate.firstObservedAt,
      );
    } catch {
      // A falha do log não interfere no Gateway.
    }
  }
}

function pruneExpiredQueue(now = Date.now()): void {
  for (
    let index = shadowQueue.length - 1;
    index >= 0;
    index -= 1
  ) {
    const item = shadowQueue[index];
    if (now - item.receivedAtMs > MAX_QUEUE_AGE_MS) {
      shadowQueue.splice(index, 1);
      recordDrop(item, "queue_expired");
    }
  }
}

function scheduleQueueSweep(): void {
  if (
    queueSweepTimer !== null ||
    shadowQueue.length === 0 ||
    stopping
  ) {
    return;
  }

  queueSweepTimer = setTimeout(() => {
    queueSweepTimer = null;
    pruneExpiredQueue();
    scheduleQueueSweep();
  }, Math.min(15_000, MAX_QUEUE_AGE_MS));
  queueSweepTimer.unref();
}

async function drainShadowQueue(): Promise<void> {
  if (drainingShadowQueue || stopping) {
    return;
  }

  drainingShadowQueue = true;

  try {
    while (!stopping && shadowQueue.length > 0) {
      pruneExpiredQueue();
      const item = shadowQueue.shift();

      if (item === undefined) {
        continue;
      }

      activeEvaluation = runShadowEvaluator(item.query);
      const diagnostic = await activeEvaluation;
      activeEvaluation = null;

      if (!stopping) {
        try {
          await queueDiagnosticWrite(
            diagnostic,
            item.receivedAt,
          );
        } catch {
          // A falha do log não interfere no fluxo de mensagens.
        }
      }
    }
  } finally {
    activeEvaluation = null;
    drainingShadowQueue = false;

    if (!stopping && shadowQueue.length > 0) {
      void drainShadowQueue();
    }
  }
}

function enqueueShadowQuery(content: string): void {
  const query = content.trim();

  if (
    stopping ||
    query.length < 3 ||
    query.length > 4000
  ) {
    return;
  }

  const receivedAtMs = Date.now();
  const item: ShadowQueueItem = {
    query,
    receivedAt: new Date(receivedAtMs).toISOString(),
    receivedAtMs,
  };

  pruneExpiredQueue(receivedAtMs);

  if (shadowQueue.length >= MAX_QUEUE_LENGTH) {
    recordDrop(item, "queue_full");
    return;
  }

  shadowQueue.push(item);
  scheduleQueueSweep();
  void drainShadowQueue();
}

async function stopShadowProcessing(): Promise<void> {
  stopping = true;

  if (queueSweepTimer !== null) {
    clearTimeout(queueSweepTimer);
    queueSweepTimer = null;
  }
  if (dropFlushTimer !== null) {
    clearTimeout(dropFlushTimer);
    dropFlushTimer = null;
  }

  for (const item of shadowQueue.splice(0)) {
    recordDrop(item, "gateway_stopping");
  }

  if (activeEvaluator !== null) {
    await terminateChild(activeEvaluator);
  }

  if (activeEvaluation !== null) {
    await activeEvaluation.catch(() => {});
  }

  await flushDropAggregates();
  await logWriteChain;
}

const plugin: OpenClawPluginDefinition = definePluginEntry({
  id: "mimir-memory",
  name: "Mimir Memory",
  description:
    "Consulta controlada da memória permanente e verificação em modo sombra.",

  register(api) {
    api.registerTool({
      name: "mimir_memory_search",
      label: "Mimir Memory Search",

      description:
        "Pesquisa memórias permanentes ativas do projeto Mimir. " +
        "Use para recuperar identidade, decisões, configurações, " +
        "princípios e contexto previamente aprovado.",

      parameters: Type.Object(
        {
          query: Type.String({
            description:
              "Pergunta ou assunto que deve ser pesquisado.",
            minLength: 3,
            maxLength: 4000,
          }),

          limit: Type.Optional(
            Type.Integer({
              description:
                "Quantidade máxima de memórias retornadas.",
              minimum: 1,
              maximum: 10,
              default: 5,
            }),
          ),

          min_similarity: Type.Optional(
            Type.Number({
              description:
                "Similaridade mínima entre zero e um.",
              minimum: 0.2,
              maximum: 0.95,
              default: 0.45,
            }),
          ),
        },
        {
          additionalProperties: false,
        },
      ),

      execute: async (_toolCallId, params) => {
        const input = isObject(params) ? params : {};
        const query =
          typeof input.query === "string"
            ? input.query.trim()
            : "";
        const limit =
          typeof input.limit === "number"
            ? input.limit
            : 5;
        const minSimilarity =
          typeof input.min_similarity === "number"
            ? input.min_similarity
            : 0.45;

        if (query.length < 3 || query.length > 4000) {
          throw new Error(
            "A consulta deve possuir entre 3 e 4000 caracteres.",
          );
        }

        if (
          !Number.isInteger(limit) ||
          limit < 1 ||
          limit > 10
        ) {
          throw new Error(
            "O limite deve estar entre 1 e 10.",
          );
        }

        if (
          !Number.isFinite(minSimilarity) ||
          minSimilarity < 0.2 ||
          minSimilarity > 0.95
        ) {
          throw new Error(
            "A similaridade mínima deve estar entre 0.2 e 0.95.",
          );
        }

        const payload = await runSemanticSearch(
          query,
          limit,
          minSimilarity,
        );

        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify(payload, null, 2),
            },
          ],
          details: payload,
        };
      },
    }, {
      optional: true,
    });

    api.on(
      "message_received",
      (event) => {
        enqueueShadowQuery(event.content ?? "");
      },
      {
        timeoutMs: 1_000,
      },
    );

    api.on(
      "gateway_stop",
      async () => {
        await stopShadowProcessing();
      },
      {
        timeoutMs: 10_000,
      },
    );
  },
});

export const __testing = {
  createChildEnv,
  sanitizeShadowDiagnostic,
};

export default plugin;
