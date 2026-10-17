"""Small reusable CareRoute presentation primitives."""


def:pub StatusBadge(label: str, tone: str = "info") -> JsxElement {
    return <span className={"status-badge " + tone}><span className="status-dot" aria-hidden="true"></span>{label}</span>;
}


def:pub SurfaceCard(
    eyebrow: str,
    title: str,
    accent: bool = False,
    children: any = None,
) -> JsxElement {
    card_class: str = "surface-card accent" if accent else "surface-card";
    return <section className={card_class}>
        <p className="eyebrow">{eyebrow}</p>
        <h2>{title}</h2>
        {children}
    </section>;
}


def:pub AppButton(
    label: str,
    on_press: Callable[[], None] | None = None,
    secondary: bool = False,
    disabled: bool = False,
) -> JsxElement {
    def handle_press(_e: MouseEvent) {
        if on_press and not disabled { on_press(); }
    }

    button_class: str = "app-button secondary" if secondary else "app-button";
    return <button type="button" className={button_class} disabled={disabled} onClick={handle_press}>
        {label}
    </button>;
}


def:pub EmptyState(
    icon: str,
    title: str,
    detail: str,
    children: any = None,
) -> JsxElement {
    return <div className="empty-state">
        <span className="empty-icon" aria-hidden="true">{icon}</span>
        <div className="empty-copy"><h3>{title}</h3><p>{detail}</p></div>
        <div className="empty-action">{children}</div>
    </div>;
}
