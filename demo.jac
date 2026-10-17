"""Demo-only helpers for restoring CareRoute's fictional data to a clean state."""

import from models {
    CaseEvent, CaseRequest, CaseState, ClinicPatient, MailItem, ReminderTask
}
import from hospitals { reset_demo_hospitals }
import from clinic { reset_simulated_clock }
import from reliability { reset_breaker }
import from matcher { matches }
import from replan { replanning }
import from orchestrator { FAIL_STEP }
import from dispatch { AUTO_ACCEPT }
import from surgery { reset_surgery_lists }

"""Counts of demo records removed and hospital records restored."""
obj DemoResetResult {
    has cases_removed: int,
        clinic_profiles_removed: int,
        hospitals_restored: int,
        message: str;
}

"""Clear fictional case and clinic data, restore demo beds and reset simulation state."""
def:pub reset_demo_data -> DemoResetResult {
    cases = [root.shared -->][?:CaseState];
    for cs in cases {
        for event in [cs ->:CaseEvent:->] {
            del event;
        }
        for request in [cs ->:CaseRequest:->] {
            del request;
        }
        del cs;
    }

    profiles = [root.shared -->][?:ClinicPatient];
    for profile in profiles {
        del profile;
    }
    for task in [root.shared -->][?:ReminderTask] {
        del task;
    }
    for item in [root.shared -->][?:MailItem] {
        del item;
    }

    hospitals_restored = reset_demo_hospitals();
    reset_surgery_lists();
    reset_simulated_clock();
    reset_breaker();
    matches.clear();
    replanning.clear();
    FAIL_STEP["step"] = "";
    AUTO_ACCEPT["on"] = True;

    return DemoResetResult(
        cases_removed=len(cases),
        clinic_profiles_removed=len(profiles),
        hospitals_restored=hospitals_restored,
        message="Demo data reset. Cases and clinic profiles were cleared, bed counts and surgery waiting lists restored, and simulated time reset."
    );
}
