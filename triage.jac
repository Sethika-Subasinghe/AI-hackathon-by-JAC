"""CareRoute - Triage Agent (T10).

Rates urgency and the care needed. It never diagnoses. Flow:
1. keyword rules find red flags (`red_flag_check`),
2. `triage_llm` (by llm) rates the case, retried once,
3. if the model fails, `rule_triage` answers instead (fallback),
4. `apply_override` makes sure the model can never rate a red-flag case lower
   than the rules do.
`triage_case` runs all of this for a CaseState and logs the timeline steps.
"""

import from models { CaseState, CaseStatus, EventStatus, Severity, UnitType }
import from agent_log { start_event, finish_event }
import from reliability { model_available, record_model_success, record_model_failure }

"""What the triage agent decides. `used_fallback` is set by code, not the model."""
obj TriageResult {
    has severity: Severity,
        unit: UnitType,
        red_flags: list[str] = [],
        confidence: float = 0.0,
        needs_followup: bool = False,
        followup_question: str = "",
        used_fallback: bool = False;
}
sem TriageResult.severity = "CRITICAL = life threatening now, URGENT = needs care within hours, STABLE = can wait or visit a clinic.";
sem TriageResult.unit = "The hospital unit needed: CARDIAC, TRAUMA, ICU, NEURO or GENERAL.";
sem TriageResult.red_flags = "Short phrases for warning signs found in the text, empty if none.";
sem TriageResult.confidence = "0.0 to 1.0, how sure you are. Use below 0.5 when the text is vague.";
sem TriageResult.needs_followup = "True only when the text is too vague to rate safely.";
sem TriageResult.followup_question = "One short question to ask the patient when needs_followup is true, otherwise empty.";
sem TriageResult.used_fallback = "Always False, set by code.";

"""One keyword rule used for the safety override and the fallback."""
obj Rule {
    has keyword: str,
        severity: Severity,
        unit: UnitType,
        label: str;
}

glob RULES: list[Rule] = [
    Rule(keyword="chest pain", severity=Severity.CRITICAL, unit=UnitType.CARDIAC, label="chest pain"),
    Rule(keyword="heart attack", severity=Severity.CRITICAL, unit=UnitType.CARDIAC, label="possible heart attack"),
    Rule(keyword="unconscious", severity=Severity.CRITICAL, unit=UnitType.ICU, label="unconscious"),
    Rule(keyword="not breathing", severity=Severity.CRITICAL, unit=UnitType.ICU, label="not breathing"),
    Rule(keyword="cannot breathe", severity=Severity.CRITICAL, unit=UnitType.ICU, label="cannot breathe"),
    Rule(keyword="can't breathe", severity=Severity.CRITICAL, unit=UnitType.ICU, label="cannot breathe"),
    Rule(keyword="difficulty breathing", severity=Severity.CRITICAL, unit=UnitType.ICU, label="difficulty breathing"),
    Rule(keyword="shortness of breath", severity=Severity.CRITICAL, unit=UnitType.ICU, label="shortness of breath"),
    Rule(keyword="severe bleeding", severity=Severity.CRITICAL, unit=UnitType.TRAUMA, label="severe bleeding"),
    Rule(keyword="bleeding heavily", severity=Severity.CRITICAL, unit=UnitType.TRAUMA, label="heavy bleeding"),
    Rule(keyword="stroke", severity=Severity.CRITICAL, unit=UnitType.NEURO, label="possible stroke"),
    Rule(keyword="face drooping", severity=Severity.CRITICAL, unit=UnitType.NEURO, label="face drooping"),
    Rule(keyword="slurred speech", severity=Severity.CRITICAL, unit=UnitType.NEURO, label="slurred speech"),
    Rule(keyword="overdose", severity=Severity.CRITICAL, unit=UnitType.ICU, label="overdose"),
    Rule(keyword="poison", severity=Severity.CRITICAL, unit=UnitType.ICU, label="poisoning"),
    Rule(keyword="seizure", severity=Severity.URGENT, unit=UnitType.NEURO, label="seizure"),
    Rule(keyword="head injury", severity=Severity.URGENT, unit=UnitType.TRAUMA, label="head injury"),
    Rule(keyword="accident", severity=Severity.URGENT, unit=UnitType.TRAUMA, label="accident"),
    Rule(keyword="fracture", severity=Severity.URGENT, unit=UnitType.TRAUMA, label="possible fracture"),
    Rule(keyword="broken bone", severity=Severity.URGENT, unit=UnitType.TRAUMA, label="possible fracture")
];

