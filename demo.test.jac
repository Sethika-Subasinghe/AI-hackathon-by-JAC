import from models {
    AgentEvent, CaseEvent, CaseRequest, CaseState, ClinicPatient, EventStatus,
    HasBeds, HasUnit, Hospital, Location, MailItem, ReminderTask, Request,
    RequestKind
}
import from hospitals { list_hospitals }
import from clinic { SIM }
import from demo { reset_demo_data }

test "reset clears demo records, restores beds and resets the simulated clock" {
    reset_demo_data();

    cs = (root.shared ++> CaseState(
        description="Demo test case",
        origin=Location(lat=6.9271, lon=79.8612, address="Colombo")
    ))[0];
    cs +>:CaseEvent():+> AgentEvent(
        case_id=jid(cs),
        agent="triage",
        step="triage",
        status=EventStatus.DONE,
        title="Test event"
    );
    cs +>:CaseRequest():+> Request(
        case_id=jid(cs),
        kind=RequestKind.AMBULANCE,
        target="Demo ambulance",
        message="Test request"
    );
    root.shared ++> ClinicPatient(
        name="Demo patient",
        phone="0771234567",
        contact_role="PATIENT",
        clinic="Demo clinic",
        hospital_id="demo-colombo-central",
        clinic_date="2030-01-01",
        clinic_time="09:00"
    );
    root.shared ++> ReminderTask(patient_id="demo-patient", kind="DAY_BEFORE", due_at=1.0);
    root.shared ++> MailItem(
        patient_id="demo-patient",
        channel="SMS",
        to="0771234567",
        subject="Demo reminder",
        body="Test phone message"
    );
    SIM["offset_hours"] = 48.0;
    colombo = [h for h in list_hospitals() if h.name == "Colombo Central Care Hospital (Demo)"][0];
    for h in [root.shared -->][?:Hospital] {
        if jid(h) == colombo.id {
            for unit in [h ->:HasUnit:->] {
                if unit.unit_type.name == "CARDIAC" {
                    for beds in [unit ->:HasBeds:->] {
                        beds.free = 0;
                    }
                }
            }
        }
    }

    result = reset_demo_data();

    assert result.cases_removed == 1;
    assert result.clinic_profiles_removed == 1;
    assert result.hospitals_restored == 10;
    assert len([root.shared -->][?:CaseState]) == 0;
    assert len([root.shared -->][?:ClinicPatient]) == 0;
    assert len([root.shared -->][?:ReminderTask]) == 0;
    assert len([root.shared -->][?:MailItem]) == 0;
    assert SIM["offset_hours"] == 0.0;
    restored = [h for h in list_hospitals() if h.name == "Colombo Central Care Hospital (Demo)"][0];
    cardiac = [u for u in restored.units if u.unit_type == "CARDIAC"][0];
    assert cardiac.free == 6;
}
