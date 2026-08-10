"use strict";

import * as React from "react";
import { kpiApi, ManualKpi, ManualKpiPatch, TREND_OPTIONS, TrendVerdict } from "./api";

export interface AppProps {
    /** Points, converted to px here — the native tables speak pt (textSize 10). */
    fontSizePt: number;
    trendHeader: string;
    readOnly: boolean;
    /** Bumped by the host on every update() so a report refresh re-pulls the rows. */
    refreshToken: number;
}

interface Draft {
    kpi: string;
    target: string;
    value: string;
    trend: string; // "" = no verdict
}

const POLL_MS = 60_000;

export const App: React.FC<AppProps> = (props) => {
    const [items, setItems] = React.useState<ManualKpi[]>([]);
    const [status, setStatus] = React.useState<{ text: string; error?: boolean } | null>(null);
    const [busy, setBusy] = React.useState(false);
    const [editingKey, setEditingKey] = React.useState<string | null>(null);
    const [draft, setDraft] = React.useState<Draft>({ kpi: "", target: "", value: "", trend: "" });

    // JSON-equality bailout so the poll never re-renders (and never disturbs an
    // in-progress edit) unless something actually changed server-side.
    const load = React.useCallback(async () => {
        try {
            const next = await kpiApi.list();
            setItems((prev) => (JSON.stringify(prev) === JSON.stringify(next) ? prev : next));
            setStatus((s) => (s?.error ? null : s));
        } catch (e) {
            setStatus({ text: `Couldn't load KPIs — ${(e as Error).message}`, error: true });
        }
    }, []);

    React.useEffect(() => { void load(); }, [load, props.refreshToken]);
    React.useEffect(() => {
        const t = setInterval(() => { void load(); }, POLL_MS);
        return () => clearInterval(t);
    }, [load]);

    const openEdit = (k: ManualKpi) => {
        setDraft({ kpi: k.kpi, target: k.target ?? "", value: k.value ?? "", trend: k.trend ?? "" });
        setEditingKey(k.kpiKey);
        setStatus(null);
    };
    const cancel = () => setEditingKey(null);

    const save = (kpiKey: string) => {
        // Every editable field goes out explicitly: the Worker treats an absent key
        // as "leave it alone", and a cleared input must actually clear the field.
        const patch: ManualKpiPatch = {
            kpi: draft.kpi.trim() || undefined,
            target: draft.target.trim() || null,
            value: draft.value.trim() || null,
            trend: (draft.trend || null) as TrendVerdict | null,
        };
        setBusy(true);
        void (async () => {
            try {
                await kpiApi.save(kpiKey, patch);
                setEditingKey(null);
                await load();
                setStatus(null);
            } catch (e) {
                // The Worker's 403 ("editor or admin required") lands here verbatim —
                // that message is the permission model surfacing, not a bug.
                setStatus({ text: (e as Error).message, error: true });
            } finally {
                setBusy(false);
            }
        })();
    };

    const onKeyDown = (e: React.KeyboardEvent, kpiKey: string) => {
        if (e.key === "Enter") save(kpiKey);
        if (e.key === "Escape") cancel();
    };

    const px = `${Math.round(props.fontSizePt * (4 / 3))}px`;

    return (
        <div className="sck-root" style={{ fontSize: px }}>
            <div className="sck-scroll">
                <table className="sck-table">
                    <colgroup>
                        <col style={{ width: "37%" }} />
                        <col style={{ width: "15%" }} />
                        <col style={{ width: "22%" }} />
                        <col style={{ width: "26%" }} />
                    </colgroup>
                    <thead>
                        <tr>
                            <th>KPI</th>
                            <th>Target</th>
                            <th>YTD Global</th>
                            <th>{props.trendHeader}</th>
                        </tr>
                    </thead>
                    <tbody>
                        {items.length === 0 && !status && (
                            <tr><td className="sck-empty" colSpan={4}>No KPIs configured.</td></tr>
                        )}
                        {items.map((k, i) => {
                            const banded = i % 2 === 1;
                            const rowCls = banded ? "sck-row-banded" : undefined;
                            if (editingKey === k.kpiKey) {
                                return (
                                    <tr className={rowCls} key={k.kpiKey}>
                                        <td className="sck-col-kpi">
                                            <input
                                                className="sck-input"
                                                value={draft.kpi}
                                                onChange={(e) => setDraft({ ...draft, kpi: e.target.value })}
                                                onKeyDown={(e) => onKeyDown(e, k.kpiKey)}
                                                aria-label="KPI"
                                            />
                                        </td>
                                        <td className="sck-col-mid">
                                            <input
                                                className="sck-input"
                                                value={draft.target}
                                                onChange={(e) => setDraft({ ...draft, target: e.target.value })}
                                                onKeyDown={(e) => onKeyDown(e, k.kpiKey)}
                                                aria-label="Target"
                                            />
                                        </td>
                                        <td className="sck-col-mid">
                                            <input
                                                className="sck-input"
                                                value={draft.value}
                                                onChange={(e) => setDraft({ ...draft, value: e.target.value })}
                                                onKeyDown={(e) => onKeyDown(e, k.kpiKey)}
                                                aria-label="YTD Global"
                                                autoFocus
                                            />
                                        </td>
                                        <td className="sck-col-mid">
                                            <select
                                                className="sck-select"
                                                value={draft.trend}
                                                onChange={(e) => setDraft({ ...draft, trend: e.target.value })}
                                                aria-label="Trend"
                                            >
                                                <option value="">—</option>
                                                {TREND_OPTIONS.map((t) => (
                                                    <option key={t} value={t}>{t}</option>
                                                ))}
                                            </select>
                                            <span className="sck-actions">
                                                <button
                                                    className="sck-btn sck-btn-primary"
                                                    onClick={() => save(k.kpiKey)}
                                                    disabled={busy}
                                                >
                                                    Save
                                                </button>
                                                <button className="sck-btn" onClick={cancel} disabled={busy}>
                                                    Cancel
                                                </button>
                                            </span>
                                        </td>
                                    </tr>
                                );
                            }
                            return (
                                <tr className={rowCls} key={k.kpiKey}>
                                    <td className="sck-col-kpi">{k.kpi}</td>
                                    <td className="sck-col-mid">{k.target ?? ""}</td>
                                    <td className="sck-col-mid">{k.value ?? ""}</td>
                                    <td className="sck-col-mid sck-cell-trend">
                                        {k.trend ?? ""}
                                        {!props.readOnly && (
                                            <button
                                                className="sck-edit-btn"
                                                onClick={() => openEdit(k)}
                                                title="Edit this KPI"
                                                aria-label={`Edit ${k.kpi}`}
                                            >
                                                ✎
                                            </button>
                                        )}
                                    </td>
                                </tr>
                            );
                        })}
                    </tbody>
                </table>
            </div>
            {status && (
                <div className={"sck-status" + (status.error ? " sck-err" : "")}>{status.text}</div>
            )}
        </div>
    );
};
