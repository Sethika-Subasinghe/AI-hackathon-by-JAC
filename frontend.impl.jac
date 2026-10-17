"""CareRoute shell interaction implementations."""

impl app.select_view(view: str) {
    active_view = view;
}


impl app.update_hospital_username(e: ChangeEvent) {
    hospital_username = e.target.value;
}


impl app.update_hospital_password(e: ChangeEvent) {
    hospital_password = e.target.value;
}


impl app.submit_hospital_login(e: FormEvent) -> None {
    e.preventDefault();
    hospital_error = "";
    hospital_notice = "";
    if not hospital_username.strip() or not hospital_password {
        hospital_error = "Enter both your username and password.";
        return;
    }
    hospital_loading = True;
    # T06 creates fictional demo hospitals lazily on this read endpoint.
    await list_hospitals();
    result = await hospital_login(hospital_username.strip(), hospital_password);
    hospital_loading = False;
    if result.ok {
        hospital_token = result.token;
        hospital = await my_hospital(hospital_token);
        hospital_password = "";
        if hospital is None {
            hospital_error = "Your session could not be loaded. Please sign in again.";
            hospital_token = "";
        }
    } else {
        hospital_error = result.message;
    }
}


impl app.adjust_beds(unit_type: str, delta: int) -> None {
    if hospital_token == "" or hospital is None { return; }
    updating_unit = unit_type;
    hospital_notice = "";
    updated = await change_free_beds(hospital_token, unit_type, delta);
    updating_unit = "";
    if updated is None {
        hospital = None;
        hospital_token = "";
        hospital_error = "Your session expired. Please sign in again.";
    } else {
        hospital = updated;
        hospital_notice = "Capacity updated for " + unit_type + ".";
    }
}


impl app.sign_out_hospital -> None {
    if hospital_token != "" { await hospital_logout(hospital_token); }
    hospital = None;
    hospital_token = "";
    hospital_password = "";
    hospital_notice = "";
    hospital_error = "";
}
