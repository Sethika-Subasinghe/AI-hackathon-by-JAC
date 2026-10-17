"""Tests for agent_log.jac (annex) plus a MockLLM check of the by-llm convention."""

import os;
import sys;
import from byllm.lib { Model, MockLLM }
import from models { Location, Severity, UnitType }

"""Mock model only while `jac test` runs; normal runs keep the real model."""
glob llm = MockLLM(model_name="mockllm", config={"outputs": [Severity.URGENT]})
    if sys.argv[1:2] == ["test"] else Model(model_name=os.environ.get("LLM_MODEL", "gemini/gemini-2.0-flash"));

def rate(text: str) -> Severity by llm(temperature=0.2);
sem rate = "Rate the urgency of the described case. Never diagnose.";
sem rate.text = "The compact case facts.";

test "event log lifecycle" {
    cs = (root.shared ++> CaseState(
        description="chest pain",
        origin=Location(lat=6.9, lon=79.8)
    ))[0];
    cid = jid(cs);

    ev = start_event(cs, "triage", "rate", "Rating urgency");
    first = case_events(cid);
    assert len(first) == 1;
    assert first[0].status == "RUNNING";

    finish_event(ev, EventStatus.DONE, "Urgent", "unit: cardiac");
    log_event(cs, "matcher", "find", EventStatus.WAITING, "Waiting for hospital");

    events = case_events(cid);
    assert len(events) == 2;
    assert events[0].status == "DONE";
    assert events[0].title == "Urgent";
    assert events[1].agent == "matcher";
    assert case_events("no-such-case") == [];
}

test "compact case and typed llm output" {
    cs = (root.shared ++> CaseState(
        description="stomach ache",
        origin=Location(lat=6.9, lon=79.8)
    ))[0];
    text = compact_case(cs);
    assert "stomach ache" in text;
    assert rate(text) == Severity.URGENT;
}
