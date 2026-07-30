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
    let limit = 5;
    let minSimilarity = 0.35;
    let json = false;
    const queryParts = [];

    for (let index = 0; index < argv.length; index += 1) {
        const argument = argv[index];

        if (argument === "--limit") {
            const value = argv[index + 1];

            if (value === undefined) {
                fail("--limit exige um valor");
            }

            limit = Number.parseInt(value, 10);
            index += 1;
            continue;
        }

        if (argument === "--min-similarity") {
            const value = argv[index + 1];

            if (value === undefined) {
                fail("--min-similarity exige um valor");
            }

            minSimilarity = Number.parseFloat(value);
            index += 1;
            continue;
        }

        if (argument === "--json") {
            json = true;
            continue;
        }

        if (argument === "--help") {
            console.log(
                "Uso:\n" +
                "  mimir-semantic-search.mjs [opções] \"consulta\"\n\n" +
                "Opções:\n" +
                "  --limit N                 Máximo de resultados, 1 a 20\n" +
                "  --min-similarity N        Similaridade mínima, 0 a 1\n" +
                "  --json                    Saída estruturada em JSON\n"
            );
            process.exit(0);
        }

        if (argument.startsWith("-")) {
            fail(`argumento desconhecido: ${argument}`);
        }

        queryParts.push(argument);
    }

    if (!Number.isInteger(limit) || limit < 1 || limit > 20) {
        fail("--limit deve estar entre 1 e 20");
    }

    if (
        !Number.isFinite(minSimilarity) ||
        minSimilarity < 0 ||
        minSimilarity > 1
    ) {
        fail("--min-similarity deve estar entre 0 e 1");
    }

    let query = queryParts.join(" ").trim();

    if (!query && !process.stdin.isTTY) {
        query = fs.readFileSync(0, "utf8").trim();
    }

    if (!query) {
        fail("consulta não informada");
    }

    if (query.length > 4000) {
        fail("consulta excede 4000 caracteres");
    }

    return {
        query,
        limit,
        minSimilarity,
        json,
    };
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
        "mimir_search",
        "-d",
        "mimir_memory",
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
            env: {
                ...process.env,
                PGCONNECT_TIMEOUT: "5",
                PGAPPNAME: "mimir-semantic-search",
            },
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

function vectorNorm(vector) {
    return Math.sqrt(
        vector.reduce(
            (total, value) => total + value * value,
            0
        )
    );
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
    limit,
    minSimilarity,
    results
) {
    console.log(`Consulta: ${query}`);
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
    const {
        query,
        limit,
        minSimilarity,
        json,
    } = parseArguments(process.argv.slice(2));

    if (!fs.existsSync(MODEL_PATH)) {
        fail(`modelo não encontrado: ${MODEL_PATH}`);
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

        const embeddingInput =
            `task: search result | query: ${query}`;

        const embeddingResult =
            await context.getEmbeddingFor(
                embeddingInput
            );

        const vector = Array.from(
            embeddingResult.vector
        );

        const norm = vectorNorm(vector);

        if (vector.length !== 768) {
            throw new Error(
                `embedding possui ${vector.length} dimensões; ` +
                "esperado: 768"
            );
        }

        if (!vector.every(Number.isFinite)) {
            throw new Error(
                "embedding contém valores não finitos"
            );
        }

        if (!Number.isFinite(norm) || norm <= 0) {
            throw new Error(
                "embedding possui norma inválida"
            );
        }

        const results = searchDatabase(
            vector,
            limit,
            minSimilarity
        );

        if (json) {
            console.log(
                JSON.stringify(
                    {
                        query,
                        model: MODEL_ID,
                        dimensions: vector.length,
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
                limit,
                minSimilarity,
                results
            );
        }
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
    console.error("CONSULTA SEMÂNTICA: FALHOU");
    console.error(
        error instanceof Error
            ? error.stack
            : String(error)
    );
    process.exitCode = 1;
});
