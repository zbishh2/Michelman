// Thin client for the Michelman writeback Worker (revisions surface). The
// shared secret is injected into every request via the x-secret header; the
// self-asserted actor email (USERPRINCIPALNAME) travels in x-actor-email so the
// Worker can resolve the viewer's role. See writeback/worker/src/index.ts.

import { WRITEBACK_CONFIG } from "./config";

export type Role = "admin" | "editor" | "restricted";

// One revision-override row as returned by the Worker (GET /revision-overrides).
export interface Override {
    revisionKey: string;
    orderLineId: string | null;
    changeDate: string | null;
    changeTime: string | null;
    revisionReason: string | null;
    note: string | null;
    excludeFlag: boolean;
    createdAt: string;
    updatedAt: string;
}

export type OverrideMap = Record<string, Override>;

// Partial upsert payload for PUT /revision-override. Omitted fields are
// preserved by the Worker. revisionKey is always sent (it is in the body, not
// the path, because it contains commas and pipes).
export interface OverridePatch {
    revisionReason?: string | null;
    note?: string | null;
    excludeFlag?: boolean;
    // Denormalized parts, derived from the revisionKey on first write so the
    // D1 row is readable/debuggable. Ignored on subsequent updates if unchanged.
    orderLineId?: string | null;
    changeDate?: string | null;
    changeTime?: string | null;
}

export type HistoryField = "revisionReason" | "note" | "excludeFlag";

export interface HistoryEntry {
    historyId: number;
    revisionKey: string;
    actorEmail: string | null;
    changedAt: string;
    field: HistoryField;
    oldValue: string | null;
    newValue: string | null;
}

export interface ReasonCode {
    codeId: number;
    code: string;
    label: string | null;
    sortOrder: number;
    active: boolean;
    updatedAt: string;
}

export interface ReasonCodePatch {
    code?: string;
    label?: string | null;
    sortOrder?: number;
    active?: boolean;
}

// Flat people model — no assignments/groups (that was DR-specific).
export interface Person {
    personKey: string;
    personName: string;
    displayName: string;
    email: string | null;
    role: Role | null;
    active: boolean;
    updatedAt: string;
    /** Order companies this person may edit, canonical 5-char ('00010'). Empty = read-only. */
    companies: string[];
}

export interface PersonPatch {
    personName?: string;
    displayName?: string | null;
    email?: string | null;
    role?: Role | null;
    active?: boolean;
    /** Whole-list replace. Accepts an array or the panel's comma-separated string. */
    companies?: string[] | string;
}

let actorEmail: string | null = null;
export function setActorEmail(email: string | null): void {
    actorEmail = email && email.trim() ? email.trim().toLowerCase() : null;
}

async function req<T>(path: string, init?: RequestInit): Promise<T> {
    const headers: Record<string, string> = {
        ...((init?.headers as Record<string, string> | undefined) || {}),
        "x-secret": WRITEBACK_CONFIG.secret,
        "content-type": "application/json",
    };
    if (actorEmail) headers["x-actor-email"] = actorEmail;
    const r = await fetch(WRITEBACK_CONFIG.baseUrl + path, { ...init, headers });
    if (!r.ok) {
        const text = await r.text().catch(() => "");
        throw new Error(`HTTP ${r.status}${text ? `: ${text}` : ""}`);
    }
    return r.json() as Promise<T>;
}

// The Worker keys layout by (actor email, visual). This visual is "revisions".
const LAYOUT_VISUAL = "revisions";

export const revisionsApi = {
    getAll: () => req<OverrideMap>("/revision-overrides"),

    upsert: (revisionKey: string, patch: OverridePatch) =>
        req<Override>("/revision-override", {
            method: "PUT",
            body: JSON.stringify({ revisionKey, ...patch }),
        }),

    remove: (revisionKey: string) =>
        req<{ revisionKey: string; deleted: true }>("/revision-override", {
            method: "DELETE",
            body: JSON.stringify({ revisionKey }),
        }),

    getHistory: (revisionKey: string, limit = 100) =>
        req<HistoryEntry[]>(
            `/history?revisionKey=${encodeURIComponent(revisionKey)}&limit=${limit}`
        ),

    // Global audit log (no revisionKey): most-recent-first override_history across
    // all keys. `since`/`before` page the changed_at window (ISO strings).
    getAuditLog: (opts: { limit?: number; since?: string; before?: string } = {}) => {
        const p = new URLSearchParams();
        p.set("limit", String(opts.limit ?? 500));
        if (opts.since) p.set("since", opts.since);
        if (opts.before) p.set("before", opts.before);
        return req<HistoryEntry[]>(`/history?${p.toString()}`);
    },

    getReasonCodes: () => req<ReasonCode[]>("/reason-codes"),
    saveReasonCode: (code: { code: string; label?: string | null; sortOrder?: number; active?: boolean }) =>
        req<ReasonCode>("/reason-codes", { method: "POST", body: JSON.stringify(code) }),
    updateReasonCode: (codeId: number, patch: ReasonCodePatch) =>
        req<ReasonCode>(`/reason-codes/${codeId}`, { method: "PUT", body: JSON.stringify(patch) }),
    deactivateReasonCode: (codeId: number) =>
        req<ReasonCode>(`/reason-codes/${codeId}`, { method: "DELETE" }),

    getPeople: () => req<Person[]>("/people"),
    savePerson: (person: { personName: string; displayName?: string | null; email?: string | null; role?: Role | null; active?: boolean; companies?: string[] | string }) =>
        req<Person>("/people", { method: "POST", body: JSON.stringify(person) }),
    updatePerson: (personKey: string, patch: PersonPatch) =>
        req<Person>(`/people/${encodeURIComponent(personKey)}`, { method: "PUT", body: JSON.stringify(patch) }),
    deactivatePerson: (personKey: string) =>
        req<Person>(`/people/${encodeURIComponent(personKey)}`, { method: "DELETE" }),
    // Hard delete — the row and its company grants are gone for good. 409 if it is your
    // own account (deleting it would revoke the rights you need to undo it).
    removePerson: (personKey: string) =>
        req<{ personKey: string; deleted: true }>(
            `/people/${encodeURIComponent(personKey)}?hard=1`,
            { method: "DELETE" }
        ),

    // Per-user table layout (column order), keyed by the actor email + visual.
    getLayout: () =>
        req<{ columnOrder: string[] | null }>(`/layout?visual=${LAYOUT_VISUAL}`),
    saveLayout: (columnOrder: string[]) =>
        req<{ columnOrder: string[] }>(`/layout?visual=${LAYOUT_VISUAL}`, {
            method: "PUT",
            body: JSON.stringify({ columnOrder }),
        }),
    deleteLayout: () =>
        req<{ deleted: true }>(`/layout?visual=${LAYOUT_VISUAL}`, { method: "DELETE" }),
};
