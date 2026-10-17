"""CareRoute - shared graph model (T05).

Graph layout:
    root --> Hospital --HasUnit--> Unit --HasBeds--> BedStatus
    root --> CaseState --CaseEvent--> AgentEvent
                       --CaseRequest--> Request
    root --> ClinicPatient

Every agent and endpoint reads and writes these types, so change them only
with a note in progress.md "Shared notes".
"""

enum Severity { CRITICAL, URGENT, STABLE }

enum Sector { PUBLIC, PRIVATE }

enum UnitType { CARDIAC, TRAUMA, ICU, NEURO, GENERAL }

enum CaseStatus {
    NEW,
    NEEDS_INFO,
    TRIAGED,
    MATCHED,
    DISPATCHING,
    DISPATCHED,
    REPLANNING,
    DONE,
    CANCELLED
}

enum EventStatus { RUNNING, DONE, FAILED, WAITING }

enum RequestKind { AMBULANCE, POLICE, HOSPITAL_ALERT }

enum RequestStatus { PENDING, SENT, ACCEPTED, DECLINED, CANCELLED, TIMEOUT }

"""A point on the map (Geoapify uses lat/lon)."""
obj Location {
    has lat: float = 0.0,
        lon: float = 0.0,
        address: str = "";
}

"""A hospital. Hospital staff log in against `username` (T06 adds auth)."""
node Hospital {
    has name: str,
        sector: Sector,
        city: str,
        lat: float,
        lon: float,
        phone: str = "",
        username: str = "";
}

"""A care unit inside a hospital, for example its ICU."""
node Unit {
    has unit_type: UnitType;
}

"""Live bed counts for one unit. Hospital staff change `free`."""
node BedStatus {
    has total: int,
        free: int,
        updated_at: float = 0.0;
}

"""One emergency case. Agents share it as the case state."""
node CaseState {
    has description: str,
        origin: Location,
        has_pdf: bool = False,
        report_summary: str = "",
        severity: Severity = Severity.STABLE,
        unit_needed: UnitType = UnitType.GENERAL,
        red_flags: list[str] = [],
        confidence: float = 0.0,
        followup_question: str = "",
        status: CaseStatus = CaseStatus.NEW,
        hospital_id: str = "",
        eta_minutes: float = 0.0,
        excluded_hospital_ids: list[str] = [],
        replan_count: int = 0,
        used_fallback: bool = False,
        created_at: float = 0.0;
}

"""One visible agent step, shown in the UI timeline."""
node AgentEvent {
    has case_id: str,
        agent: str,
        step: str,
        status: EventStatus,
        title: str,
        detail: str = "",
        timestamp: float = 0.0;
}

"""Simulated ambulance, police or hospital request for a case."""
node Request {
    has case_id: str,
        kind: RequestKind,
        target: str,
        message: str,
        status: RequestStatus = RequestStatus.PENDING,
        priority: str = "high",
        simulated: bool = True,
        created_at: float = 0.0;
}

"""Saved profile for a clinic patient. Emergency users get no profile."""
node ClinicPatient {
    has name: str,
        email: str,
        clinic: str,
        hospital_id: str,
        clinic_date: str,
        condition_note: str = "";
}

edge HasUnit: Hospital --> Unit {}

edge HasBeds: Unit --> BedStatus {}

edge CaseEvent: CaseState --> AgentEvent {}

edge CaseRequest: CaseState --> Request {}
