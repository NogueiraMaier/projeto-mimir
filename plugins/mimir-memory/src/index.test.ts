import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import entry, { __testing } from "./index.js";

describe("mimir-memory", () => {
  it("declares the mixed plugin identity", () => {
    expect(entry.id).toBe("mimir-memory");
    expect(entry.name).toBe("Mimir Memory");
    expect(typeof entry.register).toBe("function");
  });

  it("registers the optional tool and typed hooks", () => {
    const tools: Array<{
      name: string;
      optional: boolean;
    }> = [];
    const hooks: Array<{
      name: string;
      timeoutMs: number | undefined;
    }> = [];

    entry.register({
      registerTool(tool: { name: string }, options?: {
        optional?: boolean;
      }) {
        tools.push({
          name: tool.name,
          optional: options?.optional === true,
        });
      },
      on(name: string, _handler: unknown, options?: {
        timeoutMs?: number;
      }) {
        hooks.push({
          name,
          timeoutMs: options?.timeoutMs,
        });
      },
    } as never);

    expect(tools).toEqual([
      {
        name: "mimir_memory_search",
        optional: true,
      },
    ]);
    expect(hooks).toEqual([
      {
        name: "message_received",
        timeoutMs: 1_000,
      },
      {
        name: "gateway_stop",
        timeoutMs: 10_000,
      },
    ]);
  });

  it("keeps the manifest aligned with runtime registration", () => {
    const manifest = JSON.parse(
      readFileSync(
        new URL("../openclaw.plugin.json", import.meta.url),
        "utf8",
      ),
    );

    expect(manifest.version).toBe("0.2.7");
    expect(manifest.activation.onStartup).toBe(true);
    expect(manifest.contracts.tools).toEqual([
      "mimir_memory_search",
    ]);
    expect(
      manifest.toolMetadata.mimir_memory_search.optional,
    ).toBe(true);
  });

  it("does not inherit gateway credentials into subprocesses", () => {
    process.env.OPENCLAW_SECRET_TEST = "must-not-leak";
    const environment = __testing.createChildEnv("test-app");
    delete process.env.OPENCLAW_SECRET_TEST;

    expect(environment.OPENCLAW_SECRET_TEST).toBeUndefined();
    expect(environment.PGHOST).toBe("/run/postgresql");
    expect(environment.PGPORT).toBe("5432");
    expect(environment.PGUSER).toBe("mimir_search");
    expect(environment.PGDATABASE).toBe("mimir_memory");
    expect(environment.PGOPTIONS).toContain(
      "default_transaction_read_only=on",
    );
    expect(environment.PGOPTIONS).toContain(
      "statement_timeout=60000",
    );
  });

  it("maps only dedicated PostgreSQL transport overrides", () => {
    process.env.PGHOST = "must-not-be-inherited";
    process.env.MIMIR_MEMORY_PGHOST = "10.51.1.2";
    process.env.MIMIR_MEMORY_PGPORT = "5433";
    process.env.MIMIR_MEMORY_PGDATABASE = "mimir_remote";
    process.env.MIMIR_MEMORY_PGUSER = "mimir_search_remote";

    const environment = __testing.createChildEnv(
      "test-remote",
    );

    delete process.env.PGHOST;
    delete process.env.MIMIR_MEMORY_PGHOST;
    delete process.env.MIMIR_MEMORY_PGPORT;
    delete process.env.MIMIR_MEMORY_PGDATABASE;
    delete process.env.MIMIR_MEMORY_PGUSER;

    expect(environment.PGHOST).toBe("10.51.1.2");
    expect(environment.PGPORT).toBe("5433");
    expect(environment.PGDATABASE).toBe("mimir_remote");
    expect(environment.PGUSER).toBe("mimir_search_remote");
  });

  it("uses the configured memory model when present", () => {
    expect(
      __testing.resolveConfiguredSearchModel(
        {
          memory: {
            search: {
              model: "custom-embedding-model",
            },
          },
        },
        "fallback-model",
      ),
    ).toBe("custom-embedding-model");

    expect(
      __testing.resolveConfiguredSearchModel(
        {},
        "fallback-model",
      ),
    ).toBe("fallback-model");
  });

  it("validates the 768-dimensional embedding contract", () => {
    const vector = Array.from(
      { length: 768 },
      (_, index) => (index + 1) / 1000,
    );

    expect(
      __testing.validateEmbeddingVector(vector),
    ).toEqual(vector);

    expect(() =>
      __testing.validateEmbeddingVector([1, 2, 3]),
    ).toThrow(/768/);
  });

  it("canonicalizes inconsistent diagnostics to a safe error", () => {
    const diagnostic = __testing.sanitizeShadowDiagnostic(
      {
        decision: "supported",
        matched_scope: "not_present",
        memory_key: "",
        top_similarity: 0.9,
        candidate_count: 5,
        query_chars: 20,
        timing_ms: {},
        reason: "",
      },
      "2026-07-31T12:00:00.000Z",
    );

    expect(diagnostic).toMatchObject({
      schema_version: 2,
      observed_at: "2026-07-31T12:00:00.000Z",
      decision: "error",
      matched_scope: "not_present",
      memory_key: "",
      top_similarity: null,
      candidate_count: 0,
      dropped_count: 0,
      reason: "evaluator_output_invalid",
    });
  });

  it("accepts only a coherent supported diagnostic", () => {
    const diagnostic = __testing.sanitizeShadowDiagnostic({
      decision: "supported",
      matched_scope: "execution_platform",
      memory_key: "projeto.plataforma.execucao",
      top_similarity: 0.812345,
      candidate_count: 5,
      query_chars: 42,
      timing_ms: {},
      reason: "",
    });

    expect(diagnostic.decision).toBe("supported");
    expect(diagnostic.top_similarity).toBe(0.812);
    expect(diagnostic.memory_key).toBe(
      "projeto.plataforma.execucao",
    );
  });
});
