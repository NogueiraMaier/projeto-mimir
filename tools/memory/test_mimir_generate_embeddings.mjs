import assert from "node:assert/strict";
import http from "node:http";
import test from "node:test";

import {
  requestManagedEmbedding,
} from "./mimir-generate-embeddings.mjs";

async function withServer(handler, callback) {
  const server = http.createServer(handler);

  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });

  const address = server.address();

  assert.ok(
    address !== null &&
      typeof address === "object",
  );

  const baseUrl =
    `http://127.0.0.1:${address.port}/v1`;

  try {
    await callback(baseUrl);
  } finally {
    server.closeAllConnections?.();

    await new Promise((resolve, reject) => {
      server.close((error) => {
        if (error) {
          reject(error);
        } else {
          resolve();
        }
      });
    });
  }
}

test(
  "embedding provider refuses redirects",
  async () => {
    let requests = 0;

    await withServer(
      (_request, response) => {
        requests += 1;

        response.statusCode = 302;
        response.setHeader(
          "Location",
          "/v1/redirected",
        );
        response.end();
      },
      async (baseUrl) => {
        await assert.rejects(
          requestManagedEmbedding(
            "synthetic input",
            baseUrl,
          ),
          (error) => {
            assert.equal(
              error.message,
              "falha ao acessar provider local de embedding",
            );
            return true;
          },
        );
      },
    );

    assert.equal(
      requests,
      1,
      "redirect must never be followed",
    );
  },
);

test(
  "HTTP error body is never surfaced",
  async () => {
    const secret =
      "token=" + "S".repeat(32);

    await withServer(
      (_request, response) => {
        response.statusCode = 503;
        response.setHeader(
          "Content-Type",
          "text/plain",
        );
        response.end(
          "internal provider error " + secret,
        );
      },
      async (baseUrl) => {
        await assert.rejects(
          requestManagedEmbedding(
            "synthetic input",
            baseUrl,
          ),
          (error) => {
            assert.equal(
              error.message,
              "provider de embedding retornou HTTP 503",
            );

            assert.equal(
              String(error).includes(secret),
              false,
            );

            assert.equal(
              String(error.stack).includes(secret),
              false,
            );

            return true;
          },
        );
      },
    );
  },
);

test(
  "successful local embedding remains accepted",
  async () => {
    const vector = Array.from(
      { length: 768 },
      (_value, index) =>
        (index + 1) / 1000,
    );

    await withServer(
      (_request, response) => {
        const body = JSON.stringify({
          data: [
            {
              embedding: vector,
            },
          ],
        });

        response.statusCode = 200;
        response.setHeader(
          "Content-Type",
          "application/json",
        );
        response.end(body);
      },
      async (baseUrl) => {
        const result =
          await requestManagedEmbedding(
            "synthetic input",
            baseUrl,
          );

        assert.equal(result.length, 768);
        assert.deepEqual(result, vector);
      },
    );
  },
);
