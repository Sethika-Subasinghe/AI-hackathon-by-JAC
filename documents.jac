"""CareRoute - Document Agent (T24).

Turns an uploaded PDF report into short medical facts for the Triage Agent:
1. `upload_report` stores the extracted text on the case (pypdf, text only),
2. the orchestrator's READ_DOCUMENT step calls `read_report`, which asks the
   model for a structured `ReportSummary` (conditions, allergies, medicines,
   recent events) and keeps only that summary for triage.

An unreadable or scanned PDF never blocks the flow: the timeline says so and
the case continues with the description alone.
"""

import io;
import from pypdf { PdfReader }
import from fastapi { UploadFile }
import from models { CaseState, EventStatus }
import from agent_log { start_event, finish_event, find_case }
import from reliability { model_available, record_model_success, record_model_failure }

glob MAX_CHARS: int = 8000;
glob LIVE_MODEL: dict[str, bool] = {"on": True};

"""Key medical facts from a report. Facts only, no diagnosis."""
obj ReportSummary {
    has summary: str,
        conditions: list[str] = [],
        allergies: list[str] = [],
        medicines: list[str] = [],
        recent_events: list[str] = [];
}
sem ReportSummary.summary = "Two or three short sentences with the facts that matter for urgent care. Do not add facts that are not in the report.";
sem ReportSummary.conditions = "Known conditions written in the report.";
sem ReportSummary.allergies = "Allergies written in the report.";
sem ReportSummary.medicines = "Current medicines written in the report.";
sem ReportSummary.recent_events = "Recent surgeries, admissions or episodes written in the report.";

"""Result of uploading a report."""
obj UploadResult {
    has ok: bool,
        message: str,
        characters: int = 0;
}

"""Read the text of a PDF. Returns an empty string if it cannot be read."""
def extract_pdf_text(data: bytes) -> str {
    try {
        reader = PdfReader(io.BytesIO(data));
        parts: list[str] = [];
        for page in reader.pages {
            parts.append(page.extract_text() or "");
        }
        return " ".join(parts).strip()[:MAX_CHARS];
    } except Exception {
        return "";
    }
}

def summarise_report(text: str) -> ReportSummary by llm(temperature=0.1);
sem summarise_report = "Extract the key medical facts from a patient's report for an emergency triage nurse. Only use what the text says. Never diagnose.";
sem summarise_report.text = "The report text.";

def _flatten(s: ReportSummary) -> str {
    parts = [s.summary];
    if len(s.conditions) > 0 {
        parts.append("Conditions: " + ", ".join(s.conditions) + ".");
    }
    if len(s.allergies) > 0 {
        parts.append("Allergies: " + ", ".join(s.allergies) + ".");
    }
    if len(s.medicines) > 0 {
        parts.append("Medicines: " + ", ".join(s.medicines) + ".");
    }
    if len(s.recent_events) > 0 {
        parts.append("Recent: " + ", ".join(s.recent_events) + ".");
    }
    return " ".join(parts);
}

"""The Document Agent step: summarise the stored report text onto the case."""
def read_report(cs: CaseState) -> bool {
    ev = start_event(cs, "document", "read_report", "Reading your report");
    text = cs.report_text.strip();
    if text == "" {
        cs.report_summary = "Report could not be read";
        finish_event(ev, EventStatus.FAILED, "Couldn't read the report, continuing with your description");
        return False;
    }
    summary = "";
    used_fallback = False;
    if LIVE_MODEL["on"] and model_available() {
        try {
            summary = _flatten(summarise_report(text));
            record_model_success();
        } except Exception as err {
            record_model_failure(str(err));
            used_fallback = True;
        }
    } else {
        used_fallback = True;
    }
    if summary == "" {
        # Backup: the first part of the text, so triage still sees the facts.
        summary = "Report excerpt: " + text[:400];
        cs.used_fallback = True;
    }
    cs.report_summary = summary;
    detail = summary[:200];
    if used_fallback {
        detail += " Using backup logic.";
    }
    finish_event(ev, EventStatus.DONE, "Report read", detail);
    return True;
}

"""Attach a PDF report to a case. Run the case afterwards so the orchestrator reads it."""
def:pub upload_report(case_id: str, file: UploadFile) -> UploadResult {
    cs = find_case(case_id);
    if cs is None {
        return UploadResult(ok=False, message="Case not found");
    }
    raw: any = file.file;  # jac:ignore[E1032]
    text = extract_pdf_text(raw.read() as bytes);
    cs.has_pdf = True;
    cs.report_text = text;
    cs.report_summary = "";
    if text == "" {
        return UploadResult(ok=True, message="We could not read text in this PDF. We will continue with your description.");
    }
    return UploadResult(ok=True, message="Report received", characters=len(text));
}
