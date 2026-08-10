// Read-only audit trail for line comments — every create / edit / delete, newest first.
// Admin-only (the Worker returns 403 otherwise), matching the Revision Log Editor's audit
// log. Written fresh rather than ported: comment_history is action-shaped (create/edit/
// delete with a before/after body), where override_history is field-shaped.

import * as React from "react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { ScrollPane } from "../grid/ScrollPane";
import { CommentHistoryEntry, Person, commentsApi } from "../api";

const AUDIT_LIMIT = 500;

const ACTION_LABELS: Record<string, string> = {
    create: "Added",
    edit: "Edited",
    delete: "Deleted",
};

/** D1 hands back "2026-07-28 15:49:09" — space separated, no zone. Treat as UTC. */
function fmtWhen(raw: string): string {
    const d = new Date(raw.endsWith("Z") || raw.includes("+") ? raw : raw.replace(" ", "T") + "Z");
    if (Number.isNaN(d.getTime())) return raw;
    return d.toLocaleString(undefined, {
        year: "numeric", month: "short", day: "numeric", hour: "numeric", minute: "2-digit",
    });
}

// A yyyy-MM-dd date input means local midnight; send an ISO instant so the Worker's
// changed_at >= comparison lines up.
function sinceToIso(dateStr: string): string | undefined {
    if (!dateStr) return undefined;
    const d = new Date(`${dateStr}T00:00:00`);
    return Number.isNaN(d.getTime()) ? undefined : d.toISOString();
}

export interface CommentAuditPanelProps {
    people: Person[];
    onClose: () => void;
}

export const CommentAuditPanel: React.FC<CommentAuditPanelProps> = ({ people, onClose }) => {
    const [entries, setEntries] = useState<CommentHistoryEntry[]>([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [search, setSearch] = useState("");
    const [actionFilter, setActionFilter] = useState<"all" | "create" | "edit" | "delete">("all");
    const [since, setSince] = useState("");

    useEffect(() => {
        const onKey = (ev: KeyboardEvent) => { if (ev.key === "Escape") onClose(); };
        document.addEventListener("keydown", onKey);
        return () => document.removeEventListener("keydown", onKey);
    }, [onClose]);

    const load = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            setEntries(await commentsApi.history({ since: sinceToIso(since), limit: AUDIT_LIMIT }));
        } catch (e) {
            setError(e instanceof Error ? e.message : "load failed");
        } finally {
            setLoading(false);
        }
    }, [since]);

    useEffect(() => { void load(); }, [load]);

    const nameByEmail = useMemo(() => {
        const m = new Map<string, string>();
        for (const p of people) {
            if (p.email) m.set(p.email.toLowerCase(), p.displayName || p.personName);
        }
        return m;
    }, [people]);

    const who = (email: string | null): string =>
        !email ? "(unknown)" : nameByEmail.get(email.toLowerCase()) ?? email;

    const shown = useMemo(() => {
        const q = search.trim().toLowerCase();
        // Inlined rather than calling who(): keeps this memo's dependencies exactly the values it
        // reads, so no lint suppression is needed.
        const nameFor = (email: string | null) =>
            !email ? "(unknown)" : nameByEmail.get(email.toLowerCase()) ?? email;
        return entries.filter((e) => {
            if (actionFilter !== "all" && e.action !== actionFilter) return false;
            if (!q) return true;
            return [e.orderLineId, e.actorEmail ?? "", nameFor(e.actorEmail), e.oldValue ?? "", e.newValue ?? ""]
                .some((v) => v.toLowerCase().includes(q));
        });
    }, [entries, search, actionFilter, nameByEmail]);

    return (
        <div className="olc-modal-backdrop" onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}>
            <div className="olc-people-panel">
                <div className="olc-people-head">
                    <div className="olc-people-title">Comment audit log</div>
                    <button type="button" className="olc-icon-btn" onClick={onClose} title="Close">×</button>
                </div>

                <div className="olc-people-add">
                    <input
                        className="olc-input"
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        placeholder="Search line, person or text…"
                    />
                    <select
                        className="olc-input"
                        value={actionFilter}
                        onChange={(e) => setActionFilter(e.target.value as typeof actionFilter)}
                    >
                        <option value="all">All actions</option>
                        <option value="create">Added</option>
                        <option value="edit">Edited</option>
                        <option value="delete">Deleted</option>
                    </select>
                    <input
                        className="olc-input"
                        type="date"
                        value={since}
                        onChange={(e) => setSince(e.target.value)}
                        title="Only show changes on or after this date"
                    />
                    <button type="button" className="olc-btn" onClick={() => void load()} disabled={loading}>
                        {loading ? "Loading…" : "⟳ Refresh"}
                    </button>
                </div>

                {error && <div className="olc-error">{error}</div>}

                <div className="olc-people-body">
                    <ScrollPane>
                        <div className="olc-people-list">
                            {shown.map((e) => (
                                <div className="olc-person-row" key={e.historyId}>
                                    <div className="olc-person-name">
                                        <div className="olc-person-view">
                                            <span className="olc-person-display">
                                                {ACTION_LABELS[e.action] ?? e.action} · {e.orderLineId}
                                            </span>
                                            <span className="olc-person-sub">{fmtWhen(e.changedAt)}</span>
                                        </div>
                                        <div className="olc-person-sub">
                                            {who(e.actorEmail)}
                                            {e.action === "edit" && (
                                                <> · <s>{e.oldValue ?? ""}</s> → {e.newValue ?? ""}</>
                                            )}
                                            {e.action === "create" && <> · {e.newValue ?? ""}</>}
                                            {e.action === "delete" && <> · <s>{e.oldValue ?? ""}</s></>}
                                        </div>
                                    </div>
                                </div>
                            ))}
                            {!loading && shown.length === 0 && (
                                <div className="olc-thread-empty">
                                    {entries.length === 0 ? "No comment changes recorded yet." : "Nothing matches those filters."}
                                </div>
                            )}
                            {entries.length >= AUDIT_LIMIT && (
                                <div className="olc-thread-empty">
                                    Showing the most recent {AUDIT_LIMIT}. Narrow with the date filter to see older entries.
                                </div>
                            )}
                        </div>
                    </ScrollPane>
                </div>
            </div>
        </div>
    );
};
