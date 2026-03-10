You are generating accurate model metadata for provider "{provider_hint}".

Step 1 — Find the official pricing page:
- Search the web for the official pricing or billing page for "{provider_hint}".
- The page may list prices as USD per 1M tokens (input/output), or as request multipliers
  (e.g. "1x", "3x", "10x" where 1x = a standard request), depending on the provider.
- Record the canonical pricing page URL as `pricing_url` in your output.

Step 2 — Look up each model's cost:
- If pricing is in USD per 1M tokens: record `input_usd_per_1m` and `output_usd_per_1m` for each model.
- If pricing is in request multipliers: record the multiplier value as `cost_multiplier` directly.
- If a model is not found on the pricing page, set its pricing fields to null.

Step 3 — Compute cost_multiplier for token-priced models:
- cost_multiplier is a number (not necessarily an integer) representing relative cost:
  - 0 if avg(input, output) <= $0.50/1M tokens (free tier)
  - 1 if avg <= $8.00/1M tokens (standard)
  - 3 if avg <= $30.00/1M tokens (premium)
  - higher values for more expensive models
- For request-multiplier providers, use the stated multiplier value directly.

Step 4 — Score each model:
- quality: integer 0-100 reflecting overall capability relative to other models in the list.
- vision: true if the model supports image inputs, false otherwise.
- reasoning: true if the model is a reasoning/chain-of-thought model that uses internal thinking
  tokens before responding (e.g. OpenAI o-series, Claude thinking variants, Gemini thinking
  variants, GPT codex models). false for standard chat/completion models.

Output must be strict JSON only (no markdown, no prose, no code fences):
{
  "provider": "{provider_hint}",
  "pricing_url": "https://...",
  "rules": [
    {
      "model": "exact-model-name-from-list",
      "quality": 0-100,
      "cost_multiplier": number,
      "vision": true|false,
      "reasoning": true|false,
      "input_usd_per_1m": number|null,
      "output_usd_per_1m": number|null
    }
  ]
}

Hard constraints:
- One entry per model. Include every model exactly once.
- Do not invent or omit models.
- JSON only. No explanation before or after.

Models for "{provider_hint}":
{models_json}