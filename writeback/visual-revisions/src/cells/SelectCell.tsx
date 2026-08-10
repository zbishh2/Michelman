// Searchable dropdown cell. Options carry a stored `value` (what gets written —
// e.g. a UDC 42/RR reason code) and a `label` (what the user sees). Closes on
// outside click or window blur (report-canvas click in the sandbox). Ported and
// generalized from DeliveryReliability's SelectCell.

import * as React from "react";
import { useEffect, useRef, useState } from "react";

export interface SelectOption {
    value: string;
    label: string;
}

export interface SelectCellProps {
    value: string | null;
    options: SelectOption[];
    onCommit: (next: string | null) => void;
    disabled: boolean;
    searchable?: boolean;
    disabledTitle?: string;
}

export const SelectCell: React.FC<SelectCellProps> = ({ value, options, onCommit, disabled, searchable, disabledTitle }) => {
    const [open, setOpen] = useState(false);
    const [search, setSearch] = useState("");
    const rootRef = useRef<HTMLDivElement | null>(null);
    const searchRef = useRef<HTMLInputElement | null>(null);
    useEffect(() => {
        if (!open) return;
        const onDocDown = (ev: MouseEvent) => {
            if (rootRef.current && !rootRef.current.contains(ev.target as Node)) setOpen(false);
        };
        const onBlur = () => {
            window.setTimeout(() => {
                if (rootRef.current && rootRef.current.contains(document.activeElement)) return;
                setOpen(false);
            }, 0);
        };
        document.addEventListener("mousedown", onDocDown);
        window.addEventListener("blur", onBlur);
        return () => {
            document.removeEventListener("mousedown", onDocDown);
            window.removeEventListener("blur", onBlur);
        };
    }, [open]);
    useEffect(() => {
        if (open) {
            setSearch("");
            if (searchable) window.setTimeout(() => searchRef.current?.focus(), 0);
        }
    }, [open, searchable]);
    const choose = (next: string | null) => {
        setOpen(false);
        if ((next ?? "") !== (value ?? "")) onCommit(next);
    };
    const q = search.trim().toLowerCase();
    const filteredOptions = searchable && q
        ? options.filter((o) => o.label.toLowerCase().includes(q) || o.value.toLowerCase().includes(q))
        : options;
    // What to show for the current value: its option label, else the raw value.
    const current = options.find((o) => o.value === value);
    const displayText = current ? current.label : (value ?? "");
    return (
        <div className="rle-cell-select" ref={rootRef}>
            <button
                type="button"
                className="rle-cell-select-btn"
                disabled={disabled}
                title={disabled ? disabledTitle : undefined}
                onClick={() => setOpen((o) => !o)}
            >
                <span className="rle-cell-select-val">{displayText}</span>
                <span className="rle-cell-select-caret">▾</span>
            </button>
            {open && (
                <div className="rle-cell-select-menu" role="listbox">
                    {searchable && (
                        <input
                            ref={searchRef}
                            className="rle-cell-select-search"
                            value={search}
                            placeholder="Search…"
                            onChange={(e) => setSearch(e.target.value)}
                            onKeyDown={(e) => {
                                if (e.key === "Escape") { e.preventDefault(); setOpen(false); }
                                if (e.key === "Enter" && filteredOptions.length === 1) {
                                    e.preventDefault();
                                    choose(filteredOptions[0].value);
                                }
                            }}
                        />
                    )}
                    <ul className="rle-cell-select-list">
                        <li
                            className={"rle-cell-select-opt" + (value == null ? " selected" : "")}
                            onClick={() => choose(null)}
                        >
                            <span className="rle-cell-select-empty">(none)</span>
                        </li>
                        {filteredOptions.map((o) => (
                            <li
                                key={o.value}
                                className={"rle-cell-select-opt" + (o.value === value ? " selected" : "")}
                                onClick={() => choose(o.value)}
                            >
                                {o.label}
                            </li>
                        ))}
                        {filteredOptions.length === 0 && (
                            <li className="rle-cell-select-opt rle-cell-select-empty">No matches</li>
                        )}
                    </ul>
                </div>
            )}
        </div>
    );
};
