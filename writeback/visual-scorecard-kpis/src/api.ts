// Thin client for the Michelman Writeback Worker (manual-kpis surface).
// Secret on every request via x-secret; identity via x-actor-email. Contract:
// writeback/worker/src/index.ts.

import { KPI_CONFIG } from "./config";

export const TREND_OPTIONS = ["Improving", "Needs Improvement", "Steady"] as const;
export type TrendVerdict = (typeof TREND_OPTIONS)[number];

export interface ManualKpi {
    kpiKey: string;
    kpi: string;
    target: string | null;
    value: string | null;
    trend: TrendVerdict | null;
    sortOrder: number;
    active: boolean;
    updatedBy: string | null;
    updatedAt: string | null;
}

/** Editable fields, PUT as a partial upsert; the Worker preserves omitted keys. */
export interface ManualKpiPatch {
    kpi?: string;
    target?: string | null;
    value?: string | null;
    trend?: TrendVerdict | null;
}

let actorEmail: string | null = null;

export function setActorEmail(email: string | null): void {
    actorEmail = email && email.trim() ? email.trim().toLowerCase() : null;
}

async function req<T>(path: string, init?: RequestInit): Promise<T> {
    const headers: Record<string, string> = {
        ...((init?.headers as Record<string, string> | undefined) || {}),
        "x-secret": KPI_CONFIG.secret,
        "content-type": "application/json",
    };
    if (actorEmail) headers["x-actor-email"] = actorEmail;
    const r = await fetch(KPI_CONFIG.baseUrl + path, { ...init, headers });
    if (!r.ok) {
        const text = await r.text().catch(() => "");
        throw new Error(`HTTP ${r.status}${text ? `: ${text}` : ""}`);
    }
    return r.json() as Promise<T>;
}

export const kpiApi = {
    // A handful of rows; fetched whole. The Worker already filters to active = 1
    // and orders by sort_order.
    list: () => req<ManualKpi[]>("/manual-kpis"),

    // null clears a field (the Worker treats an ABSENT key as "leave it alone"),
    // so the editor always sends every editable field explicitly.
    save: (kpiKey: string, patch: ManualKpiPatch) =>
        req<ManualKpi>("/manual-kpis", {
            method: "PUT",
            body: JSON.stringify({ kpiKey, ...patch }),
        }),
};
