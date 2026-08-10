// Thin client for the Michelman Writeback Worker (reason-code dimension surface).
// Secret goes on every request via x-secret; identity via x-actor-email.
// Contract: writeback/worker/src/index.ts.

import { OTIF_HITS_CONFIG } from "./config";

export type Role = "admin" | "editor" | "restricted";

// One reason-code dimension row as returned by the worker (GET /reason-dim).
// `code` is the UDC 42/RR value; `otif` = whether a revision with this code
// counts as an OTIF miss (THE driver); `active` = dim-row validity (false =
// retired / "do not use", independent of otif).
export interface ReasonCode {
    code: string;
    description: string | null;
    longDescription: string | null;
    exemptionCriteria: string | null;
    otif: boolean;
    category: string | null;
    // Extra columns preserved from the SharePoint workbook (no data lost):
    // three X-mark milestone flags + three free-text columns.
    review530: boolean;
    review540: boolean;
    typicalHit: boolean;
    oldClassification: string | null;
    usageExamples: string | null;
    regionNote: string | null;
    active: boolean;
    sortOrder: number;
    updatedBy: string | null;
    updatedAt: string;
}

// Partial upsert payload for PUT /reason-dim. `code` is always sent (it is the
// PK, in the body not the path). Omitted fields are preserved by the worker.
export interface ReasonCodePatch {
    description?: string | null;
    longDescription?: string | null;
    exemptionCriteria?: string | null;
    otif?: boolean;
    category?: string | null;
    review530?: boolean;
    review540?: boolean;
    typicalHit?: boolean;
    oldClassification?: string | null;
    usageExamples?: string | null;
    regionNote?: string | null;
    active?: boolean;
    sortOrder?: number;
}

export type ReasonCodeHistoryField =
    | "description" | "longDescription" | "exemptionCriteria"
    | "otif" | "category" | "review530" | "review540" | "typicalHit"
    | "oldClassification" | "usageExamples" | "regionNote"
    | "active" | "sortOrder";

export interface ReasonCodeHistoryEntry {
    historyId: number;
    code: string;
    actorEmail: string | null;
    changedAt: string;
    field: ReasonCodeHistoryField;
    oldValue: string | null;
    newValue: string | null;
}

// A UDC 42/RR dropdown reason code (GET /reason-codes). Used as the datalist
// source when adding a new reason-code dimension row.
export interface DropdownReasonCode {
    codeId: number;
    code: string;
    label: string | null;
    sortOrder: number;
    active: boolean;
    updatedAt: string;
}

// One Classification choice (GET /reason-categories). The managed picklist behind the
// "Classification" dropdown — free text let "Operations (??)" in next to
// "Operations". `inUse` is how many reason codes carry it, which is why a live choice
// cannot simply be deleted.
export interface ReasonCategory {
    name: string;
    sortOrder: number;
    active: boolean;
    updatedBy: string | null;
    updatedAt: string;
    inUse: number;
}

// A person row (worker personPayload). Used for role gating + admin management.
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
export function getActorEmail(): string | null {
    return actorEmail;
}

async function req<T>(path: string, init?: RequestInit): Promise<T> {
    const headers: Record<string, string> = {
        ...(init?.headers as Record<string, string> | undefined || {}),
        "x-secret": OTIF_HITS_CONFIG.secret,
        "content-type": "application/json",
    };
    if (actorEmail) headers["x-actor-email"] = actorEmail;
    const r = await fetch(OTIF_HITS_CONFIG.baseUrl + path, { ...init, headers });
    if (!r.ok) {
        const text = await r.text().catch(() => "");
        throw new Error(`HTTP ${r.status}${text ? `: ${text}` : ""}`);
    }
    return r.json() as Promise<T>;
}

export const otifHitsApi = {
    // ─── Reason-code dimension ───
    // Ordered array: by sortOrder, then code (all ~48 codes).
    getAll: () => req<ReasonCode[]>("/reason-dim"),
    // Partial upsert of one code (inline edit / toggle / add). editor+ only.
    upsert: (code: string, patch: ReasonCodePatch) =>
        req<ReasonCode>("/reason-dim", {
            method: "PUT",
            body: JSON.stringify({ code, ...patch }),
        }),
    // Soft delete = retire the dim row (active=0; keeps descriptions + history). editor+ only.
    remove: (code: string) =>
        req<ReasonCode>("/reason-dim", {
            method: "DELETE",
            body: JSON.stringify({ code }),
        }),
    // Per-code change history, most-recent-first.
    getHistory: (code: string, limit = 100) =>
        req<ReasonCodeHistoryEntry[]>(
            `/reason-dim/history?code=${encodeURIComponent(code)}&limit=${limit}`
        ),

    // ─── Reason codes (UDC 42/RR dropdown list — datalist for new codes) ───
    getReasonCodes: () => req<DropdownReasonCode[]>("/reason-codes"),

    // ─── Classification picklist (the Classification column dropdown) ───
    getCategories: () => req<ReasonCategory[]>("/reason-categories"),
    // Add or update a choice. Pass renameFrom to rename: the worker cascades the new
    // name onto every reason code carrying the old one and logs each change. admin only.
    saveCategory: (body: { name: string; renameFrom?: string; sortOrder?: number; active?: boolean }) =>
        req<ReasonCategory>("/reason-categories", { method: "PUT", body: JSON.stringify(body) }),
    // Hard delete, refused with 409 while any reason code still carries it. admin only.
    removeCategory: (name: string) =>
        req<{ deleted: true; name: string }>("/reason-categories", {
            method: "DELETE",
            body: JSON.stringify({ name }),
        }),

    // ─── People (role lookup + admin management) ───
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

    // ─── Per-user table layout (column order), keyed by actor email + visual ───
    getLayout: () => req<{ columnOrder: string[] | null }>("/layout?visual=reasondim"),
    saveLayout: (columnOrder: string[]) =>
        req<{ columnOrder: string[] }>("/layout?visual=reasondim", {
            method: "PUT",
            body: JSON.stringify({ columnOrder }),
        }),
    deleteLayout: () =>
        req<{ deleted: true }>("/layout?visual=reasondim", { method: "DELETE" }),
};
