"""Maps Settings.chatBotApi values to provider ids.

Current QML values (ChatBotWidget.qml providers) all route to openrouter.
Future agent backends (agent/opencode, agent/hermes) get new files here;
QML needs no change because it keeps passing the settings value through.
"""

_OPENROUTER_VALUES = {
    "openrouter/free",
    "openrouter/auto",
    "openai/gpt-4o-mini",
    "qwen/qwen3.5-9b",
    "meta-llama/llama-3.2-1b-instruct",
    "mistralai/ministral-8b-2512",
}


def resolve_provider(settings_value: str) -> str:
    if settings_value in _OPENROUTER_VALUES:
        return "openrouter"
    raise ValueError(f"Unknown chatbot provider: {settings_value!r}")
