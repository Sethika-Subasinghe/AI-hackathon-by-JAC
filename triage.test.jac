"""Tests for triage.jac (annex). The model is a MockLLM, outputs are consumed in order."""

import from byllm.lib { MockLLM }
import from models { Location }

glob llm = MockLLM(model_name="mockllm", config={"outputs": [
    TriageResult(severity=Severity.STABLE, unit=UnitType.GENERAL, confidence=0.9),
    TriageResult(
        severity=Severity.STABLE,
        unit=UnitType.GENERAL,
        confidence=0.2,
        needs_followup=True,
        followup_question="Where does it hurt?"
    ),
    TriageResult(severity=Severity.URGENT, unit=UnitType.TRAUMA, confidence=0.8)
]});

def _new_case(text: str) -> CaseState {
    return (root.shared ++> CaseState(
        description=text,
        origin=Location(lat=6.9, lon=79.8)
    ))[0];
}

test "model cannot rate a red-flag case below the rules" {
    cs = _new_case("My father has chest pain and is sweating");
    result = triage_case(cs);
    assert result.severity == Severity.CRITICAL;
    assert result.unit == UnitType.CARDIAC;
    assert "chest pain" in result.red_flags;
    assert not result.used_fallback;
    assert cs.severity == Severity.CRITICAL;
    assert cs.status == CaseStatus.TRIAGED;
}

test "vague text asks one follow-up question" {
    cs = _new_case("help");
    result = triage_case(cs);
    assert result.needs_followup;
    assert cs.status == CaseStatus.NEEDS_INFO;
    assert cs.followup_question == "Where does it hurt?";
}

test "model rating is kept when no rule fires" {
    cs = _new_case("Fell from a bicycle and the ankle is swollen");
    result = triage_case(cs);
    assert result.severity == Severity.URGENT;
    assert result.unit == UnitType.TRAUMA;
}

test "fallback rules answer when the model fails" {
    cs = _new_case("He is unconscious after the fall");
    result = triage_case(cs);
    assert result.used_fallback;
    assert result.severity == Severity.CRITICAL;
    assert result.unit == UnitType.ICU;
    assert cs.used_fallback;
}

test "rule fallback for plain and vague text" {
    plain = rule_triage("mild cough for two days");
    assert plain.severity == Severity.STABLE;
    assert not plain.needs_followup;
    vague = rule_triage("sick");
    assert vague.needs_followup;
    assert apply_override(
        TriageResult(severity=Severity.STABLE, unit=UnitType.GENERAL),
        "seizure at home"
    ).unit == UnitType.NEURO;
}
