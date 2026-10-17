"""Hospital side: keep the number of patients waiting for each surgery up to date."""

import "../assets/surgery.css";
import from react { useEffect }
sv import from surgery { SurgeryListView, my_surgery_lists, change_surgery_waiting, change_surgery_capacity, set_surgery_offered, set_surgery_waiting }
sv import from data.surgery_seed { SurgeryInfo }
sv import from surgery { list_surgery_catalog }

def _weeks_text(weeks: float) -> str {
    if weeks < 1.0 {
        return "under 1 week";
    }
    return "about " + str(int(weeks + 0.5)) + " weeks";
}

"""One surgery on the hospital's list with two steppers: patients waiting, operations per week."""
def:pub SurgeryRow(
    item: SurgeryListView,
    busy: bool,
    on_waiting: Callable[[str, int], None],
    on_capacity: Callable[[str, int], None],
    on_remove: Callable[[str], None],
) -> JsxElement {
    # Named handlers, because a lambda inside a list slot would run while rendering.
    def waiting_less(_e: MouseEvent) { on_waiting(item.surgery_code, -1); }
    def waiting_more(_e: MouseEvent) { on_waiting(item.surgery_code, 1); }
    def waiting_less_ten(_e: MouseEvent) { on_waiting(item.surgery_code, -10); }
    def waiting_more_ten(_e: MouseEvent) { on_waiting(item.surgery_code, 10); }
    def capacity_less(_e: MouseEvent) { on_capacity(item.surgery_code, -1); }
    def capacity_more(_e: MouseEvent) { on_capacity(item.surgery_code, 1); }
    def remove(_e: MouseEvent) { on_remove(item.surgery_code); }

    return <article className="sl-row">
        <div className="sl-title">
            <div>
                <p className="sl-name">{item.name}</p>
                <p className="sl-speciality">{item.speciality}</p>
            </div>
            <span className="sl-wait" aria-label="Expected wait">{_weeks_text(item.wait_weeks)}</span>
        </div>
        <div className="sl-controls">
            <div className="sl-control">
                <p className="sl-label">Patients waiting</p>
                <div className="sl-stepper" role="group" aria-label={"Patients waiting for " + item.name}>
                    <button type="button" onClick={waiting_less_ten} disabled={busy or item.waiting < 10} aria-label="Remove 10">-10</button>
                    <button type="button" onClick={waiting_less} disabled={busy or item.waiting == 0} aria-label="Remove 1">-</button>
                    <strong>{str(item.waiting)}</strong>
                    <button type="button" onClick={waiting_more} disabled={busy} aria-label="Add 1">+</button>
                    <button type="button" onClick={waiting_more_ten} disabled={busy} aria-label="Add 10">+10</button>
                </div>
            </div>
            <div className="sl-control">
                <p className="sl-label">Operations per week</p>
                <div className="sl-stepper" role="group" aria-label={"Operations per week for " + item.name}>
                    <button type="button" onClick={capacity_less} disabled={busy or item.weekly_capacity <= 1} aria-label="Fewer per week">-</button>
                    <strong>{str(item.weekly_capacity)}</strong>
                    <button type="button" onClick={capacity_more} disabled={busy} aria-label="More per week">+</button>
                </div>
            </div>
        </div>
        <button type="button" className="sl-remove" onClick={remove} disabled={busy}>Stop offering this surgery</button>
    </article>;
}

def:pub SurgeryLists(token: str) -> JsxElement {
    has lists: list[SurgeryListView] = [],
        catalog: list[SurgeryInfo] = [],
        add_code: str = "",
        busy: bool = False,
        notice: str = "";

    async def refresh() -> None {
        if token == "" {
            return;
        }
        latest = await my_surgery_lists(token);
        if latest is not None {
            lists = latest;
        }
    }

    async can with entry {
        catalog = await list_surgery_catalog();
        await refresh();
    }

    # Pick up patients who join a list, every 5 seconds.
    useEffect(lambda {
        interval = setInterval(lambda { refresh(); }, 5000);
        return lambda { clearInterval(interval); };
    }, [token]);

    async def change_waiting(code: str, delta: int) -> None {
        busy = True;
        updated = await change_surgery_waiting(token, code, delta);
        busy = False;
        if updated is not None {
            lists = updated;
            notice = "Waiting list updated.";
        }
    }

    async def change_capacity(code: str, delta: int) -> None {
        busy = True;
        updated = await change_surgery_capacity(token, code, delta);
        busy = False;
        if updated is not None {
            lists = updated;
            notice = "Weekly capacity updated.";
        }
    }

    async def remove_surgery(code: str) -> None {
        busy = True;
        updated = await set_surgery_offered(token, code, False);
        busy = False;
        if updated is not None {
            lists = updated;
            notice = "That surgery is no longer offered.";
        }
    }

    def update_add(e: ChangeEvent) { add_code = e.target.value; }

    async def add_surgery(_e: MouseEvent) -> None {
        if add_code == "" {
            return;
        }
        busy = True;
        updated = await set_surgery_offered(token, add_code, True);
        busy = False;
        if updated is not None {
            lists = updated;
            notice = "Surgery added. Set how many patients are waiting.";
            add_code = "";
        }
    }

    offered: list[str] = [l.surgery_code for l in lists];
    available: list[SurgeryInfo] = [s for s in catalog if s.code not in offered];
    total_waiting: int = 0;
    for l in lists {
        total_waiting += l.waiting;
    }

    return <section className="surgery-lists" aria-label="Surgery waiting lists">
        <div className="sl-head">
            <h4>Surgery waiting lists</h4>
            <span className="sl-total">{str(total_waiting) + " patients waiting in total"}</span>
        </div>
        <p className="sl-help">Keep these numbers current. Patients choose hospitals by expected wait, so honest numbers send patients to the right place.</p>
        {if notice != "" {
            <p className="sl-notice" role="status">{notice}</p>
        }}
        {if len(lists) == 0 {
            <p className="sl-empty">This hospital does not offer any planned surgery yet. Add one below.</p>
        }}
        <div className="sl-list">
            {for item in lists {
                <SurgeryRow key={item.surgery_code} item={item} busy={busy} on_waiting={change_waiting} on_capacity={change_capacity} on_remove={remove_surgery}/>
            }}
        </div>
        {if len(available) > 0 {
            <div className="sl-add">
                <label htmlFor="sl-add-select">Offer another surgery</label>
                <div className="sl-add-row">
                    <select id="sl-add-select" value={add_code} onChange={update_add}>
                        <option value="">Choose a surgery</option>
                        {for s in available {
                            <option key={s.code} value={s.code}>{s.name}</option>
                        }}
                    </select>
                    <button type="button" className="app-button" onClick={add_surgery} disabled={busy or add_code == ""}>Add to my hospital</button>
                </div>
            </div>
        }}
    </section>;
}
