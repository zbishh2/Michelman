// Thin client for the Michelman Writeback Worker (board-comments surface).
// Secret on every request via x-secret; identity via x-actor-email, same as the
// Order Line Comments visual. Contract: writeback/worker/src/index.ts.

import { BOARD_CONFIG } from "./config";

/**
 * The board's region vocabulary, matching 'Dim Region' in the semantic model
 * (00010 -> Americas, 00020 -> EMEA, 00030/34/35 -> Asia).
 * null on a comment means "all regions" — it stays visible under every filter.
 */
export const REGIONS = ["Americas", "EMEA", "Asia"] as const;
export type Region = (typeof REGIONS)[number];

export interface BoardComment {
    id: number;
    boardKey: string;
    body: string;
    region: Region | null;
    actorEmail: string | null;
    createdAt: string;
    updatedAt: string | null;
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
        ...((init?.headers as Record<string, string> | undefined) || {}),
        "x-secret": BOARD_CONFIG.secret,
        "content-type": "application/json",
    };
    if (actorEmail) headers["x-actor-email"] = actorEmail;
    const r = await fetch(BOARD_CONFIG.baseUrl + path, { ...init, headers });
    if (!r.ok) {
        const text = await r.text().catch(() => "");
        throw new Error(`HTTP ${r.status}${text ? `: ${text}` : ""}`);
    }
    return r.json() as Promise<T>;
}

export const boardApi = {
    // The whole thread is a few hundred rows at most, so it is fetched once and filtered in the
    // browser. That keeps region switching instant and avoids a round trip per click; the
    // Worker's ?region= filter stays available for anything that needs a narrowed read.
    list: (boardKey: string, limit = 200) =>
        req<BoardComment[]>(`/board-comments?board=${encodeURIComponent(boardKey)}&limit=${limit}`),

    add: (boardKey: string, body: string, region: Region | null) =>
        req<BoardComment>("/board-comment", {
            method: "POST",
            body: JSON.stringify({ boardKey, body, region }),
        }),

    edit: (id: number, body: string, region: Region | null) =>
        req<BoardComment>(`/board-comment/${id}`, {
            method: "PATCH",
            body: JSON.stringify({ body, region }),
        }),

    remove: (id: number) =>
        req<{ id: number; deleted: true }>(`/board-comment/${id}`, { method: "DELETE" }),
};
