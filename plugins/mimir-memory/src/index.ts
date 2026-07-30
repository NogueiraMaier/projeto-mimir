import { spawn } from "node:child_process";
import { Type } from "typebox";
import { defineToolPlugin } from "openclaw/plugin-sdk/tool-plugin";

const NODE_BINARY = "/usr/bin/node";

const SEARCH_SCRIPT =
  "/var/lib/openclaw/workspace/tools/memory/" +
  "mimir-semantic-search.mjs";

const EXECUTION_TIMEOUT_MS = 300_000;
const MAX_OUTPUT_LENGTH = 8 * 1024 * 1024;

type SearchPayload = {
  query: string;
  model: string;
  dimensions: number;
  limit: number;
  min_similarity: number;
  result_count: number;
  results: unknown[];
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

  if (value.result_count !== value.results.length) {
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
        stdio: ["pipe", "pipe", "pipe"],
        env: {
          ...process.env,
          PGAPPNAME: "mimir-memory-plugin",
        },
      },
    );

    let stdout = "";
    let stderr = "";
    let timedOut = false;
    let outputExceeded = false;

    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");

    child.stdout.on("data", (chunk: string) => {
      if (
        stdout.length + chunk.length >
        MAX_OUTPUT_LENGTH
      ) {
        outputExceeded = true;
        child.kill("SIGTERM");
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
      child.kill("SIGTERM");
    }, EXECUTION_TIMEOUT_MS);

    child.on("error", (error) => {
      clearTimeout(timer);
      reject(
        new Error(
          `Não foi possível iniciar a consulta: ${error.message}`,
        ),
      );
    });

    child.on("close", (code, signal) => {
      clearTimeout(timer);

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

    child.stdin.on("error", (error) => {
      const errorCode =
        (error as NodeJS.ErrnoException).code;

      if (errorCode !== "EPIPE") {
        child.kill("SIGTERM");
      }
    });

    child.stdin.end(query, "utf8");
  });
}

export default defineToolPlugin({
  id: "mimir-memory",
  name: "Mimir Memory",
  description:
    "Consulta controlada da memória semântica permanente do Mimir.",

  tools: (tool) => [
    tool({
      name: "mimir_memory_search",

      description:
        "Pesquisa memórias permanentes ativas do projeto Mimir. " +
        "Use para recuperar identidade, decisões, configurações, " +
        "princípios e contexto previamente aprovado.",

      optional: true,

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

      execute: async ({
        query,
        limit,
        min_similarity: minSimilarity,
      }) => {
        const normalizedQuery = query.trim();
        const resolvedLimit = limit ?? 5;
        const resolvedMinSimilarity =
          minSimilarity ?? 0.45;

        if (
          normalizedQuery.length < 3 ||
          normalizedQuery.length > 4000
        ) {
          throw new Error(
            "A consulta deve possuir entre 3 e 4000 caracteres.",
          );
        }

        if (
          !Number.isInteger(resolvedLimit) ||
          resolvedLimit < 1 ||
          resolvedLimit > 10
        ) {
          throw new Error(
            "O limite deve estar entre 1 e 10.",
          );
        }

        if (
          !Number.isFinite(resolvedMinSimilarity) ||
          resolvedMinSimilarity < 0.2 ||
          resolvedMinSimilarity > 0.95
        ) {
          throw new Error(
            "A similaridade mínima deve estar entre 0.2 e 0.95.",
          );
        }

        return runSemanticSearch(
          normalizedQuery,
          resolvedLimit,
          resolvedMinSimilarity,
        );
      },
    }),
  ],
});
