"""Maps Settings.chatBotApi values to provider ids and endpoint specs.

QML keeps passing the settings value through unchanged; this module decides which
OpenAI-compatible endpoint serves it and which env var carries the key.
"""

_OPENROUTER_VALUES = {
    "openrouter/free",
    "openrouter/auto",
    "openai/gpt-4o-mini",
    "qwen/qwen3.5-9b",
    "meta-llama/llama-3.2-1b-instruct",
    "mistralai/ministral-8b-2512",
}

# Both endpoints speak the OpenAI chat-completions dialect (SSE deltas), so one
# request/parse path serves them; only the URL, model id and key differ.
PROVIDERS = {
    "openrouter": {
        "label": "OpenRouter",
        "api_url": "https://openrouter.ai/api/v1/chat/completions",
        "models_url": "https://openrouter.ai/api/v1/models",
        "key_env": "OPENROUTER_API_KEY",
    },
    "opencode": {
        "label": "OpenCode Zen",
        "api_url": "https://opencode.ai/zen/v1/chat/completions",
        "models_url": "https://opencode.ai/zen/v1/models",
        "key_env": "OPENCODE_API_KEY",
    },
}


def resolve_provider(settings_value: str) -> str:
    if settings_value in _OPENROUTER_VALUES:
        return "openrouter"
    if isinstance(settings_value, str) and settings_value.startswith("opencode/"):
        return "opencode"
    raise ValueError(f"Unknown chatbot provider: {settings_value!r}")


def api_model(provider: str, settings_value: str) -> str:
    """Model id the endpoint expects ("opencode/foo" -> "foo")."""
    if provider == "opencode":
        return settings_value.split("/", 1)[1]
    return settings_value


def provider_spec(provider: str) -> dict:
    return PROVIDERS[provider]
