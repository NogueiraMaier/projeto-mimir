#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import fs from "node:fs";

const PSQL = "/usr/lib64/postgresql-17/bin/psql";
const EMBEDDING_DIMENSIONS = 768;
const MAX_REQUEST_BYTES = 256 * 1024;

function fail(message) {
    console.error(`ERRO: ${message}`);
    process.exit(1);
}

function parseArguments(argv) {
    let json = false;

    for (const argument of argv) {
        if (argument === "--json") {
            json = true;
            continue;
        }

        if (argument === "--help") {
            console.log(
                "Uso:\n" +
                "  mimir-semantic-search.mjs [--json]\n\n" +
                "Entrada:\n" +
                "  JSON via stdin com query, model, embedding, " +
                "limit e min_similarity.\n\n" +
                "O embedding deve ser gerado pelo runtime gerenciado " +
                "do OpenClaw antes desta etapa.\n"
            );
            process.exit(0);
        }

        fail(`argumento desconhecido: ${argument}`);
    }

    return { json };
}

function isObject(value) {
    return (
        typeof value === "object" &&
        value !== null &&
        !Array.isArray(value)
    );
}

function vectorNorm(vector) {
    return Math.sqrt(
        vector.reduce(
            (total, value) => total + value * value,
            0
        )
    );
}

function parseRequest() {
    if (process.stdin.isTTY) {
        fail("requisição JSON não informada em stdin");
    }

    const raw = fs.readFileSync(0, "utf8");

    if (Buffer.byteLength(raw, "utf8") > MAX_REQUEST_BYTES) {
        fail("requisição excede o limite de tamanho");
    }

    let request;

    try {
        request = JSON.parse(raw);
    } catch {
        fail("requisição JSON inválida");
    }

    if (!isObject(request)) {
        fail("requisição deve ser um objeto JSON");
    }

    const query =
        typeof request.query === "string"
            ? request.query.trim()
            : "";
    const model =
        typeof request.model === "string"
            ? request.model.trim()
            : "";
    const embedding = request.embedding;
    const limit = request.limit;
    const minSimilarity = request.min_similarity;

    if (query.length < 3 || query.length > 4000) {
        fail("query deve possuir entre 3 e 4000 caracteres");
    }

    if (!model || model.length > 1024) {
        fail("model inválido");
    }

    if (
        !Array.isArray(embedding) ||
        embedding.length !== EMBEDDING_DIMENSIONS ||
        !embedding.every(
            (value) =>
                typeof value === "number" &&
                Number.isFinite(value)
        )
    ) {
        fail(
            "embedding deve conter exatamente " +
            `${EMBEDDING_DIMENSIONS} números finitos`
        );
    }

    const norm = vectorNorm(embedding);

    if (!Number.isFinite(norm) || norm <= 0) {
        fail("embedding possui norma inválida");
    }

    if (
        !Number.isInteger(limit) ||
        limit < 1 ||
        limit > 10
    ) {
        fail("limit deve estar entre 1 e 10");
    }

    if (
        typeof minSimilarity !== "number" ||
        !Number.isFinite(minSimilarity) ||
        minSimilarity < 0.2 ||
        minSimilarity > 0.95
    ) {
        fail("min_similarity deve estar entre 0.2 e 0.95");
    }

    return {
        query,
        model,
        embedding,
        limit,
        minSimilarity,
    };
}

function readEnv(name, fallback) {
    const value = process.env[name]?.trim();
    return value || fallback;
}

