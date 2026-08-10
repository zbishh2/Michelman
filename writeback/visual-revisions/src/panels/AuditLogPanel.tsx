// Global, read-only audit log: every override_history entry across all revision
// keys, newest first. Visible to all users for accountability. Server-side it
// pages the changed_at window (limit=500, since, before); client-side it filters
// by free text, field, and a "since" date. Panel chrome mirrors PeoplePanel.

import * as React from "react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ScrollPane } from "../grid/ScrollPane";
import { HistoryEntry, HistoryField, Person, revisionsApi } from "../api";
import { formatHistoryTimestamp, formatRelativeTime } from "../format";

const AUDIT_LIMIT = 500;

const FIELD_LABELS: Record<HistoryField, string> = {
    revisionReason: "Override Reason",
    note: "Note",
    excludeFlag: "Exclude",
};

// Keep the head/tail of a long revisionKey, drop the middle. Full value lives on
// the title tooltip.
function truncateMiddle(s: string, head = 12, tail = 10): string {
    if (s.length <= head + tail + 1) return s;
    return `${s.slice(0, head)}…${s.slice(-tail)}`;
}

// A yyyy-MM-dd date input marks local midnight of that day; send it as an ISO
// instant so the Worker's changed_at >= comparison lines up.
function sinceToIso(dateStr: string): string | undefined {
    if (!dateStr) return undefined;
    const d = new Date(`${dateStr}T00:00:00`);
    return Number.isNaN(d.getTime()) ? undefined : d.toISOString();
}

export interface AuditLogPanelProps {
    people: Person[];
    reasonDisplay: (code: string | null | undefined) => string;
    onClose: () => void;
}

