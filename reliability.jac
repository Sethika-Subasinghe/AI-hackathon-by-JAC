"""CareRoute - reliability guardrails (T25).

* Every model call gets a 15 second timeout (`litellm.request_timeout`).
* A circuit breaker stops calling a failing model: after BREAKER_FAILURES
  failures in a row the agents use their backup logic for BREAKER_PAUSE_SECONDS,
  so a bad key or a rate limit costs one slow call, not one per step.
* `get_system_status` tells the UI whether to show the "Using backup logic" banner.

Agents use it like this:

    if model_available() {
        try { result = some_llm_call(); record_model_success(); }
        except Exception { record_model_failure(); }
    }
"""

import time;
import litellm;

glob MODEL_TIMEOUT_SECONDS: float = 15.0;
glob BREAKER_FAILURES: int = 2;
glob BREAKER_PAUSE_SECONDS: float = 60.0;
glob breaker: dict[str, float] = {"failures": 0.0, "open_until": 0.0};

with entry {
    litellm.request_timeout = MODEL_TIMEOUT_SECONDS;
}

"""False while the breaker is open (the model keeps failing)."""
def model_available() -> bool {
    return time.time() >= breaker["open_until"];
}

def record_model_success() {
    breaker["failures"] = 0.0;
    breaker["open_until"] = 0.0;
}

def record_model_failure(error_text: str = "") {
    # A rejected key or missing model never fixes itself: open the breaker at once.
    lowered = error_text.lower();
    permanent = "authentication" in lowered or "api key" in lowered or "api_key" in lowered or "not found" in lowered;
    breaker["failures"] += 1.0;
    if permanent or breaker["failures"] >= float(BREAKER_FAILURES) {
        breaker["open_until"] = time.time() + BREAKER_PAUSE_SECONDS;
        breaker["failures"] = 0.0;
    }
}

"""Close the breaker again (tests and the demo reset button)."""
def reset_breaker() {
    breaker["failures"] = 0.0;
    breaker["open_until"] = 0.0;
}

"""System health for the UI."""
obj SystemStatus {
    has model_ok: bool,
        backup_logic: bool,
        message: str;
}

"""Poll this to show a global "Using backup logic" banner when the model is paused."""
def:pub get_system_status() -> SystemStatus {
    # Touch the graph so the server does not serve a cached answer after the breaker changes.
    _seen = len([root.shared -->]);
    ok = model_available();
    return SystemStatus(
        model_ok=ok,
        backup_logic=not ok,
        message="" if ok else "Using backup logic: the AI model is temporarily unavailable, results use built-in rules."
    );
}
