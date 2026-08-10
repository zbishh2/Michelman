// Slide-in change-history panel for one reason code. Reads GET
// /reason-dim/history?code=. Ported from the Revision Log Editor visual.

import * as React from "react";
import { useEffect } from "react";
import { ScrollPane } from "../grid/ScrollPane";
import { ReasonCodeHistoryEntry, ReasonCodeHistoryField } from "../api";
import { formatTimestamp } from "../util";

const HISTORY_FIELD_LABELS: Record<ReasonCodeHistoryField, string> = {
    description: "Description",
    longDescription: "Long Description",
    exemptionCriteria: "Exemption Criteria",
    otif: "OTIF Relevant",
    category: "Classification",
    review530: "Review at 530",
    review540: "Changes at 540+",
    typicalHit: "Typical Codes / OTIF Hits",
    oldClassification: "Old Classification",
    usageExamples: "Examples: When to Use",
    regionNote: "Region Note",
    active: "Active",
    sortOrder: "Sort Order",
};

// The boolean flags are stored as "0"/"1" strings in reason_dim_history — humanize.
const BOOL_HISTORY_FIELDS = new Set<ReasonCodeHistoryField>([
    "otif", "active", "review530", "review540", "typicalHit",
]);
function humanize(field: ReasonCodeHistoryField, value: string | null): string {
    if (value == null) return "—";
    if (BOOL_HISTORY_FIELDS.has(field)) {
        return value === "1" || value.toLowerCase() === "true" ? "Yes" : "No";
    }
    return value;
}

export interface HistoryPanelProps {
    code: string;
    loading: boolean;
    error: string | null;
    entries: ReasonCodeHistoryEntry[];
    onClose: () => void;
}

export const HistoryPanel: React.FC<HistoryPanelProps> = ({ code, loading, error, entries, onClose }) => {
    useEffect(() => {
        const onKey = (ev: KeyboardEvent) => { if (ev.key === "Escape") onClose(); };
        document.addEventListener("keydown", onKey);
        return () => document.removeEventListener("keydown", onKey);
    }, [onClose]);
    return (
        <div className="olc-modal-backdrop" onClick={(ev) => { if (ev.target === ev.currentTarget) onClose(); }}>
            <div className="olc-history-panel" role="dialog" aria-modal="true" aria-label="Change history">
                <div className="olc-history-header">
                    <div>
                        <div className="olc-history-title">Change history</div>
                        <div className="olc-history-subtitle">{code}</div>
                    </div>
                    <button type="button" className="olc-btn" onClick={onClose}>Close</button>
                </div>
                <div className="olc-history-body">
                    <ScrollPane>
                        {loading && <div className="olc-history-empty">Loading…</div>}
                        {!loading && error && <div className="olc-history-empty olc-history-error">{error}</div>}
                        {!loading && !error && entries.length === 0 && (
                            <div className="olc-history-empty">No changes recorded yet.</div>
                        )}
                        {!loading && !error && entries.length > 0 && (
                            <ul className="olc-history-list">
                                {entries.map((e) => (
                                    <li key={e.historyId} className="olc-history-item">
                                        <div className="olc-history-when">{formatTimestamp(e.changedAt)}</div>
                                        <div className="olc-history-who">{e.actorEmail || "(unknown)"}</div>
                                        <div className="olc-history-what">
                                            <span className="olc-history-field">{HISTORY_FIELD_LABELS[e.field] ?? e.field}</span>
                                            <span className="olc-history-old">{humanize(e.field, e.oldValue)}</span>
                                            <span className="olc-history-arrow">→</span>
                                            <span className="olc-history-new">{humanize(e.field, e.newValue)}</span>
                                        </div>
                                    </li>
                                ))}
                            </ul>
                        )}
                    </ScrollPane>
                </div>
            </div>
        </div>
    );
};
