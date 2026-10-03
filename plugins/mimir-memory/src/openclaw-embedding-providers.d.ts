declare module "openclaw/plugin-sdk/embedding-providers" {
  export type EmbeddingInput =
    | string
    | {
        text: string;
        parts?: Array<
          | { type: "text"; text: string }
          | {
              type: "inline-data";
              mimeType: string;
              data: string;
            }
        >;
      };

  export type EmbeddingProviderCallOptions = {
    signal?: AbortSignal;
    inputType?:
      | "query"
      | "document"
      | "semantic"
      | "classification"
      | "clustering";
  };

  export type EmbeddingProvider = {
    id: string;
    model: string;
    dimensions?: number;
    maxInputTokens?: number;
    embed: (
      input: EmbeddingInput,
      options?: EmbeddingProviderCallOptions,
    ) => Promise<number[]>;
    embedBatch: (
      inputs: EmbeddingInput[],
      options?: EmbeddingProviderCallOptions,
    ) => Promise<number[][]>;
    close?: () => Promise<void> | void;
  };

  export type EmbeddingProviderCreateOptions = {
    config: unknown;
    agentDir?: string;
    provider?: string;
    remote?: {
      baseUrl?: string;
      apiKey?: unknown;
      headers?: Record<string, string>;
    };
    model: string;
    inputType?: string;
    queryInputType?: string;
    documentInputType?: string;
    local?: {
      modelPath?: string;
      modelCacheDir?: string;
    };
    dimensions?: number;
    taskType?: string;
  };

  export type EmbeddingProviderCreateResult = {
    provider: EmbeddingProvider | null;
    runtime?: unknown;
  };

  export type EmbeddingProviderAdapter = {
    id: string;
    defaultModel?: string;
    transport?: "local" | "remote";
    authProviderId?: string;
    normalizeModel?: (
      options: EmbeddingProviderCreateOptions,
    ) => string;
    create: (
      options: EmbeddingProviderCreateOptions,
    ) => Promise<EmbeddingProviderCreateResult>;
    formatSetupError?: (error: unknown) => string;
  };

  export function getEmbeddingProvider(
    id: string,
    config?: unknown,
  ): EmbeddingProviderAdapter | undefined;
}
