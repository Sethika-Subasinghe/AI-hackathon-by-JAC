"""One unit's live bed card with a +/- BedStepper (hospital dashboard)."""

sv import from hospitals { UnitView }

def:pub BedCard(
    unit: UnitView,
    busy: bool,
    on_adjust: Callable[[str, int], None],
) -> JsxElement {
    # Named handlers (not lambdas): a lambda inside a list slot compiles to a render-time call.
    def decrease(_e: MouseEvent) { on_adjust(unit.unit_type, -1); }
    def increase(_e: MouseEvent) { on_adjust(unit.unit_type, 1); }

    percent: int = (unit.free * 100) // max(unit.total, 1);
    label: str = unit.unit_type + ": " + str(unit.free) + " free of " + str(unit.total);

    return <article className="bed-card">
        <div className="bed-card-top">
            <span className="bed-unit">{unit.unit_type}</span>
            <span className="bed-total">{str(unit.total) + " total"}</span>
        </div>
        <strong className="bed-count">{str(unit.free)}<small> free beds</small></strong>
        <div className="bed-meter" aria-label={label}><span style={{"width": str(percent) + "%"}}></span></div>
        <div className="bed-stepper" aria-label={"Change " + unit.unit_type + " free beds"}>
            <button
                type="button"
                aria-label={"Decrease " + unit.unit_type + " free beds"}
                disabled={busy or unit.free == 0}
                onClick={decrease}
            >-</button>
            <span>{str(unit.free) + " / " + str(unit.total)}</span>
            <button
                type="button"
                aria-label={"Increase " + unit.unit_type + " free beds"}
                disabled={busy or unit.free == unit.total}
                onClick={increase}
            >+</button>
        </div>
    </article>;
}
