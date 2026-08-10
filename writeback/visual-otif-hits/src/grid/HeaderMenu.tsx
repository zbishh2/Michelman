// Header sort + filter popover (Power Query style). Anchored under the clicked
// header. Ported from the DeliveryReliability visual.

import * as React from "react";
import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import {
    ColumnFilterState, FilterDataType, opsForType, opNeedsValue, opNeedsTwoValues,
} from "../filters";
import { ScrollPane } from "./ScrollPane";

interface HeaderMenuProps {
    anchor: DOMRect;
    label: string;
    dataType: FilterDataType;
    values: string[];
    currentFilter: ColumnFilterState;
    sortDirection?: "asc" | "desc";
    hasAnyFilter: boolean;
    onSort: (dir: "asc" | "desc") => void;
    onClearSort: () => void;
    onApply: (state: ColumnFilterState) => void;
    onClearAll: () => void;
    onClose: () => void;
}

export const HeaderMenu: React.FC<HeaderMenuProps> = ({
    anchor, label, dataType, values, currentFilter, sortDirection, hasAnyFilter,
    onSort, onClearSort, onApply, onClearAll, onClose,
}) => {
    const ref = useRef<HTMLDivElement | null>(null);
    const searchRef = useRef<HTMLInputElement | null>(null);
    const scrollWrapRef = useRef<HTMLDivElement | null>(null);
    const listRef = useRef<HTMLUListElement | null>(null);
    const [pos, setPos] = useState<{ left: number; top: number }>({ left: anchor.left, top: anchor.bottom });
    const [maxH, setMaxH] = useState<number | undefined>(undefined);
    const [view, setView] = useState<"main" | "conditions">(currentFilter?.mode === "condition" ? "conditions" : "main");
    const [valueSearch, setValueSearch] = useState("");
    const [checked, setChecked] = useState<Set<string>>(
        () => currentFilter?.mode === "values" ? new Set(currentFilter.selected) : new Set(values),
    );
    const ops = opsForType(dataType);
    const [op, setOp] = useState<string>(currentFilter?.mode === "condition" ? currentFilter.op : ops[0][0]);
    const [val, setVal] = useState(currentFilter?.mode === "condition" ? currentFilter.value : "");
    const [valTo, setValTo] = useState(currentFilter?.mode === "condition" ? (currentFilter.valueTo ?? "") : "");

    // Viewport-fit placement. The popover is position:fixed and cannot escape the
    // sandbox iframe, so in a short visual it would clip. Rather than pinning it to
    // one side of the anchor (which starves the value list), size it to the whole
    // iframe: menu height = min(natural, innerHeight - 16), then shift it up/left to
    // stay on screen — it may cover the header/grid, which is fine for a popover.
    // The value checklist (flex:1, min-height in CSS) scrolls internally via
    // ScrollPane, so search + sort/clear + OK/Cancel always stay visible.
    const MARGIN = 8;
    const reposition = useCallback(() => {
        const menu = ref.current;
        if (!menu) return;
        const vw = window.innerWidth;
        const vh = window.innerHeight;
        const wrap = scrollWrapRef.current;
        const ul = listRef.current;
        // Measure with the cap lifted. menu.offsetHeight otherwise reports whatever
        // the PREVIOUS maxHeight clamped it to, so chromeH comes out short, naturalH
        // with it, and the next cap is smaller again — a ratchet that collapses the
        // menu a little on every keystroke (each one re-runs this via valueSearch).
        // ul.scrollHeight is the full (unclamped) list height either way.
        const prevMaxH = menu.style.maxHeight;
        menu.style.maxHeight = "none";
        const chromeH = wrap ? menu.offsetHeight - wrap.offsetHeight : menu.offsetHeight;
        const listH = ul ? ul.scrollHeight : 0;
        menu.style.maxHeight = prevMaxH;
        const naturalH = chromeH + listH;
        const menuH = Math.min(naturalH, vh - 2 * MARGIN);
        const width = menu.offsetWidth || 248;
        let left = anchor.left;
        if (left + width > vw - MARGIN) left = vw - width - MARGIN;
        if (left < MARGIN) left = MARGIN;
        let top = anchor.bottom;
        if (top + menuH > vh - MARGIN) top = vh - menuH - MARGIN;
        if (top < MARGIN) top = MARGIN;
        setPos({ left: Math.round(left), top: Math.round(top) });
        setMaxH(Math.round(menuH));
    }, [anchor]);

    useLayoutEffect(() => { reposition(); }, [reposition, view, valueSearch]);
    useEffect(() => {
        window.addEventListener("resize", reposition);
        return () => window.removeEventListener("resize", reposition);
    }, [reposition]);

    useEffect(() => {
        const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
        const onDown = (e: MouseEvent) => {
            if (ref.current && !ref.current.contains(e.target as Node)) onClose();
        };
        const onBlur = () => {
            window.setTimeout(() => {
                if (ref.current && ref.current.contains(document.activeElement)) return;
                onClose();
            }, 0);
        };
        document.addEventListener("keydown", onKey);
        document.addEventListener("mousedown", onDown);
        window.addEventListener("blur", onBlur);
        return () => {
            document.removeEventListener("keydown", onKey);
            document.removeEventListener("mousedown", onDown);
            window.removeEventListener("blur", onBlur);
        };
    }, [onClose]);

    useEffect(() => {
        if (view === "main") window.setTimeout(() => searchRef.current?.focus(), 0);
    }, [view]);

    const VALUE_RENDER_CAP = 500;
    const q = valueSearch.trim().toLowerCase();
    const filtered = q ? values.filter((v) => v.toLowerCase().includes(q)) : values;
    const visible = filtered.length > VALUE_RENDER_CAP ? filtered.slice(0, VALUE_RENDER_CAP) : filtered;
    const allFilteredChecked = filtered.length > 0 && filtered.every((v) => checked.has(v));
    const someFilteredChecked = filtered.some((v) => checked.has(v));

    const toggleSelectAll = () => {
        setChecked((prev) => {
            const next = new Set(prev);
            if (allFilteredChecked) filtered.forEach((v) => next.delete(v));
            else filtered.forEach((v) => next.add(v));
            return next;
        });
    };
    const toggleValue = (v: string) => {
        setChecked((prev) => {
            const next = new Set(prev);
            if (next.has(v)) next.delete(v); else next.add(v);
            return next;
        });
    };

    const labelForValue = (v: string) => (v === "" ? "(blank)" : v);
    const needsValue = opNeedsValue(op);
    const needsTwo = opNeedsTwoValues(op);
    const inputType = dataType === "date" ? "date" : dataType === "number" ? "number" : "text";

    const handleOk = () => {
        if (view === "conditions") {
            if (!needsValue) {
                onApply({ mode: "condition", op, value: "" });
            } else if (val.trim() !== "") {
                const next: ColumnFilterState = { mode: "condition", op, value: val.trim() };
                if (needsTwo && valTo.trim() !== "") next.valueTo = valTo.trim();
                onApply(next);
            } else {
                onApply(null);
            }
        } else {
            const allSelected = checked.size === values.length && values.every((v) => checked.has(v));
            if (allSelected || checked.size === 0) onApply(null);
            else onApply({ mode: "values", selected: [...checked] });
        }
        onClose();
    };

    return (
        <div className="olc-hdr-menu" ref={ref} style={{ left: pos.left, top: pos.top, maxHeight: maxH }} onContextMenu={(e) => e.preventDefault()}>
            {view === "main" ? (
                <>
                    <div className="olc-hdr-menu-section">
                        <button type="button" className={"olc-hdr-menu-item" + (sortDirection === "asc" ? " active" : "")} onClick={() => { onSort("asc"); onClose(); }}>▲ Sort ascending</button>
                        <button type="button" className={"olc-hdr-menu-item" + (sortDirection === "desc" ? " active" : "")} onClick={() => { onSort("desc"); onClose(); }}>▼ Sort descending</button>
                        <button type="button" className="olc-hdr-menu-item" disabled={!sortDirection} onClick={() => { onClearSort(); onClose(); }}>Clear sort</button>
                    </div>
                    <div className="olc-hdr-menu-section">
                        <button type="button" className="olc-hdr-menu-item" disabled={!currentFilter} onClick={() => { onApply(null); onClose(); }}>Clear filter</button>
                        <button type="button" className="olc-hdr-menu-item" disabled={!hasAnyFilter} onClick={() => { onClearAll(); onClose(); }}>Clear all filters</button>
                        <button type="button" className="olc-hdr-menu-item" onClick={() => setView("conditions")}>
                            {dataType === "number" ? "Number" : dataType === "date" ? "Date" : "Text"} filters <span className="olc-hdr-chevron">▸</span>
                        </button>
                    </div>
                    <div className="olc-hdr-filter">
                        <input
                            ref={searchRef}
                            className="olc-hdr-filter-search"
                            value={valueSearch}
                            placeholder="Search"
                            onChange={(e) => setValueSearch(e.target.value)}
                        />
                        <div className="olc-hdr-filter-scroll" ref={scrollWrapRef}>
                            <ScrollPane>
                                <ul className="olc-hdr-filter-list" ref={listRef}>
                                    <li className="olc-hdr-filter-opt" onClick={toggleSelectAll}>
                                        <span className={"olc-hdr-check" + (allFilteredChecked ? " on" : someFilteredChecked ? " some" : "")}>
                                            {allFilteredChecked ? "✓" : someFilteredChecked ? "–" : ""}
                                        </span>
                                        <span className="olc-hdr-filter-label"><b>(Select all)</b></span>
                                    </li>
                                    {visible.map((v) => (
                                        <li key={v} className="olc-hdr-filter-opt" onClick={() => toggleValue(v)}>
                                            <span className={"olc-hdr-check" + (checked.has(v) ? " on" : "")}>{checked.has(v) ? "✓" : ""}</span>
                                            <span className="olc-hdr-filter-label">{labelForValue(v)}</span>
                                        </li>
                                    ))}
                                    {filtered.length === 0 && <li className="olc-hdr-filter-opt olc-hdr-filter-empty">No matches</li>}
                                    {filtered.length > VALUE_RENDER_CAP && (
                                        <li className="olc-hdr-filter-opt olc-hdr-filter-empty">
                                            Showing {VALUE_RENDER_CAP} of {filtered.length} — search to narrow ((Select all) still applies to all)
                                        </li>
                                    )}
                                </ul>
                            </ScrollPane>
                        </div>
                    </div>
                    <div className="olc-hdr-menu-actions">
                        <button type="button" className="olc-btn" onClick={handleOk}>OK</button>
                        <button type="button" className="olc-btn" onClick={onClose}>Cancel</button>
                    </div>
                </>
            ) : (
                <>
                    <div className="olc-hdr-menu-section">
                        <button type="button" className="olc-hdr-menu-item" onClick={() => setView("main")}>
                            <span className="olc-hdr-chevron">◂</span> Back
                        </button>
                    </div>
                    <div className="olc-hdr-cond">
                        <select className="olc-hdr-cond-op" value={op} onChange={(e) => setOp(e.target.value)}>
                            {ops.map(([value, text]) => <option key={value} value={value}>{text}</option>)}
                        </select>
                        {needsValue && (
                            <input
                                className="olc-hdr-cond-val"
                                type={inputType}
                                value={val}
                                placeholder="Value"
                                autoFocus
                                onChange={(e) => setVal(e.target.value)}
                                onKeyDown={(e) => { if (e.key === "Enter" && !needsTwo) handleOk(); }}
                            />
                        )}
                        {needsValue && needsTwo && (
                            <>
                                <span className="olc-hdr-cond-and">and</span>
                                <input
                                    className="olc-hdr-cond-val"
                                    type={inputType}
                                    value={valTo}
                                    placeholder="Value"
                                    onChange={(e) => setValTo(e.target.value)}
                                    onKeyDown={(e) => { if (e.key === "Enter") handleOk(); }}
                                />
                            </>
                        )}
                    </div>
                    <div className="olc-hdr-menu-actions">
                        <button type="button" className="olc-btn" onClick={handleOk}>OK</button>
                        <button type="button" className="olc-btn" onClick={onClose}>Cancel</button>
                    </div>
                </>
            )}
        </div>
    );
};
