// Right-click cell menu: copy value / row / row+headers / whole table, plus
// "View change history" for the row's revision event. Ported from DR.

import * as React from "react";
import { useEffect, useLayoutEffect, useRef, useState } from "react";

export interface CellContextMenuProps {
    x: number;
    y: number;
    onClose: () => void;
    onCopyValue: () => void;
    onCopyRow: () => void;
    onCopyRowWithHeaders: () => void;
    onCopyTable: () => void;
    canViewHistory: boolean;
    onViewHistory: () => void;
}

export const CellContextMenu: React.FC<CellContextMenuProps> = ({
    x, y, onClose, onCopyValue, onCopyRow, onCopyRowWithHeaders, onCopyTable, canViewHistory, onViewHistory,
}) => {
    const ref = useRef<HTMLDivElement | null>(null);
    const [pos, setPos] = useState<{ left: number; top: number }>({ left: x, top: y });
    useLayoutEffect(() => {
        const el = ref.current;
        if (!el) return;
        const r = el.getBoundingClientRect();
        const vw = window.innerWidth;
        const vh = window.innerHeight;
        const left = x + r.width > vw ? Math.max(0, vw - r.width - 4) : x;
        const top = y + r.height > vh ? Math.max(0, vh - r.height - 4) : y;
        setPos({ left, top });
    }, [x, y]);
    useEffect(() => {
        const onDocDown = (ev: MouseEvent) => {
            if (ref.current && !ref.current.contains(ev.target as Node)) onClose();
        };
        const onKey = (ev: KeyboardEvent) => { if (ev.key === "Escape") onClose(); };
        const onScroll = () => onClose();
        const onBlur = () => onClose();
        document.addEventListener("mousedown", onDocDown, true);
        document.addEventListener("contextmenu", onDocDown, true);
        document.addEventListener("keydown", onKey);
        window.addEventListener("scroll", onScroll, true);
        window.addEventListener("blur", onBlur);
        return () => {
            document.removeEventListener("mousedown", onDocDown, true);
            document.removeEventListener("contextmenu", onDocDown, true);
            document.removeEventListener("keydown", onKey);
            window.removeEventListener("scroll", onScroll, true);
            window.removeEventListener("blur", onBlur);
        };
    }, [onClose]);
    return (
        <div
            ref={ref}
            className="rle-ctx-menu"
            style={{ left: pos.left, top: pos.top }}
            onContextMenu={(e) => e.preventDefault()}
        >
            <button type="button" className="rle-ctx-item" onClick={onCopyValue}>Copy value</button>
            <button type="button" className="rle-ctx-item" onClick={onCopyRow}>Copy row</button>
            <button type="button" className="rle-ctx-item" onClick={onCopyRowWithHeaders}>Copy row with headers</button>
            <button type="button" className="rle-ctx-item" onClick={onCopyTable}>Copy table</button>
            <button type="button" className="rle-ctx-item" onClick={onViewHistory} disabled={!canViewHistory}>
                View change history
            </button>
        </div>
    );
};
