"""Agent timeline: every agent step, live, expandable, with hand-offs made visible.

Stateless apart from its own open/closed UI state. The parent polls
`case_events` and passes the list in.
"""

import "../assets/timeline.css";
sv import from agent_log { EventView }

glob AGENT_LABELS: dict[str, str] = {
    "orchestrator": "Orchestrator",
    "triage": "Triage",
    "document": "Report reader",
    "matcher": "Hospital matcher",
    "dispatch": "Dispatch",
    "replan": "Re-plan"
};

glob AGENT_BADGES: dict[str, str] = {
    "orchestrator": "OR",
    "triage": "TR",
    "document": "DO",
    "matcher": "MA",
    "dispatch": "DI",
    "replan": "RP"
};

def _label(agent: str) -> str {
    return AGENT_LABELS.get(agent, agent.title()) as str;
}

def _marker(status: str) -> str {
    if status == "DONE" {
        return "✓";
    }
    if status == "FAILED" {
        return "!";
    }
    if status == "WAITING" {
        return "…";
    }
    return "";
}

def _status_word(status: str) -> str {
    if status == "DONE" {
        return "Done";
    }
    if status == "FAILED" {
        return "Problem, handled";
    }
    if status == "WAITING" {
        return "Waiting";
    }
    return "Working";
}

def _clock(ts: float) -> str {
    when: any = new(Date, ts * 1000);  # jac:ignore[E1053]
    return when.toLocaleTimeString() as str;
}

def:pub TimelineStep(
    ev: EventView,
    prev_agent: str,
    is_open: bool,
    is_raw: bool,
    on_toggle: Callable[[str], None],
    on_raw: Callable[[str], None],
) -> JsxElement {
    def toggle(_e: MouseEvent) { on_toggle(ev.id); }
    def toggle_raw_click(_e: MouseEvent) { on_raw(ev.id); }

    highlight: str = " highlight" if ev.agent == "replan" or ev.step == "hospital_declined" else "";
    return <li className={"at-step " + ev.status.lower() + highlight}>
        {if prev_agent != "" and prev_agent != ev.agent {
            <p className="at-handoff">{"Hand-off to " + _label(ev.agent)}</p>
        }}
        <div className="at-row">
            <span className="at-badge" aria-hidden="true">{AGENT_BADGES.get(ev.agent, "AG")}</span>
            <span className={"at-state " + ev.status.lower()} aria-hidden="true">{_marker(ev.status)}</span>
            <div className="at-main">
                <p className="at-title">{ev.title}</p>
                <p className="at-meta">
                    {_label(ev.agent) + " · " + _status_word(ev.status) + " · " + _clock(ev.timestamp)}
                    {if "simulated" in ev.title.lower() or ev.agent == "dispatch" {
                        <span className="at-sim">Simulated</span>
                    }}
                </p>
            </div>
            {if ev.detail != "" {
                <button
                    type="button"
                    className="at-more"
                    aria-expanded={is_open}
                    aria-label={"Details for " + ev.title}
                    onClick={toggle}
                >{"Less" if is_open else "Details"}</button>
            }}
        </div>
        {if is_open {
            <div className="at-detail">
                <p>{ev.detail}</p>
                <button type="button" className="at-link" onClick={toggle_raw_click}>{"Hide raw" if is_raw else "Show raw"}</button>
                {if is_raw {
                    <pre className="at-raw">{JSON.stringify(ev, None, 2)}</pre>
                }}
            </div>
        }}
    </li>;
}

def:pub AgentTimeline(events: list[EventView]) -> JsxElement {
    has open_ids: list[str] = [],
        raw_ids: list[str] = [],
        collapsed: bool = False;

    def toggle_panel(_e: MouseEvent) { collapsed = not collapsed; }

    def toggle_step(step_id: str) {
        if step_id in open_ids {
            open_ids = [i for i in open_ids if i != step_id];
        } else {
            open_ids = open_ids + [step_id];
        }
    }

    def toggle_raw(step_id: str) {
        if step_id in raw_ids {
            raw_ids = [i for i in raw_ids if i != step_id];
        } else {
            raw_ids = raw_ids + [step_id];
        }
    }

    count: int = len(events);
    working: bool = len([e for e in events if e.status == "RUNNING"]) > 0;
    headline: str = "No steps yet";
    if count > 0 {
        headline = events[count - 1].title;
    }

    return <section className="agent-timeline" aria-label="What the agents are doing">
        <header className="at-head">
            <div>
                <p className="at-eyebrow">Agent activity</p>
                <h3>{headline}</h3>
            </div>
            <button
                type="button"
                className="at-toggle"
                aria-expanded={not collapsed}
                onClick={toggle_panel}
            >{"Show steps (" + str(count) + ")" if collapsed else "Hide steps"}</button>
        </header>
        {if not collapsed {
            <ol className="at-list" aria-live="polite" aria-busy={working}>
                {if count == 0 {
                    <li className="at-empty">The agents will appear here as soon as they start.</li>
                }}
                {for (i, ev) in enumerate(events) {
                    <TimelineStep
                        key={ev.id}
                        ev={ev}
                        prev_agent={events[i - 1].agent if i > 0 else ""}
                        is_open={ev.id in open_ids}
                        is_raw={ev.id in raw_ids}
                        on_toggle={toggle_step}
                        on_raw={toggle_raw}
                    />
                }}
            </ol>
        }}
    </section>;
}
