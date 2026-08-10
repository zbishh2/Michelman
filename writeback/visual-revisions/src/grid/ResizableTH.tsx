// A table header cell that supports: edge-drag resize (persisted width),
// drag-drop column reorder, a sort indicator, and a click-to-open header menu.
// Ported from DeliveryReliability.

import * as React from "react";
import { useEffect, useRef } from "react";

const MIN_WIDTH = 20;

export interface ResizableTHProps {
    label: string;
    width?: number;
    numeric?: boolean;
    onResize: (next: number) => void;
    onResizeEnd: (next: number) => void;
    dragKey?: string;
    onColumnDrop?: (fromKey: string, toKey: string) => void;
    sortDirection?: "asc" | "desc";
    onOpenMenu?: (anchor: DOMRect) => void;
    filterActive?: boolean;
    stickyLeft?: number;
    frozenBoundary?: boolean;
    onMeasured?: (width: number) => void;
}

export const ResizableTH: React.FC<ResizableTHProps> = ({ label, width, numeric, onResize, onResizeEnd, dragKey, onColumnDrop, sortDirection, onOpenMenu, filterActive, stickyLeft, frozenBoundary, onMeasured }) => {
    const thRef = useRef<HTMLTableCellElement | null>(null);
    const dragMovedRef = useRef(false);
    useEffect(() => {
        const el = thRef.current;
        if (!el || !onMeasured) return;
        const report = () => onMeasured(el.getBoundingClientRect().width);
        report();
        const ro = new ResizeObserver(report);
        ro.observe(el);
        return () => ro.disconnect();
    }, [onMeasured]);
    const onMouseDown = (e: React.MouseEvent<HTMLDivElement>) => {
        e.preventDefault();
        e.stopPropagation();
        const startX = e.clientX;
        const startW = width ?? thRef.current?.offsetWidth ?? MIN_WIDTH;
        let lastW = startW;
        const target = e.currentTarget;
        target.classList.add("active");
        const move = (ev: MouseEvent) => {
            lastW = Math.max(MIN_WIDTH, startW + (ev.clientX - startX));
            onResize(lastW);
        };
        const up = () => {
            target.classList.remove("active");
            document.removeEventListener("mousemove", move);
            document.removeEventListener("mouseup", up);
            onResizeEnd(lastW);
        };
        document.addEventListener("mousemove", move);
        document.addEventListener("mouseup", up);
    };
    const style: React.CSSProperties = {
        ...(width != null ? { width, minWidth: width, maxWidth: width } : {}),
        ...(stickyLeft != null ? { left: stickyLeft } : {}),
    };
    return (
        <th
            ref={thRef}
            className={[
                numeric ? "num" : "",
                dragKey ? "rle-draggable-th" : "",
                stickyLeft != null ? "rle-frozen-col" : "",
                frozenBoundary ? "rle-frozen-boundary" : "",
            ].filter(Boolean).join(" ")}
            style={style}
            draggable={!!dragKey}
            onDragStart={(e) => {
                if (!dragKey) return;
                dragMovedRef.current = false;
                e.dataTransfer.setData("text/plain", dragKey);
                e.dataTransfer.effectAllowed = "move";
            }}
            onDrag={(e) => {
                if (e.clientX !== 0 || e.clientY !== 0) dragMovedRef.current = true;
            }}
            onDragOver={(e) => {
                if (dragKey && onColumnDrop) {
                    e.preventDefault();
                    e.dataTransfer.dropEffect = "move";
                }
            }}
            onDrop={(e) => {
                if (!dragKey || !onColumnDrop) return;
                e.preventDefault();
                const fromKey = e.dataTransfer.getData("text/plain");
                if (fromKey && fromKey !== dragKey) onColumnDrop(fromKey, dragKey);
            }}
            onClick={(e) => {
                if (dragMovedRef.current) {
                    dragMovedRef.current = false;
                    return;
                }
                onOpenMenu?.((e.currentTarget as HTMLElement).getBoundingClientRect());
            }}
        >
            <span className="rle-th-inner">
                <span className="rle-th-label" title={label}>{label}</span>
                {sortDirection && <span className="rle-sort-indicator">{sortDirection === "asc" ? " ▲" : " ▼"}</span>}
                {filterActive && <span className="rle-th-filter-icon active" title="Filtered">⏷</span>}
                {!filterActive && <span className="rle-th-menu-caret">▾</span>}
            </span>
            <div className="rle-resizer" draggable={false} onMouseDown={onMouseDown} />
        </th>
    );
};
