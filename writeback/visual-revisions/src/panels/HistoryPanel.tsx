// Slide-in change-history panel for one revision event. Reads GET /history.
// Ported from DeliveryReliability.

import * as React from "react";
import { useEffect } from "react";
import { ScrollPane } from "../grid/ScrollPane";
import { HistoryEntry, HistoryField } from "../api";
import { formatHistoryTimestamp } from "../format";

const HISTORY_FIELD_LABELS: Record<HistoryField, string> = {
    revisionReason: "Override Reason",
    note: "Note",
    excludeFlag: "Excluded",
};

// exclude_flag is stored as "0"/"1" strings in override_history — humanize.
function humanize(field: HistoryField, value: string | null): string {
    if (value == null) return "—";
    if (field === "excludeFlag") return value === "1" || value.toLowerCase() === "true" ? "Yes" : "No";
    return value;
}

export interface HistoryPanelProps {
    revisionKey: string;
    loading: boolean;
    error: string | null;
    entries: HistoryEntry[];
    onClose: () => void;
}

export const HistoryPanel: React.FC<HistoryPanelProps> = ({ revisionKey, loading, error, entries, onClose }) => {
    useEffect(() => {
        const onKey = (ev: KeyboardEvent) => { if (ev.key === "Escape") onClose(); };
        document.addEventListener("keydown", onKey);
        return () => document.removeEventListener("keydown", onKey);
    }, [onClose]);
    return (
        <div className="rle-modal-backdrop" onClick={(ev) => { if (ev.target === ev.currentTarget) onClose(); }}>
            <div className="rle-history-panel" role="dialog" aria-modal="true" aria-label="Change history">
                <div className="rle-history-header">
                    <div>
                        <div className="rle-history-title">Change history</div>
                        <div className="rle-history-subtitle">{revisionKey}</div>
                    </div>
                    <button type="button" className="rle-btn" onClick={onClose}>Close</button>
                </div>
                <div className="rle-history-body">
                    <ScrollPane>
                        {loading && <div className="rle-history-empty">Loading…</div>}
                        {!loading && error && <div className="rle-history-empty rle-history-error">{error}</div>}
                        {!loading && !error && entries.length === 0 && (
                            <div className="rle-history-empty">No changes recorded yet.</div>
                        )}
                        {!loading && !error && entries.length > 0 && (
                            <ul className="rle-history-list">
                                {entries.map((e) => (
                                    <li key={e.historyId} className="rle-history-item">
                                        <div className="rle-history-when">{formatHistoryTimestamp(e.changedAt)}</div>
                                        <div className="rle-history-who">{e.actorEmail || "(unknown)"}</div>
                                        <div className="rle-history-what">
                                            <span className="rle-history-field">{HISTORY_FIELD_LABELS[e.field] ?? e.field}</span>
                                            <span className="rle-history-old">{humanize(e.field, e.oldValue)}</span>
                                            <span className="rle-history-arrow">→</span>
                                            <span className="rle-history-new">{humanize(e.field, e.newValue)}</span>
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