export const AuditLogPanel: React.FC<AuditLogPanelProps> = ({ people, reasonDisplay, onClose }) => {
    const [entries, setEntries] = useState<HistoryEntry[]>([]);
    const [loading, setLoading] = useState(false);
    const [loadingOlder, setLoadingOlder] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [hasMore, setHasMore] = useState(false);

    const [search, setSearch] = useState("");
    const [fieldFilter, setFieldFilter] = useState<"all" | HistoryField>("all");
    const [since, setSince] = useState("");

    useEffect(() => {
        const onKey = (ev: KeyboardEvent) => { if (ev.key === "Escape") onClose(); };
        document.addEventListener("keydown", onKey);
        return () => document.removeEventListener("keydown", onKey);
    }, [onClose]);

    // email → display name (fall back to the raw email).
    const nameByEmail = useMemo(() => {
        const m = new Map<string, string>();
        for (const p of people) {
            if (p.email) m.set(p.email.toLowerCase(), p.displayName || p.personName);
        }
        return m;
    }, [people]);
    const whoName = useCallback((email: string | null): string => {
        if (!email) return "(unknown)";
        return nameByEmail.get(email.toLowerCase()) ?? email;
    }, [nameByEmail]);

    const renderValue = useCallback((field: HistoryField, value: string | null): string => {
        if (value == null) return "—";
        if (field === "excludeFlag") return value === "1" || value.toLowerCase() === "true" ? "Yes" : "No";
        if (field === "revisionReason") return reasonDisplay(value);
        return value;
    }, [reasonDisplay]);

    // Re-fetch the newest page whenever the "since" filter changes (and on mount).
    const sinceRef = useRef(since);
    sinceRef.current = since;
    const load = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const rows = await revisionsApi.getAuditLog({ limit: AUDIT_LIMIT, since: sinceToIso(sinceRef.current) });
            setEntries(rows);
            setHasMore(rows.length >= AUDIT_LIMIT);
        } catch (e) {
            setError(e instanceof Error ? e.message : "Failed to load audit log");
            setEntries([]);
            setHasMore(false);
        } finally {
            setLoading(false);
        }
    }, []);
    useEffect(() => { load(); }, [load, since]);

    const loadOlder = useCallback(async () => {
        if (!entries.length) return;
        setLoadingOlder(true);
        setError(null);
        try {
            const oldest = entries[entries.length - 1].changedAt;
            const older = await revisionsApi.getAuditLog({ limit: AUDIT_LIMIT, since: sinceToIso(sinceRef.current), before: oldest });
            setEntries((prev) => {
                const seen = new Set(prev.map((e) => e.historyId));
                return [...prev, ...older.filter((e) => !seen.has(e.historyId))];
            });
            setHasMore(older.length >= AUDIT_LIMIT);
        } catch (e) {
            setError(e instanceof Error ? e.message : "Failed to load older entries");
        } finally {
            setLoadingOlder(false);
        }
    }, [entries]);

    const filtered = useMemo(() => {
        const q = search.trim().toLowerCase();
        return entries.filter((e) => {
            if (fieldFilter !== "all" && e.field !== fieldFilter) return false;
            if (q) {
                const hay = [
                    e.actorEmail ?? "",
                    whoName(e.actorEmail),
                    e.revisionKey,
                    renderValue(e.field, e.oldValue),
                    renderValue(e.field, e.newValue),
                ].join(" ").toLowerCase();
                if (!hay.includes(q)) return false;
            }
            return true;
        });
    }, [entries, search, fieldFilter, whoName, renderValue]);

    return (
        <div className="rle-modal-backdrop" onClick={(ev) => { if (ev.target === ev.currentTarget) onClose(); }}>
            <div className="rle-people-panel" role="dialog" aria-modal="true" aria-label="Audit log">
                <div className="rle-people-head">
                    <div className="rle-people-title">Audit Log</div>
                    <div className="rle-audit-head-actions">
                        <button type="button" className="rle-btn" onClick={() => load()} disabled={loading} title="Reload the latest audit entries.">⟳ Refresh</button>
                        <button type="button" className="rle-icon-btn" onClick={onClose} title="Close">×</button>
                    </div>
                </div>
                <div className="rle-audit-filters">
                    <input
                        className="rle-people-input rle-audit-search"
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        placeholder="Search actor, key, or value…"
                    />
                    <select className="rle-people-select" value={fieldFilter} onChange={(e) => setFieldFilter(e.target.value as "all" | HistoryField)}>
                        <option value="all">All fields</option>
                        <option value="revisionReason">Override Reason</option>
                        <option value="note">Note</option>
                    </select>
                    <label className="rle-audit-since">
                        Since
                        <input type="date" className="rle-people-input" value={since} onChange={(e) => setSince(e.target.value)} />
                    </label>
                </div>
                {hasMore && (
                    <div className="rle-audit-notice">Showing most recent {AUDIT_LIMIT}. Use "Since" or "Load older" to see more.</div>
                )}
                {error && <div className="rle-error">{error}</div>}
                <div className="rle-audit-body">
                    <ScrollPane>
                        <table className="rle-audit-table">
                            <thead>
                                <tr>
                                    <th>When</th>
                                    <th>Who</th>
                                    <th>Revision Key</th>
                                    <th>Field</th>
                                    <th>Change</th>
                                </tr>
                            </thead>
                            <tbody>
                                {loading && (
                                    <tr><td className="rle-audit-empty" colSpan={5}>Loading…</td></tr>
                                )}
                                {!loading && filtered.length === 0 && (
                                    <tr><td className="rle-audit-empty" colSpan={5}>No audit entries{entries.length ? " match the filters" : " yet"}.</td></tr>
                                )}
                                {!loading && filtered.map((e) => (
                                    <tr key={e.historyId}>
                                        <td className="rle-audit-when" title={formatHistoryTimestamp(e.changedAt)}>{formatRelativeTime(e.changedAt)}</td>
                                        <td className="rle-audit-who" title={e.actorEmail ?? undefined}>{whoName(e.actorEmail)}</td>
                                        <td><span className="rle-audit-key" title={e.revisionKey}>{truncateMiddle(e.revisionKey)}</span></td>
                                        <td className="rle-audit-field">{FIELD_LABELS[e.field] ?? e.field}</td>
                                        <td className="rle-audit-change">
                                            <span className="rle-history-old">{renderValue(e.field, e.oldValue)}</span>
                                            <span className="rle-history-arrow">→</span>
                                            <span className="rle-history-new">{renderValue(e.field, e.newValue)}</span>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                        {hasMore && !loading && (
                            <div className="rle-audit-more">
                                <button type="button" className="rle-btn" onClick={loadOlder} disabled={loadingOlder}>
                                    {loadingOlder ? "Loading…" : "Load older"}
                                </button>
                            </div>
                        )}
                    </ScrollPane>
                </div>
            </div>
        </div>
    );
};