"""Higher means more urgent."""
def _rank(s: Severity) -> int {
    if s == Severity.CRITICAL {
        return 3;
    }
    if s == Severity.URGENT {
        return 2;
    }
    return 1;
}

"""Rules that match the text, most urgent first."""
def red_flag_check(text: str) -> list[Rule] {
    lowered = text.lower();
    found: list[Rule] = [];
    for r in RULES {
        if r.keyword in lowered {
            found.append(r);
        }
    }
    return sorted(found, key=lambda r: Rule : -_rank(r.severity));
}

"""Rule-based triage, used when the model fails."""
def rule_triage(text: str) -> TriageResult {
    flags = red_flag_check(text);
    if len(flags) > 0 {
        return TriageResult(
            severity=flags[0].severity,
            unit=flags[0].unit,
            red_flags=[f.label for f in flags],
            confidence=0.6,
            used_fallback=True
        );
    }
    if len(text.split()) < 3 {
        return TriageResult(
            severity=Severity.STABLE,
            unit=UnitType.GENERAL,
            confidence=0.2,
            needs_followup=True,
            followup_question="Can you describe the symptoms in a few more words?",
            used_fallback=True
        );
    }
    return TriageResult(
        severity=Severity.STABLE,
        unit=UnitType.GENERAL,
        confidence=0.4,
        used_fallback=True
    );
}

"""Safety override: the model can raise severity but never lower it below the rules."""
def apply_override(result: TriageResult, text: str) -> TriageResult {
    flags = red_flag_check(text);
    if len(flags) == 0 {
        return result;
    }
    labels = list(result.red_flags);
    for f in flags {
        if f.label not in labels {
            labels.append(f.label);
        }
    }
    result.red_flags = labels;
    if _rank(flags[0].severity) > _rank(result.severity) {
        result.severity = flags[0].severity;
        result.unit = flags[0].unit;
        result.needs_followup = False;
        result.followup_question = "";
    }
    return result;
}

"""Rate the case with the model."""
def triage_llm(description: str, report_summary: str) -> TriageResult by llm(temperature=0.1);
sem triage_llm = "You are a triage assistant for a hospital finder in Sri Lanka. Rate the urgency and the unit needed from the patient's text. Never diagnose and never name a disease as a conclusion. If the text is too vague, set needs_followup and ask one short question.";
sem triage_llm.description = "What the patient or family wrote.";
sem triage_llm.report_summary = "Key facts from an uploaded medical report, may be empty.";

"""Run triage for a case: model first, rules as backup, override last.
Writes the result onto the CaseState and logs the timeline steps."""
def triage_case(cs: CaseState) -> TriageResult {
    text = cs.description + " " + cs.report_summary;
    flags = red_flag_check(text);

    ev = start_event(cs, "triage", "rate_urgency", "Rating how urgent this is");
    result: TriageResult | None = None;
    for _attempt in range(2) {
        if result is None and model_available() {
            try {
                result = triage_llm(cs.description, cs.report_summary);
                record_model_success();
            } except Exception {
                record_model_failure();
                result = None;
            }
        }
    }
    used_fallback = result is None;
    if result is None {
        result = rule_triage(text);
    }
    result.used_fallback = used_fallback;
    result = apply_override(result, text);

    if result.needs_followup and len(flags) == 0 {
        cs.status = CaseStatus.NEEDS_INFO;
    } else {
        result.needs_followup = False;
        cs.status = CaseStatus.TRIAGED;
    }
    cs.severity = result.severity;
    cs.unit_needed = result.unit;
    cs.red_flags = result.red_flags;
    cs.confidence = result.confidence;
    cs.followup_question = result.followup_question;
    cs.used_fallback = cs.used_fallback or used_fallback;

    detail = f"Unit: {result.unit.name}. Confidence: {result.confidence}. Red flags: {', '.join(result.red_flags) or 'none'}.";
    if used_fallback {
        detail += " Using backup logic.";
    }
    finish_event(
        ev,
        EventStatus.DONE,
        f"Rated {result.severity.name}, needs {result.unit.name} care",
        detail
    );
    return result;
}
