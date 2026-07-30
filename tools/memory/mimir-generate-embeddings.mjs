#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";
import fs from "node:fs";

const MODEL_PATH =
    "/var/lib/openclaw/.node-llama-cpp/models/" +
    "hf_ggml-org_embeddinggemma-300m-qat-Q8_0.gguf";

const MODEL_ID =
    "hf:ggml-org/embeddinggemma-300m-qat-q8_0-GGUF/" +
    "embeddinggemma-300m-qat-Q8_0.gguf";

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

function runPsql(sql, variables = {}) {
    const argumentsList = [
        "-X",
        "-w",
        "-q",
        "-A",
        "-t",
        "-h",
        "/run/postgresql",
        "-U",
        "mimir_embedder",
        "-d",
        "mimir_memory",
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
            env: {
                ...process.env,
                PGCONNECT_TIMEOUT: "5",
            },
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

    if (!fs.existsSync(MODEL_PATH)) {
        fail(`modelo não encontrado: ${MODEL_PATH}`);
    }

    const memories = loadPendingEmbeddings(limit);

    console.log(
        "Modo:",
        write ? "GRAVAÇÃO CONTROLADA" : "VALIDAÇÃO"
    );
    console.log("Modelo:", MODEL_ID);
    console.log("Backend: CPU");
    console.log("Pendentes selecionados:", memories.length);

    if (memories.length === 0) {
        console.log("Nenhum embedding pendente.");
        return;
    }

    const requireFromOpenClaw = createRequire(
        "/opt/openclaw/package.json"
    );

    const modulePath = requireFromOpenClaw.resolve(
        "node-llama-cpp"
    );

    const { getLlama } = await import(
        pathToFileURL(modulePath).href
    );

    let llama;
    let model;
    let context;

    try {
        llama = await getLlama({
            gpu: false,
        });

        model = await llama.loadModel({
            modelPath: MODEL_PATH,
        });

        context = await model.createEmbeddingContext();

        let generated = 0;
        let stored = 0;

        for (const [index, memory] of memories.entries()) {
            const position = index + 1;
            const input = createEmbeddingInput(memory);

            const result = await context.getEmbeddingFor(input);
            const vector = Array.from(result.vector);
            const norm = vectorNorm(vector);

            if (vector.length !== 768) {
                throw new Error(
                    `memória ${memory.memory_id}: ` +
                    `dimensão ${vector.length}; esperado 768`
                );
            }

            if (!vector.every(Number.isFinite)) {
                throw new Error(
                    `memória ${memory.memory_id}: ` +
                    "vetor contém valores inválidos"
                );
            }

            if (!Number.isFinite(norm) || norm <= 0) {
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
                normalizeText(memory.title) || "(sem título)"
            );
            console.log("Dimensões:", vector.length);
            console.log("Norma original:", norm.toFixed(8));

            if (!write) {
                console.log("Banco: não alterado");
                continue;
            }

            const databaseResult = storeEmbedding(
                memory,
                vector
            );

            const normalizedDatabaseResult =
                databaseResult.trim().toLowerCase();

            if (
                normalizedDatabaseResult === "t" ||
                normalizedDatabaseResult === "true" ||
                normalizedDatabaseResult === "1"
            ) {
                stored += 1;
                console.log("Banco: embedding gravado");
            } else if (
                normalizedDatabaseResult === "f" ||
                normalizedDatabaseResult === "false" ||
                normalizedDatabaseResult === "0"
            ) {
                console.log(
                    "Banco: embedding já existente; nenhuma alteração"
                );
            } else {
                throw new Error(
                    `resposta inesperada do banco: ` +
                    `${databaseResult}`
                );
            }
        }

        console.log();
        console.log("Embeddings gerados:", generated);
        console.log("Embeddings gravados:", stored);
        console.log(
            "Resultado:",
            write
                ? "GRAVAÇÃO CONCLUÍDA"
                : "VALIDAÇÃO CONCLUÍDA SEM GRAVAÇÃO"
        );
    } finally {
        try {
            await context?.dispose?.();
        } catch {}

        try {
            await model?.dispose?.();
        } catch {}

        try {
            await llama?.dispose?.();
        } catch {}
    }
}

main().catch((error) => {
    console.error();
    console.error("GERADOR DE EMBEDDINGS: FALHOU");
    console.error(
        error instanceof Error
            ? error.stack
            : String(error)
    );
    process.exitCode = 1;
});
