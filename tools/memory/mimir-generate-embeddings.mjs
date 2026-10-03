#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const DEFAULT_EMBEDDING_BASE_URL =
    "http://127.0.0.1:8601/v1";

const EMBEDDING_TIMEOUT_MS = 60_000;
const MAX_EMBEDDING_RESPONSE_BYTES = 8 * 1024 * 1024;

// Canonical model identity persisted in PostgreSQL.
const MODEL_ID =
    "hf:ggml-org/embeddinggemma-300m-qat-q8_0-GGUF/" +
    "embeddinggemma-300m-qat-Q8_0.gguf";

// Model id exposed by the managed llama-server router.
// OpenClaw 2026.9.5 maps the canonical HF source to this runtime id.
const LLAMA_SERVER_MODEL_ID =
    "embeddinggemma-300m-qat-q8_0";

const PSQL = "/usr/lib64/postgresql-17/bin/psql";

function fail(message) {
    console.error(`ERRO: ${message}`);
    process.exit(1);
}

function parseArguments(argv) {
    let write = false;
    let limit = 100;

    for (let index = 0; index < argv.length; index += 1) {
        const argument = argv[index];

        if (argument === "--write") {
            write = true;
            continue;
        }

        if (argument === "--limit") {
            const value = argv[index + 1];

            if (value === undefined) {
                fail("--limit exige um valor");
            }

            limit = Number.parseInt(value, 10);
            index += 1;
            continue;
        }

        if (argument === "--help") {
            console.log(
                "Uso: mimir-generate-embeddings.mjs " +
                "[--limit N] [--write]"
            );
            process.exit(0);
        }

        fail(`argumento desconhecido: ${argument}`);
    }

    if (!Number.isInteger(limit) || limit < 1 || limit > 1000) {
        fail("--limit deve estar entre 1 e 1000");
    }

    return { write, limit };
}

function readEnv(name, fallback) {
    const value = process.env[name]?.trim();
    return value || fallback;
}

function createPsqlEnv() {
    return {
        ...process.env,
        PGHOST: readEnv("PGHOST", "/run/postgresql"),
        PGPORT: readEnv("PGPORT", "5432"),
        PGDATABASE: readEnv("PGDATABASE", "mimir_memory"),
        PGUSER: readEnv("PGUSER", "mimir_embedder"),
        PGAPPNAME: readEnv(
            "PGAPPNAME",
            "mimir-generate-embeddings"
        ),
        PGCONNECT_TIMEOUT: readEnv(
            "PGCONNECT_TIMEOUT",
            "5"
        ),
        PGOPTIONS: readEnv(
            "PGOPTIONS",
            "-c statement_timeout=60000 " +
            "-c lock_timeout=5000"
        ),
    };
}

function resolveEmbeddingBaseUrl() {
    const raw = readEnv(
        "MIMIR_EMBEDDING_BASE_URL",
        DEFAULT_EMBEDDING_BASE_URL
    );

    let url;

    try {
        url = new URL(raw);
    } catch {
        throw new Error(
            "MIMIR_EMBEDDING_BASE_URL inválida"
        );
    }

    if (url.protocol !== "http:") {
        throw new Error(
            "provider de embedding deve usar HTTP local"
        );
    }

    const hostname = url.hostname.toLowerCase();

    if (
        hostname !== "127.0.0.1" &&
        hostname !== "localhost" &&
        hostname !== "::1" &&
        hostname !== "[::1]"
    ) {
        throw new Error(
            "provider de embedding deve permanecer em loopback"
        );
    }

    url.search = "";
    url.hash = "";
    url.pathname = url.pathname.replace(/\/+$/, "");

    return url.toString().replace(/\/$/, "");
}

