"""Tests for reliability.jac (annex)."""

test "the breaker opens after repeated failures and closes after the pause" {
    reset_breaker();
    assert model_available();
    record_model_failure();
    assert model_available();
    record_model_failure();
    assert not model_available();
    status = get_system_status();
    assert status.backup_logic;
    assert "backup logic" in status.message.lower();
    breaker["open_until"] = time.time() - 1.0;
    assert model_available();
    assert get_system_status().model_ok;
}

test "a success resets the failure count" {
    reset_breaker();
    record_model_failure();
    record_model_success();
    record_model_failure();
    assert model_available();
    reset_breaker();
}

test "the model timeout is set" {
    assert litellm.request_timeout == MODEL_TIMEOUT_SECONDS;
}

test "a rejected key opens the breaker at once" {
    reset_breaker();
    record_model_failure("litellm.AuthenticationError: API key not valid");
    assert not model_available();
    reset_breaker();
    record_model_failure("read timed out");
    assert model_available();
    reset_breaker();
}
