"""Placeholder blocks shown while data loads (decorative, hidden from screen readers)."""


def:pub Skeleton(count: int = 2, height: int = 96) -> JsxElement {
    blocks: list = [i for i in range(count)];
    return <div className="skeleton-grid" aria-hidden="true">
        {for i in blocks {
            <div key={str(i)} className="skeleton-block" style={{"height": str(height) + "px"}}></div>
        }}
    </div>;
}