function createPsqlEnv() {
    return {
        HOME: "/var/lib/openclaw",
        USER: "openclaw",
        LOGNAME: "openclaw",
        PATH:
            "/usr/local/sbin:/usr/local/bin:" +
            "/usr/sbin:/usr/bin:/sbin:/bin",
        LANG: "C.UTF-8",
        LC_ALL: "C.UTF-8",
        PGHOST: readEnv("PGHOST", "/run/postgresql"),
        PGPORT: readEnv("PGPORT", "5432"),
        PGDATABASE: readEnv("PGDATABASE", "mimir_memory"),
        PGUSER: readEnv("PGUSER", "mimir_search"),
        PGAPPNAME: readEnv(
            "PGAPPNAME",
            "mimir-semantic-search"
        ),
        PGCONNECT_TIMEOUT: readEnv(
            "PGCONNECT_TIMEOUT",
            "5"
        ),
        PGOPTIONS: readEnv(
            "PGOPTIONS",
            "-c default_transaction_read_only=on " +
            "-c statement_timeout=60000 " +
            "-c lock_timeout=5000"
        ),
    };
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
        argumentsList.push(
            "-v",
            `${name}=${value}`
        );
    }

    const result = spawnSync(
        PSQL,
        argumentsList,
        {
            input: sql,
            encoding: "utf8",
            env: createPsqlEnv(),
            timeout: 75_000,
            killSignal: "SIGKILL",
            maxBuffer: 16 * 1024 * 1024,
        }
    );

    if (result.error) {
        throw result.error;
    }

    if (result.status !== 0) {
        throw new Error(
            result.stderr?.trim() ||
            `psql terminou com código ${result.status}`
        );
    }

    return result.stdout.trim();
}

function vectorToPgLiteral(vector) {
    return `[${vector.map(String).join(",")}]`;
}

function searchDatabase(
    vector,
    limit,
    minSimilarity
) {
    const sql = `
SELECT coalesce(
    jsonb_agg(
        to_jsonb(result)
        ORDER BY
            result.similarity DESC,
            result.importance DESC,
            result.confidence DESC,
            result.memory_id
    ),
    '[]'::jsonb
)::text
FROM mimir.search_active_memory(
    :'embedding'::public.vector,
    :'result_limit'::integer,
    :'min_similarity'::double precision
) AS result;
`;

    const output = runPsql(
        sql,
        {
            embedding: vectorToPgLiteral(vector),
            result_limit: String(limit),
            min_similarity: String(minSimilarity),
        }
    );

    if (!output) {
        return [];
    }

    const parsed = JSON.parse(output);

    if (!Array.isArray(parsed)) {
        throw new Error(
            "a função de busca não retornou uma lista"
        );
    }

    return parsed;
}

function printHumanResults(
    query,
    model,
    limit,
    minSimilarity,
    results
) {
    console.log(`Consulta: ${query}`);
    console.log(`Modelo: ${model}`);
    console.log(`Limite: ${limit}`);
    console.log(
        `Similaridade mínima: ${minSimilarity}`
    );
    console.log(`Resultados: ${results.length}`);

    if (results.length === 0) {
        console.log();
        console.log(
            "Nenhuma memória atingiu a similaridade mínima."
        );
        return;
    }

    for (const [index, result] of results.entries()) {
        const similarity = Number(result.similarity);

        console.log();
        console.log(
            `${index + 1}. ${result.title || "(sem título)"}`
        );
        console.log(
            `   Similaridade: ${similarity.toFixed(6)}`
        );
        console.log(
            `   Chave: ${result.memory_key || "(sem chave)"}`
        );
        console.log(
            `   Tipo: ${result.memory_type || "(sem tipo)"}`
        );

        if (result.summary) {
            console.log(`   Resumo: ${result.summary}`);
        }

        if (result.content) {
            console.log(`   Conteúdo: ${result.content}`);
        }

        if (result.source_ref) {
            console.log(`   Fonte: ${result.source_ref}`);
        }
    }
}

async function main() {
    const { json } = parseArguments(
        process.argv.slice(2)
    );
    const {
        query,
        model,
        embedding,
        limit,
        minSimilarity,
    } = parseRequest();

    const results = searchDatabase(
        embedding,
        limit,
        minSimilarity
    );

    if (json) {
        console.log(
            JSON.stringify(
                {
                    query,
                    model,
                    dimensions: embedding.length,
                    limit,
                    min_similarity: minSimilarity,
                    result_count: results.length,
                    results,
                },
                null,
                2
            )
        );
    } else {
        printHumanResults(
            query,
            model,
            limit,
            minSimilarity,
            results
        );
    }
}

main().catch((error) => {
    console.error();
    console.error("CONSULTA SEMÂNTICA: FALHOU");
    console.error(
        error instanceof Error
            ? error.stack
            : String(error)
    );
    process.exitCode = 1;
});
