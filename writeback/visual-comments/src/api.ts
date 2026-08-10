// Thin client for the Michelman Writeback Worker (comments visual surface).
// Secret goes on every request via x-secret; identity via x-actor-email.
// Contract: writeback/worker/src/index.ts.

import { COMMENTS_CONFIG } from "./config";

export type Role = "admin" | "editor" | "restricted";

// One comment in a thread (worker commentPayload).
export interface Comment {
    id: number;
    orderLineId: string;
    body: string;
    actorEmail: string | null;
    createdAt: string;
    updatedAt: string | null;
}

// Latest non-deleted comment per line (worker /comments/latest value shape).
export interface Latest {
    id: number;
    body: string;
    actorEmail: string | null;
    createdAt: string;
    updatedAt: string | null;
}

export type LatestMap = Record<string, Latest>;

/** One create / edit / delete of a line comment (worker commentHistoryPayload). */
export interface CommentHistoryEntry {
    historyId: number;
    orderLineId: string;
    commentId: number | null;
    actorEmail: string | null;
    changedAt: string;
    action: "create" | "edit" | "delete" | string;
    oldValue: string | null;
    newValue: string | null;
}

// A person row (worker personPayload). Used for role gating + author names.
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
        "x-secret": COMMENTS_CONFIG.secret,
        "content-type": "application/json",
    };
    if (actorEmail) headers["x-actor-email"] = actorEmail;
    const r = await fetch(COMMENTS_CONFIG.baseUrl + path, { ...init, headers });
    if (!r.ok) {
        const text = await r.text().catch(() => "");
        throw new Error(`HTTP ${r.status}${text ? `: ${text}` : ""}`);
    }
    return r.json() as Promise<T>;
}

export const commentsApi = {
    // ─── Comments ───
    latest: () => req<LatestMap>("/comments/latest"),
    // Upsert the single comment for a line (inline edit). Empty body deletes it.
    saveLineComment: (orderLineId: string, body: string) =>
        req<Comment | { orderLineId: string; deleted: true }>("/line-comment", {
            method: "PUT",
            body: JSON.stringify({ orderLineId, body }),
        }),
    // Exact non-deleted comment count per line, e.g. { "<orderLineId>": 3 }.
    counts: () => req<Record<string, number>>("/comments/counts"),
    thread: (orderLineId: string) =>
        req<Comment[]>(`/comments/thread?orderLineId=${encodeURIComponent(orderLineId)}`),
    add: (orderLineId: string, body: string) =>
        req<Comment>("/comment", {
            method: "POST",
            body: JSON.stringify({ orderLineId, body }),
        }),
    update: (id: number, body: string) =>
        req<Comment>(`/comment/${id}`, {
            method: "PATCH",
            body: JSON.stringify({ body }),
        }),
    remove: (id: number) =>
        req<{ id: number; deleted: true }>(`/comment/${id}`, { method: "DELETE" }),

    // ─── Comment audit trail (admin only; 403 otherwise) ───
    history: (opts?: { orderLineId?: string; since?: string; limit?: number }) => {
        const q = new URLSearchParams();
        if (opts?.orderLineId) q.set("orderLineId", opts.orderLineId);
        if (opts?.since) q.set("since", opts.since);
        q.set("limit", String(opts?.limit ?? 500));
        return req<CommentHistoryEntry[]>(`/comment-history?${q.toString()}`);
    },

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
    getLayout: () => req<{ columnOrder: string[] | null }>("/layout?visual=comments"),
    saveLayout: (columnOrder: string[]) =>
        req<{ columnOrder: string[] }>("/layout?visual=comments", {
            method: "PUT",
            body: JSON.stringify({ columnOrder }),
        }),
    deleteLayout: () =>
        req<{ deleted: true }>("/layout?visual=comments", { method: "DELETE" }),
};
