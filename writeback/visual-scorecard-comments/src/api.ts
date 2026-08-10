// Thin client for the Michelman Writeback Worker (board-comments surface).
// Secret on every request via x-secret; identity via x-actor-email. Contract:
// writeback/worker/src/index.ts.
//
// FORK NOTE — this is visual-board's api.ts with the region vocabulary removed. The Executive
// Scorecard feed has no regional dimension (people/org KPIs aren't per-region), so nothing here
// ever sets a region. The `region` COLUMN still exists in D1 and is shared with the OTIF board;
// posts written from this visual just leave it NULL, which the Worker already treats as
// "all regions". One table keeps serving both visuals, no schema fork.

import { BOARD_CONFIG } from "./config";

export interface BoardComment {
    id: number;
    boardKey: string;
    body: string;
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
    // The whole thread is a few hundred rows at most, so it is fetched once and rendered whole.
    // No ?region= param — this visual reads its board unfiltered by design.
    list: (boardKey: string, limit = 200) =>
        req<BoardComment[]>(`/board-comments?board=${encodeURIComponent(boardKey)}&limit=${limit}`),

    add: (boardKey: string, body: string) =>
        req<BoardComment>("/board-comment", {
            method: "POST",
            body: JSON.stringify({ boardKey, body, region: null }),
        }),

    // region is sent as an explicit null, not omitted. The Worker's PATCH reads an ABSENT key as
    // "leave the tag alone" and an explicit null as "clear it" — so omitting it would silently
    // preserve a region tag on any row that happened to be written from the OTIF visual.
    edit: (id: number, body: string) =>
        req<BoardComment>(`/board-comment/${id}`, {
            method: "PATCH",
            body: JSON.stringify({ body, region: null }),
        }),

    remove: (id: number) =>
        req<{ id: number; deleted: true }>(`/board-comment/${id}`, { method: "DELETE" }),
};
