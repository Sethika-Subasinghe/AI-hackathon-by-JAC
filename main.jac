"""AI-hackathon-by-JAC - Entry Point.

Combines server-side endpoints with the client-side UI.
"""

import from endpoints { Message, PostMessage, ListMessages }
import from hospitals {
    UnitView, HospitalView, LoginResult,
    list_hospitals, get_hospital, hospital_login, hospital_logout,
    my_hospital, set_free_beds, change_free_beds
}
import from agent_log { EventView, case_events }
import from orchestrator { CaseView, create_case, run_case_by_id, get_case, answer_followup }
import from matcher { HospitalPick, MatchResult, get_match }
import from dispatch {
    RequestView, DispatchView, AlertView,
    get_dispatch, cancel_dispatch, hospital_alerts, respond_alert
}
import from sos { start_sos, run_sos }
import from documents { ReportSummary, UploadResult, upload_report }
import from reliability { SystemStatus, get_system_status }
import from mapconfig { MapConfig, get_map_config }
import from surgery {
    SurgeryOption, SurgeryChoice, SurgeryListView, JoinResult,
    list_surgery_catalog, find_surgery_hospitals, join_surgery_list,
    my_surgery_lists, set_surgery_waiting, change_surgery_waiting,
    change_surgery_capacity, set_surgery_offered
}
import from clinic {
    MessageDraft, ClinicView, ClinicResult, MailView,
    save_clinic_patient, get_clinic_patient, clinic_inbox, skip_time,
    demo_clinic_date
}
import from demo { DemoResetResult, reset_demo_data }
import from geoapify {
    AddressSuggestion, GeocodeResult, RouteResult,
    geocode, autocomplete, get_route, get_eta
}

# Client-side UI
cl {
    import from .frontend { app as ClientApp }

    def:pub app -> JsxElement {
        return <ClientApp/>;
    }
}

