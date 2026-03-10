You are selecting one production default model for provider "{provider_hint}".

Task:
- Choose exactly one default model from the provided list.
- Optimize for reliable day-to-day general usage (not benchmark peak only).
- Prefer robust quality/cost balance and broad multimodal usefulness when possible.
- If multiple are close, choose the more stable widely-available option.
- You may consult any public URL/domain if needed to verify current pricing/availability.

Output must be strict JSON only:
{
    "provider": "{provider_hint}",
    "default_model": "exact-model-name-from-list",
    "reason": "short explanation"
}

Available models:
{models_json}
