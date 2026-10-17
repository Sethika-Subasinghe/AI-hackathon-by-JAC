"""T12 AgentTimeline component: polls case_events once per second and shows
expandable timeline steps for every agent action.

Used by the Patient view to make every agent decision visible live.
"""

sv import from agent_log { EventView, case_events }
import from react { useEffect }


"""One step in the agent timeline."""
def _TimelineStep(ev: EventView, expanded: bool, on_toggle: Callable[[str], None]) -> JsxElement {
    def handle_toggle(_e: MouseEvent) {
        on_toggle(ev.id);
    }

    status_icon: str = "⏳" if ev.status == "RUNNING" else (
        "✅" if ev.status == "DONE" else (
            "⚠️" if ev.status == "FAILED" else "⏸"
        )
    );
    status_tone: str = "teal" if ev.status == "DONE" else (
        "critical" if ev.status == "FAILED" else (
            "urgent" if ev.status == "RUNNING" else "info"
        )
    );
    agent_label: str = ev.agent.replace("_", " ").title();

    return <li
        className={"timeline-step timeline-step--" + ev.status.lower()}
        aria-live="polite"
    >
        <button
            type="button"
            className="timeline-trigger"
            aria-expanded={expanded}
            onClick={handle_toggle}
        >
            <span className={"timeline-icon timeline-icon--" + status_tone} aria-hidden="true">{status_icon}</span>
            <div className="timeline-summary">
                <span className="timeline-title">{ev.title}</span>
                <span className="timeline-agent">{agent_label + " · " + ev.step}</span>
            </div>
            <span className="timeline-chevron" aria-hidden="true">{"▼" if expanded else "▶"}</span>
        </button>

        {expanded and <div className="timeline-detail">
            {ev.detail and <p className="timeline-detail-text">{ev.detail}</p>}
            <p className="timeline-meta">
                <span className="timeline-ts">{ev.timestamp}</span>
                {"  ·  Used backup logic" if "backup logic" in ev.detail.lower() else ""}
            </p>
        </div>}
    </li>;
}


"""Live agent timeline. Polls `case_events` every second while `case_id` is set.
Shows expandable steps, newest appended as they arrive.
Pass `case_status` to stop polling once the case is finished."""
def:pub AgentTimeline(
    case_id: str,
    case_status: str = "",
    children: any = None,
) -> JsxElement {
    has events: list[EventView] = [];
    has loading: bool = True;
    has expanded_ids: dict[str, bool] = {};

    def on_toggle(event_id: str) {
        if event_id in expanded_ids {
            del expanded_ids[event_id];
        } else {
            expanded_ids[event_id] = True;
        }
        # Force re-render by reassigning.
        expanded_ids = dict(expanded_ids);
    }

    finished_statuses: list[str] = ["DONE", "CANCELLED", "DISPATCHED", "FAILED"];

    # Poll once on mount, then every second while the case is running.
    # Per jac guide: outer lambda must NOT be annotated -> None because it returns cleanup.
    useEffect(lambda {
        active: list[bool] = [True];

        def fetch_once() {
            if case_id == "" or not active[0] { return; }
            case_events(case_id).then(lambda(result: any) {
                if result is not None and active[0] {
                    events = result;
                    loading = False;
                }
            });
        }

        fetch_once();
        interval = setInterval(lambda { fetch_once(); }, 1000);
        return lambda {
            active[0] = False;
            clearInterval(interval);
        };
    }, [case_id, case_status]);

    done: bool = case_status in finished_statuses;

    return <section className="agent-timeline" aria-label="Agent timeline" aria-live="polite">
        <div className="timeline-header">
            <h4 className="timeline-heading">Agent steps</h4>
            {loading and case_id != "" and <span className="timeline-spinner" aria-label="Loading agent events">⏳</span>}
            {done and <span className="timeline-done-badge">All steps complete</span>}
        </div>

        {if case_id == "" {
            <p className="timeline-empty">Submit a case to see the agent work here.</p>
        } elif len(events) == 0 and not loading {
            <p className="timeline-empty">No events yet — agents are starting.</p>
        }}

        <ol className="timeline-list" aria-label="Agent event steps">
            {for ev in events {
                <_TimelineStep
                    ev={ev}
                    expanded={expanded_ids.get(ev.id, False)}
                    on_toggle={on_toggle}
                    key={ev.id}
                />
            }}
        </ol>
        {children}
    </section>;
}
