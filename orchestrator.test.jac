"""Tests for orchestrator.jac (annex). The decide_next model is a MockLLM.
Triage falls back to its keyword rules here because no real model is configured."""

import os;
import sys;
import from byllm.lib { Model, MockLLM }
import from agent_log { case_events }
import from matcher { LIVE_SERVICES }
import from dispatch { LIVE_MODEL }

"""Mock model only while `jac test` runs; normal runs keep the real model."""
glob llm = MockLLM(model_name="mockllm", config={"outputs": [
    NextAction(step=Step.TRIAGE, reason="new case"),
    NextAction(step=Step.MATCH, reason="triaged"),
    NextAction(step=Step.DISPATCH, reason="critical"),
    NextAction(step=Step.FINISH, reason="done"),
    NextAction(step=Step.TRIAGE, reason="new case"),
    NextAction(step=Step.ASK_FOLLOWUP, reason="vague")
]})
    if sys.argv[1:2] == ["test"] else Model(model_name=os.environ.get("LLM_MODEL", "gemini/gemini-2.0-flash"));

def _case(text: str) -> CaseState {
    r = create_case(text, 6.9, 79.8);
    return find_case(r);
}

test "guard vetoes a step that is not allowed" {
    cs = _case("mild cough for two days");
    fixed = guard(NextAction(step=Step.DISPATCH, reason="model guess"), cs);
    assert fixed.step == Step.TRIAGE;
    assert "Guard changed" in fixed.reason;
    ok = guard(NextAction(step=Step.TRIAGE, reason="fine"), cs);
    assert ok.reason == "fine";
}

test "dispatch needs a critical case with a hospital" {
    cs = _case("chest pain");
    cs.status = CaseStatus.MATCHED;
    cs.severity = Severity.CRITICAL;
    assert allowed_steps(cs) == [Step.FINISH];
    cs.hospital_id = "h1";
    assert allowed_steps(cs) == [Step.DISPATCH];
    cs.severity = Severity.STABLE;
    assert allowed_steps(cs) == [Step.FINISH];
}

test "replan stops after three tries" {
    cs = _case("chest pain");
    cs.status = CaseStatus.REPLANNING;
    assert allowed_steps(cs) == [Step.REPLAN];
    cs.replan_count = 3;
    assert allowed_steps(cs) == [Step.FINISH];
}

test "critical case runs triage, match, dispatch and finish" {
    LIVE_SERVICES["on"] = False;
    LIVE_MODEL["on"] = False;
    cs = _case("My father has chest pain");
    steps = run_case(cs);
    assert steps == 4;
    assert cs.hospital_id != "";
    assert cs.severity == Severity.CRITICAL;
    assert cs.status == CaseStatus.DISPATCHING;
    events = case_events(jid(cs));
    agents = [e.agent for e in events];
    assert "orchestrator" in agents;
    assert "triage" in agents;
    assert "matcher" in agents;
}

test "vague case asks a follow-up then waits" {
    cs = _case("help");
    run_case(cs);
    assert cs.status == CaseStatus.NEEDS_INFO;
    view = get_case(jid(cs));
    assert view is not None;
    assert view.followup_question != "";
    again = answer_followup(jid(cs), "he has chest pain");
    assert again is not None;
    assert again.status == "NEW";
    assert "chest pain" in again.description;
}

test "backup logic when the model fails" {
    LIVE_SERVICES["on"] = False;
    LIVE_MODEL["on"] = False;
    cs = _case("He is unconscious");
    run_case(cs);
    assert cs.status == CaseStatus.DISPATCHING;
    assert cs.severity == Severity.CRITICAL;
    details = [e.detail for e in case_events(jid(cs)) if e.step == "decide"];
    assert any(["Using backup logic" in d for d in details]);
}

test "unknown case ids are handled" {
    assert run_case_by_id("nope") is None;
    assert get_case("nope") is None;
}
