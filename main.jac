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
