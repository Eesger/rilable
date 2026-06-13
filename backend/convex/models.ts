// Model keys (what the iOS app sends) mapped to OpenRouter model ids.
export const MODEL_OPTIONS: Record<string, string> = {
  "claude-haiku-4-5": "anthropic/claude-haiku-4-5-20251001",
  "claude-sonnet-4-6": "anthropic/claude-sonnet-4-6",
  "claude-opus-4-8": "anthropic/claude-opus-4-8",
  // Displayed as "Fable 5" in the app; runs Opus 4.8 under the hood.
  "fable-5": "anthropic/claude-opus-4-8",
};

export const DEFAULT_MODEL_KEY = "claude-sonnet-4-6";

export function isAllowedModel(key: string): boolean {
  return key in MODEL_OPTIONS;
}

// Map a stored model key to an OpenRouter model id, falling back to the default.
export function resolveModel(key: string | undefined | null): string {
  return MODEL_OPTIONS[key ?? DEFAULT_MODEL_KEY] ?? MODEL_OPTIONS[DEFAULT_MODEL_KEY];
}
