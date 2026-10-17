"""Tests for documents.jac (annex). The model is off, so summaries use the excerpt backup."""

import from models { Location }
import from agent_log { case_events }

def _tiny_pdf(text: str) -> bytes {
    nl = chr(10);
    content = f"BT /F1 12 Tf 10 50 Td ({text}) Tj ET";
    objs = [
        "<</Type/Catalog/Pages 2 0 R>>",
        "<</Type/Pages/Kids[3 0 R]/Count 1>>",
        "<</Type/Page/Parent 2 0 R/MediaBox[0 0 400 100]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>",
        f"<</Length {len(content)}>>" + nl + "stream" + nl + content + nl + "endstream",
        "<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>"
    ];
    out = "%PDF-1.4" + nl;
    offsets: list[int] = [];
    for i in range(len(objs)) {
        offsets.append(len(out));
        out += f"{i + 1} 0 obj" + nl + objs[i] + nl + "endobj" + nl;
    }
    xref_pos = len(out);
    out += "xref" + nl + f"0 {len(objs) + 1}" + nl + "0000000000 65535 f " + nl;
    for off in offsets {
        out += f"{off:010d} 00000 n " + nl;
    }
    out += "trailer" + nl + f"<</Size {len(objs) + 1}/Root 1 0 R>>" + nl + "startxref" + nl + f"{xref_pos}" + nl + "%%EOF";
    return out.encode();
}

def _case() -> CaseState {
    LIVE_MODEL["on"] = False;
    return (root.shared ++> CaseState(
        description="feeling dizzy",
        origin=Location(lat=6.9, lon=79.8),
        has_pdf=True
    ))[0];
}

test "text is extracted from a readable pdf" {
    text = extract_pdf_text(_tiny_pdf("Allergic to penicillin"));
    assert "penicillin" in text;
}

test "garbage bytes give empty text, never a crash" {
    assert extract_pdf_text("not a pdf".encode()) == "";
    assert extract_pdf_text("".encode()) == "";
}

test "readable report becomes a summary on the case" {
    cs = _case();
    cs.report_text = "Patient has diabetes. Allergic to penicillin. Takes metformin.";
    assert read_report(cs);
    assert "penicillin" in cs.report_summary;
    events = [e for e in case_events(jid(cs)) if e.agent == "document"];
    assert len(events) == 1;
    assert events[0].status == "DONE";
}

test "unreadable report is reported and the flow continues" {
    cs = _case();
    cs.report_text = "";
    assert not read_report(cs);
    assert cs.report_summary == "Report could not be read";
    events = [e for e in case_events(jid(cs)) if e.agent == "document"];
    assert events[0].status == "FAILED";
    assert "continuing with your description" in events[0].title;
}

test "summary flattening keeps the facts" {
    s = ReportSummary(
        summary="Known diabetic.",
        conditions=["diabetes"],
        allergies=["penicillin"],
        medicines=["metformin"],
        recent_events=["admitted in May"]
    );
    flat = _flatten(s);
    assert "penicillin" in flat and "metformin" in flat and "diabetes" in flat and "May" in flat;
}
