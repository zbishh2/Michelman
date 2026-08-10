// Custom overlay scrollbars. Native scrollbars trigger a Chromium
// iframe-transform blur inside this visual's Power BI sandbox, so we hide them
// and render our own thin thumbs. Ported verbatim from DeliveryReliability.

import * as React from "react";
import { useCallback, useEffect, useRef, useState } from "react";

export const ScrollPane: React.FC<{ children: React.ReactNode; onScroll?: (el: HTMLDivElement) => void }> = ({ children, onScroll }) => {
    const innerRef = useRef<HTMLDivElement | null>(null);
    const [hThumb, setHThumb] = useState({ left: 0, size: 0 });
    const [vThumb, setVThumb] = useState({ top: 0, size: 0 });
    const [showH, setShowH] = useState(false);
    const [showV, setShowV] = useState(false);
    const [dragH, setDragH] = useState(false);
    const [dragV, setDragV] = useState(false);
    const onScrollRef = useRef(onScroll);
    useEffect(() => { onScrollRef.current = onScroll; }, [onScroll]);

    const compute = useCallback(() => {
        const el = innerRef.current;
        if (!el) return;
        const sw = el.scrollWidth, cw = el.clientWidth, sh = el.scrollHeight, ch = el.clientHeight;
        if (sw > cw + 1 && cw > 0) {
            const size = Math.max(30, (cw / sw) * cw);
            const left = sw === cw ? 0 : (el.scrollLeft / (sw - cw)) * (cw - size);
            setHThumb({ left, size });
            setShowH(true);
        } else {
            setShowH(false);
        }
        if (sh > ch + 1 && ch > 0) {
            const size = Math.max(30, (ch / sh) * ch);
            const top = sh === ch ? 0 : (el.scrollTop / (sh - ch)) * (ch - size);
            setVThumb({ top, size });
            setShowV(true);
        } else {
            setShowV(false);
        }
        onScrollRef.current?.(el);
    }, []);

    useEffect(() => {
        const el = innerRef.current;
        if (!el) return;
        compute();
        const ro = new ResizeObserver(compute);
        ro.observe(el);
        const child = el.firstElementChild;
        if (child) ro.observe(child);
        const onScrollEv = () => compute();
        el.addEventListener("scroll", onScrollEv, { passive: true });
        return () => {
            ro.disconnect();
            el.removeEventListener("scroll", onScrollEv);
        };
    }, [compute]);

    const startHDrag = (e: React.MouseEvent) => {
        e.preventDefault();
        e.stopPropagation();
        const el = innerRef.current;
        if (!el) return;
        setDragH(true);
        const startX = e.clientX;
        const startScroll = el.scrollLeft;
        const sw = el.scrollWidth, cw = el.clientWidth;
        const trackUsable = cw - hThumb.size;
        const ratio = trackUsable > 0 ? (sw - cw) / trackUsable : 0;
        const move = (ev: MouseEvent) => { el.scrollLeft = startScroll + (ev.clientX - startX) * ratio; };
        const up = () => {
            setDragH(false);
            document.removeEventListener("mousemove", move);
            document.removeEventListener("mouseup", up);
        };
        document.addEventListener("mousemove", move);
        document.addEventListener("mouseup", up);
    };

    const startVDrag = (e: React.MouseEvent) => {
        e.preventDefault();
        e.stopPropagation();
        const el = innerRef.current;
        if (!el) return;
        setDragV(true);
        const startY = e.clientY;
        const startScroll = el.scrollTop;
        const sh = el.scrollHeight, ch = el.clientHeight;
        const trackUsable = ch - vThumb.size;
        const ratio = trackUsable > 0 ? (sh - ch) / trackUsable : 0;
        const move = (ev: MouseEvent) => { el.scrollTop = startScroll + (ev.clientY - startY) * ratio; };
        const up = () => {
            setDragV(false);
            document.removeEventListener("mousemove", move);
            document.removeEventListener("mouseup", up);
        };
        document.addEventListener("mousemove", move);
        document.addEventListener("mouseup", up);
    };

    const onHTrackClick = (e: React.MouseEvent<HTMLDivElement>) => {
        if (e.target !== e.currentTarget) return;
        const el = innerRef.current;
        if (!el) return;
        const rect = e.currentTarget.getBoundingClientRect();
        const x = e.clientX - rect.left - hThumb.size / 2;
        const trackUsable = el.clientWidth - hThumb.size;
        if (trackUsable <= 0) return;
        const frac = Math.max(0, Math.min(1, x / trackUsable));
        el.scrollLeft = frac * (el.scrollWidth - el.clientWidth);
    };

    const onVTrackClick = (e: React.MouseEvent<HTMLDivElement>) => {
        if (e.target !== e.currentTarget) return;
        const el = innerRef.current;
        if (!el) return;
        const rect = e.currentTarget.getBoundingClientRect();
        const y = e.clientY - rect.top - vThumb.size / 2;
        const trackUsable = el.clientHeight - vThumb.size;
        if (trackUsable <= 0) return;
        const frac = Math.max(0, Math.min(1, y / trackUsable));
        el.scrollTop = frac * (el.scrollHeight - el.clientHeight);
    };

    return (
        <div className="rle-scroll-pane">
            <div
                className={"rle-scroll-inner" + (showH ? " has-h" : "") + (showV ? " has-v" : "")}
                ref={innerRef}
            >{children}</div>
            {showH && (
                <div className="rle-htrack" onMouseDown={onHTrackClick}>
                    <div className={"rle-hthumb" + (dragH ? " dragging" : "")} style={{ left: hThumb.left, width: hThumb.size }} onMouseDown={startHDrag} />
                </div>
            )}
            {showV && (
                <div className="rle-vtrack" onMouseDown={onVTrackClick}>
                    <div className={"rle-vthumb" + (dragV ? " dragging" : "")} style={{ top: vThumb.top, height: vThumb.size }} onMouseDown={startVDrag} />
                </div>
            )}
        </div>
    );
};
