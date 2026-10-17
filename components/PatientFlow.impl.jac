"""Handler bodies for PatientFlow."""

impl PatientFlow.update_description(e: ChangeEvent) {
    description = e.target.value;
}

impl PatientFlow.pick_example(text: str) {
    description = text;
}

impl PatientFlow.update_address(e: ChangeEvent) -> None {
    value = e.target.value;
    address = value;
    location_ready = False;
    if len(value.strip()) >= 3 {
        suggestions = await autocomplete(value, 5);
    } else {
        suggestions = [];
    }
}

impl PatientFlow.pick_suggestion(label: str, s_lat: float, s_lon: float) {
    address = label;
    lat = s_lat;
    lon = s_lon;
    location_ready = True;
    suggestions = [];
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
        found = await geocode(address);
        if not found.ok {
            submitting = False;
            error = "We could not find that address. Try a nearby town or use your location.";
            return;
        }
        use_lat = found.lat;
        use_lon = found.lon;
    }
    new_id = await create_case(description.strip(), use_lat, use_lon, address, picked_file is not None);
    if picked_file is not None {
        form_class: any = FormData;
        form: any = new(form_class);  # jac:ignore[E1053]
        form.append("case_id", new_id);
        form.append("file", picked_file);
        try {
            await fetch("/function/upload_report", {"method": "POST", "body": form});
        } except Exception {
            error = "";
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
    latest = await get_case(case_id);
    if latest is not None {
        current = latest;
    }
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
    description = "";
    address = "";
    location_ready = False;
    picked_file = None;
    file_name = "";
    error = "";
}
