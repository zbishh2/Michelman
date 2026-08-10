// Company picker for the People panel — a checkbox dropdown, replacing the old
// comma-separated text input. Companies are the edit permission, so mistyping one
// silently granted or revoked access; a list you pick from cannot be mistyped.
//
// The popup is position:fixed and viewport-fitted (same approach as HeaderMenu):
// the People roster scrolls inside a ScrollPane, and an absolutely-positioned menu
// would be clipped by it.

import * as React from "react";
import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { normalizeCompany } from "../permissions";

interface CompanyMultiSelectProps {
    /** Currently granted companies, canonical 5-char codes. */
    value: string[];
    /** Companies offered as checkboxes — from the data (see App.tsx availableCompanies). */
    options: string[];
    disabled?: boolean;
    /** Shown instead of the selection when disabled — e.g. admins implicitly hold every company. */
    disabledLabel?: string;
    onChange: (next: string[]) => void;
}

const MARGIN = 8;
const MENU_WIDTH = 210;

function summarize(value: string[]): string {
    if (value.length === 0) return "No companies";
    if (value.length <= 2) return value.join(", ");
    return `${value.length} companies`;
}

export const CompanyMultiSelect: React.FC<CompanyMultiSelectProps> = ({ value, options, disabled, disabledLabel, onChange }) => {
    const [open, setOpen] = useState(false);
    const [pos, setPos] = useState<{ left: number; top: number } | null>(null);
    const [maxH, setMaxH] = useState<number | undefined>(undefined);
    const [addDraft, setAddDraft] = useState("");
    const btnRef = useRef<HTMLButtonElement | null>(null);
    const menuRef = useRef<HTMLDivElement | null>(null);

    // Anything already granted stays visible even if it is absent from the data
    // (a company whose rows are filtered out must not silently drop off the list).
    const items = useMemo(() => {
        const set = new Set<string>();
        options.forEach((o) => { const n = normalizeCompany(o); if (n) set.add(n); });
        value.forEach((v) => { const n = normalizeCompany(v); if (n) set.add(n); });
        return Array.from(set).sort();
    }, [options, value]);

    const selected = useMemo(() => new Set(value.map((v) => normalizeCompany(v)).filter((v): v is string => !!v)), [value]);

    const reposition = useCallback(() => {
        const btn = btnRef.current;
        const menu = menuRef.current;
        if (!btn || !menu) return;
        const rect = btn.getBoundingClientRect();
        const vw = window.innerWidth;
        const vh = window.innerHeight;
        const menuH = Math.min(menu.scrollHeight, vh - 2 * MARGIN);
        let left = rect.left;
        if (left + MENU_WIDTH > vw - MARGIN) left = vw - MENU_WIDTH - MARGIN;
        if (left < MARGIN) left = MARGIN;
        let top = rect.bottom + 2;
        if (top + menuH > vh - MARGIN) top = Math.max(MARGIN, rect.top - menuH - 2);
        setPos({ left: Math.round(left), top: Math.round(top) });
        setMaxH(Math.round(menuH));
    }, []);

    useLayoutEffect(() => { if (open) reposition(); }, [open, reposition, items.length]);

    useEffect(() => {
        if (!open) return;
        const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") setOpen(false); };
        const onDown = (e: MouseEvent) => {
            const t = e.target as Node;
            if (menuRef.current?.contains(t) || btnRef.current?.contains(t)) return;
            setOpen(false);
        };
        document.addEventListener("keydown", onKey);
        document.addEventListener("mousedown", onDown);
        window.addEventListener("resize", reposition);
        return () => {
            document.removeEventListener("keydown", onKey);
            document.removeEventListener("mousedown", onDown);
            window.removeEventListener("resize", reposition);
        };
    }, [open, reposition]);

    const toggle = (code: string) => {
        const next = new Set(selected);
        if (next.has(code)) next.delete(code); else next.add(code);
        onChange(Array.from(next).sort());
    };

    const addTyped = () => {
        const n = normalizeCompany(addDraft);
        if (!n) return;
        setAddDraft("");
        if (selected.has(n)) return;
        onChange(Array.from(new Set([...selected, n])).sort());
    };

    return (
        <>
            <button
                type="button"
                ref={btnRef}
                className={"olc-input olc-company-btn" + (value.length === 0 && !disabledLabel ? " empty" : "")}
                disabled={disabled}
                onClick={() => setOpen((o) => !o)}
                title={
                    disabled && disabledLabel ? disabledLabel
                        : value.length ? `May edit: ${value.join(", ")}`
                            : "No companies — this person is read-only. Click to grant."
                }
            >
                <span className="olc-company-btn-label">{disabled && disabledLabel ? disabledLabel : summarize(value)}</span>
                <span className="olc-company-caret">▾</span>
            </button>
            {open && (
                <div
                    ref={menuRef}
                    className="olc-company-menu"
                    style={{ left: pos?.left ?? -9999, top: pos?.top ?? -9999, maxHeight: maxH, visibility: pos ? "visible" : "hidden" }}
                >
                    <div className="olc-company-menu-head">
                        <span>Companies</span>
                        <div className="olc-company-menu-acts">
                            <button type="button" className="olc-linkbtn" onClick={() => onChange([...items])} disabled={items.length === 0}>All</button>
                            <button type="button" className="olc-linkbtn" onClick={() => onChange([])} disabled={value.length === 0}>None</button>
                        </div>
                    </div>
                    <div className="olc-company-menu-list">
                        {items.map((code) => (
                            <label key={code} className="olc-company-opt">
                                <span className={"olc-hdr-check" + (selected.has(code) ? " on" : "")}>{selected.has(code) ? "✓" : ""}</span>
                                <input
                                    type="checkbox"
                                    className="olc-company-cb"
                                    checked={selected.has(code)}
                                    onChange={() => toggle(code)}
                                />
                                <span className="olc-company-code">{code}</span>
                            </label>
                        ))}
                        {items.length === 0 && <div className="olc-company-none">No companies found in the data.</div>}
                    </div>
                    <div className="olc-company-menu-add">
                        <input
                            className="olc-input"
                            value={addDraft}
                            onChange={(e) => setAddDraft(e.target.value)}
                            onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); addTyped(); } }}
                            placeholder="Other code…"
                            title="Grant a company that has no rows in this visual. 10 / 0010 / 00010 all mean 00010."
                        />
                        <button type="button" className="olc-btn" onClick={addTyped} disabled={!addDraft.trim()}>Add</button>
                    </div>
                    <div className="olc-company-menu-foot">
                        {value.length === 0 ? "Read-only until a company is ticked." : `May edit ${value.join(", ")}`}
                    </div>
                </div>
            )}
        </>
    );
};