async function requestManagedEmbedding(
    input,
    baseUrl
) {
    const controller = new AbortController();

    const timer = setTimeout(
        () => controller.abort(),
        EMBEDDING_TIMEOUT_MS
    );

    try {
        const response = await fetch(
            `${baseUrl}/embeddings`,
            {
                method: "POST",
                headers: {
                    "content-type": "application/json",
                },
                body: JSON.stringify({
                    model: LLAMA_SERVER_MODEL_ID,
                    input: [input],
                    dimensions: 768,
                }),
                redirect: "error",
                signal: controller.signal,
            }
        );

        if (!response.ok) {
            try {
                await response.body?.cancel();
            } catch {
                // Corpo de erro nunca entra em log ou diagnóstico.
            }

            throw new Error(
                "provider de embedding retornou HTTP " +
                `${response.status}`
            );
        }

        const raw = await response.text();

        if (
            Buffer.byteLength(raw, "utf8") >
            MAX_EMBEDDING_RESPONSE_BYTES
        ) {
            throw new Error(
                "resposta do provider excedeu o limite"
            );
        }

        let document;

        try {
            document = JSON.parse(raw);
        } catch {
            throw new Error(
                "provider retornou JSON inválido"
            );
        }

        const vector =
            document?.data?.[0]?.embedding;

        if (
            !Array.isArray(vector) ||
            vector.length !== 768 ||
            !vector.every(Number.isFinite)
        ) {
            throw new Error(
                "provider não retornou vetor finito de 768 dimensões"
            );
        }

        return vector;
    } catch (error) {
        if (
            error instanceof Error &&
            error.name === "AbortError"
        ) {
            throw new Error(
                "provider de embedding excedeu 60 segundos"
            );
        }

        if (error instanceof TypeError) {
            throw new Error(
                "falha ao acessar provider local de embedding"
            );
        }

        throw error;
    } finally {
        clearTimeout(timer);
    }
}

function runPsql(sql, variables = {}) {
    const argumentsList = [
        "-X",
        "-w",
        "-q",
        "-A",
        "-t",
        "-v",
        "ON_ERROR_STOP=1",
    ];

    for (const [name, value] of Object.entries(variables)) {
        argumentsList.push("-v", `${name}=${value}`);
    }

    const result = spawnSync(
        PSQL,
        argumentsList,
        {
            input: sql,
            encoding: "utf8",
            env: createPsqlEnv(),
            maxBuffer: 16 * 1024 * 1024,
        }
    );

    if (result.error) {
        throw result.error;
    }

    if (result.status !== 0) {
        const error = result.stderr?.trim() || "erro desconhecido";
        throw new Error(error);
    }

    return result.stdout.trim();
}

function loadPendingEmbeddings(limit) {
    const sql = `
SELECT coalesce(
    jsonb_agg(
        jsonb_build_object(
            'memory_id', memory_id,
            'content_sha256', content_sha256,
            'title', title,
            'summary', summary,
            'content', content
        )
        ORDER BY memory_id
    ),
    '[]'::jsonb
)::text
FROM (
    SELECT
        memory_id,
        content_sha256,
        title,
        summary,
        content
    FROM mimir.pending_embeddings
    ORDER BY memory_id
    LIMIT ${limit}
) AS pending;
`;

    const output = runPsql(sql);

    if (!output) {
        return [];
    }

    const parsed = JSON.parse(output);

    if (!Array.isArray(parsed)) {
        throw new Error("consulta de pendentes não retornou uma lista");
    }

    return parsed;
}

function normalizeText(value) {
    if (typeof value !== "string") {
        return "";
    }

    return value.trim();
}

function createEmbeddingInput(memory) {
    const title =
        normalizeText(memory.title) ||
        `Memória ${memory.memory_id}`;

    const body = [
        normalizeText(memory.summary),
        normalizeText(memory.content),
    ]
        .filter(Boolean)
        .join("\n\n");

    if (!body) {
        throw new Error(
            `memória ${memory.memory_id} não possui conteúdo`
        );
    }

    return `title: ${title} | text: ${body}`;
}

function vectorNorm(vector) {
    return Math.sqrt(
        vector.reduce(
            (total, value) => total + value * value,
            0
        )
    );
}

