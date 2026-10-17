"""Handler bodies for PatientFlow."""

impl PatientFlow.update_description(e: ChangeEvent) {
    description = e.target.value;
}

impl PatientFlow.pick_example(text: str) {
    description = text;
}

impl PatientFlow.load_demo_scenario {
    description = "My father has sudden chest pain and is sweating. We are near central Colombo.";
    address = "Colombo, Sri Lanka";
    lat = 6.9271;
    lon = 79.8612;
    location_ready = True;
    locating = False;
    suggestions = [];
    picked_file = None;
    file_name = "";
    error = "";
}

impl PatientFlow.update_address(e: ChangeEvent) -> None {
    value = e.target.value;
    address = value;
    location_ready = False;
    if len(value.strip()) >= 3 {
        address_searching = True;
        address_feedback = "";
        try {
            suggestions = await autocomplete(value, 5);
            if len(suggestions) == 0 {
                address_feedback = "No matching addresses found. Try a nearby town or district.";
            }
        } except Exception {
            suggestions = [];
            address_feedback = "Address search is temporarily unavailable. You can still enter the address and continue.";
        }
        address_searching = False;
    } else {
        suggestions = [];
        address_searching = False;
        address_feedback = "";
    }
}

impl PatientFlow.pick_suggestion(label: str, s_lat: float, s_lon: float) {
    address = label;
    lat = s_lat;
    lon = s_lon;
    location_ready = True;
    suggestions = [];
    address_feedback = "";
}

impl PatientFlow.use_my_location() {
    error = "";
    nav: any = navigator;
    if not nav.geolocation {
        error = "Your browser cannot share its location. Please type an address instead.";
        return;
    }
    locating = True;
    nav.geolocation.getCurrentPosition(
        lambda(pos: any) {
            lat = pos.coords.latitude as float;
            lon = pos.coords.longitude as float;
            address = "My current location";
            location_ready = True;
            suggestions = [];
            locating = False;
        },
        lambda(_err: any) {
            locating = False;
            error = "We could not get your location. Please type an address instead.";
        }
    );
}

impl PatientFlow.pick_file(e: ChangeEvent) {
    target: any = e.target;
    files: any = target.files;
    if files and files.length > 0 {
        picked_file = files[0];
        file_name = files[0].name as str;
    }
}

impl PatientFlow.drop_file(e: Event) {
    e.preventDefault();
    ev: any = e;
    files: any = ev.dataTransfer.files;
    if files and files.length > 0 {
        picked_file = files[0];
        file_name = files[0].name as str;
    }
}

impl PatientFlow.remove_file() {
    picked_file = None;
    file_name = "";
}

impl PatientFlow.submit_intake(e: FormEvent) -> None {
    e.preventDefault();
    error = "";
    if description.strip() == "" {
        error = "Please describe what is happening.";
        return;
    }
    submitting = True;
    use_lat = lat;
    use_lon = lon;
    if not location_ready {
        if address.strip() == "" {
            submitting = False;
            error = "Please tell us where the patient is, or tap Use my location.";
            return;
        }
        try {
            found = await geocode(address);
        } except Exception {
            submitting = False;
            error = "Location search is temporarily unavailable. Please try again or use your location.";
            return;
        }
        if not found.ok {
            submitting = False;
            error = "We could not find that address. Try a nearby town or use your location.";
            return;
        }
        use_lat = found.lat;
        use_lon = found.lon;
    }
    lat = use_lat;
    lon = use_lon;
    new_id = "";
    try {
        new_id = await create_case(description.strip(), use_lat, use_lon, address, picked_file is not None);
    } except Exception {
        submitting = False;
        error = "We could not start your request. Please check your connection and try again.";
        return;
    }
    case_error = "";
    if picked_file is not None {
        form_class: any = FormData;
        form: any = new(form_class);  # jac:ignore[E1053]
        form.append("case_id", new_id);
        form.append("file", picked_file);
        try {
            upload_response: any = await fetch("/function/upload_report", {"method": "POST", "body": form});
            if not upload_response.ok {
                case_error = "We could not attach the PDF. The request will continue with your description.";
            }
        } except Exception {
            case_error = "We could not attach the PDF. The request will continue with your description.";
        }
    }
    case_id = new_id;
    submitting = False;
    # Start the agents. Do not wait: the page keeps polling while they work.
    run_case_by_id(new_id);
}

impl PatientFlow.refresh_case() -> None {
    if case_id == "" {
        return;
    }
    try {
        latest = await get_case(case_id);
        if latest is not None {
            current = latest;
            # Fetch match result when the case is matched or done.
            if latest.status in ["MATCHED", "DONE", "DISPATCHING", "DISPATCHED"] and match_result is None {
                mr = await get_match(case_id);
                if mr is not None {
                    match_result = mr;
                }
            }
        }
        events = await case_events(case_id);
        if latest is not None and latest.hospital_id != "" {
            shown_id = match_result.best.hospital_id if match_result is not None and match_result.best is not None else "";
            if shown_id != latest.hospital_id {
                match_result = await get_match(case_id);
            }
        }
        if latest is not None and latest.severity == "CRITICAL" {
            dispatch = await get_dispatch(case_id);
        }
        case_error = "";
    } except Exception {
        case_error = "We could not refresh this request just now. We will keep trying automatically.";
    }
}

impl PatientFlow.cancel_countdown() -> None {
    if case_id == "" {
        return;
    }
    dispatch = await cancel_dispatch(case_id);
}

impl PatientFlow.update_followup(e: ChangeEvent) {
    followup_answer = e.target.value;
}

impl PatientFlow.send_followup(e: FormEvent) -> None {
    e.preventDefault();
    if followup_answer.strip() == "" {
        return;
    }
    await answer_followup(case_id, followup_answer.strip());
    followup_answer = "";
    run_case_by_id(case_id);
}

impl PatientFlow.start_over() {
    case_id = "";
    current = None;
    case_error = "";
    events = [];
    dispatch = None;
    match_result = None;
    description = "";
    address = "";
    location_ready = False;
    picked_file = None;
    file_name = "";
    error = "";
    address_feedback = "";
    address_searching = False;
    match_result = None;
}
