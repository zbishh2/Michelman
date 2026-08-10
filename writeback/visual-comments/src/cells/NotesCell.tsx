// Auto-sizing textarea cell (grows to fit content). Commits on blur when the
// trimmed value changed. While focused, incoming prop updates (e.g. the 60s
// poll) are ignored so they can't clobber the in-progress draft. Ported from the
// Revision Log Editor visual.

import * as React from "react";
import { useEffect, useLayoutEffect, useRef, useState } from "react";

export interface NotesCellProps {
    value: string | null;
    onCommit: (next: string | null) => void;
    disabled: boolean;
    disabledTitle?: string;
}

export const NotesCell: React.FC<NotesCellProps> = ({ value, onCommit, disabled, disabledTitle }) => {
    const [local, setLocal] = useState(value ?? "");
    const focusedRef = useRef(false);
    const taRef = useRef<HTMLTextAreaElement | null>(null);
    useEffect(() => {
        if (!focusedRef.current) setLocal(value ?? "");
    }, [value]);
    useLayoutEffect(() => {
        const el = taRef.current;
        if (!el) return;
        el.style.height = "0px";
        el.style.height = el.scrollHeight + "px";
    }, [local]);
    return (
        <textarea
            ref={taRef}
            className="olc-cell-notes"
            disabled={disabled}
            title={disabled ? disabledTitle : undefined}
            value={local}
            rows={1}
            onFocus={() => { focusedRef.current = true; }}
            onChange={(e) => setLocal(e.target.value)}
            onBlur={() => {
                focusedRef.current = false;
                const next = local.trim() === "" ? null : local;
                if ((next ?? "") !== (value ?? "")) onCommit(next);
            }}
        />
    );
};