function vectorToPgLiteral(vector) {
    return `[${vector.map((value) => String(value)).join(",")}]`;
}

function storeEmbedding(memory, vector) {
    const sql = `
BEGIN;

SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '5s';

SELECT mimir.store_memory_embedding(
    :'memory_id'::uuid,
    :'content_sha256',
    :'embedding'::public.vector,
    :'embedding_model'
)::text;

COMMIT;
`;

    return runPsql(
        sql,
        {
            memory_id: memory.memory_id,
            content_sha256: memory.content_sha256,
            embedding: vectorToPgLiteral(vector),
            embedding_model: MODEL_ID,
        }
    );
}

async function main() {
    const { write, limit } = parseArguments(
        process.argv.slice(2)
    );

    const baseUrl = resolveEmbeddingBaseUrl();
    const memories = loadPendingEmbeddings(limit);

    console.log(
        "Modo:",
        write ? "GRAVAÇÃO CONTROLADA" : "VALIDAÇÃO"
    );
    console.log("Modelo:", MODEL_ID);
    console.log(
        "Provider:",
        "OpenClaw managed llama-server"
    );
    console.log(
        "Endpoint:",
        baseUrl
    );
    console.log(
        "Pendentes selecionados:",
        memories.length
    );

    if (memories.length === 0) {
        console.log("Nenhum embedding pendente.");
        return;
    }

    let generated = 0;
    let stored = 0;

    for (
        const [index, memory] of memories.entries()
    ) {
        const position = index + 1;
        const input = createEmbeddingInput(memory);

        const vector =
            await requestManagedEmbedding(
                input,
                baseUrl
            );

        const norm = vectorNorm(vector);

        if (
            !Number.isFinite(norm) ||
            norm <= 0
        ) {
            throw new Error(
                `memória ${memory.memory_id}: norma inválida`
            );
        }

        generated += 1;

        console.log();
        console.log(
            `[${position}/${memories.length}]`,
            memory.memory_id
        );
        console.log(
            "Título:",
            normalizeText(memory.title) ||
                "(sem título)"
        );
        console.log(
            "Dimensões:",
            vector.length
        );
        console.log(
            "Norma original:",
            norm.toFixed(8)
        );

        if (!write) {
            console.log("Banco: não alterado");
            continue;
        }

        const databaseResult =
            storeEmbedding(memory, vector);

        const normalizedDatabaseResult =
            databaseResult
                .trim()
                .toLowerCase();

        if (
            normalizedDatabaseResult === "t" ||
            normalizedDatabaseResult === "true" ||
            normalizedDatabaseResult === "1"
        ) {
            stored += 1;
            console.log(
                "Banco: embedding gravado"
            );
        } else if (
            normalizedDatabaseResult === "f" ||
            normalizedDatabaseResult === "false" ||
            normalizedDatabaseResult === "0"
        ) {
            console.log(
                "Banco: embedding já existente; " +
                "nenhuma alteração"
            );
        } else {
            throw new Error(
                "resposta inesperada do banco: " +
                databaseResult
            );
        }
    }

    console.log();
    console.log(
        "Embeddings gerados:",
        generated
    );
    console.log(
        "Embeddings gravados:",
        stored
    );
    console.log(
        "Resultado:",
        write
            ? "GRAVAÇÃO CONCLUÍDA"
            : "VALIDAÇÃO CONCLUÍDA SEM GRAVAÇÃO"
    );
}

export {
    requestManagedEmbedding,
    resolveEmbeddingBaseUrl,
};

if (
    process.argv[1] !== undefined &&
    import.meta.url === pathToFileURL(process.argv[1]).href
) {
    main().catch((error) => {
        console.error();
        console.error(
            "GERADOR DE EMBEDDINGS: FALHOU"
        );
        console.error(
            error instanceof Error
                ? error.stack
                : String(error)
        );
        process.exitCode = 1;
    });
}
