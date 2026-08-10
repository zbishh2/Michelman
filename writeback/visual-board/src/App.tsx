"use strict";

import * as React from "react";
import { boardApi, BoardComment, Region, REGIONS, getActorEmail } from "./api";
import { renderRich } from "./richtext";
import { RichTextEditor, RichTextEditorHandle } from "./RichTextEditor";

export interface AppProps {
    boardKey: string;
    title: string;
    showTitle: boolean;
    titleFontSize: number;
    titleColor: string;
    fontSize: number;
    placeholder: string;
    readOnly: boolean;
    /** Bumped by the host on every update() so a report refresh re-pulls the thread. */
    refreshToken: number;
    /** host.launchUrl — the sandboxed iframe cannot follow a plain <a href> on its own. */
    launchUrl?: (url: string) => void;
}

/** "2026-07-28T13:04:22Z" -> "28 Jul, 1:04 PM". Worker stores UTC; render local. */
function when(iso: string): string {
    const d = new Date(iso.endsWith("Z") || iso.includes("+") ? iso : iso.replace(" ", "T") + "Z");
    if (isNaN(d.getTime())) return iso;
    return d.toLocaleString(undefined, {
        day: "numeric", month: "short", hour: "numeric", minute: "2-digit",
    });
}

function authorOf(c: BoardComment): string {
    if (!c.actorEmail) return "Unknown";
    return c.actorEmail.split("@")[0].replace(/[._]/g, " ");
}

/** Filter chips: "All" plus one per region. `null` here means no narrowing, not an untagged post. */
type RegionFilter = Region | null;

const REGION_CLASS: Record<Region, string> = {
    Americas: "obc-rgn-americas",
    EMEA: "obc-rgn-emea",
    Asia: "obc-rgn-asia",
};

export const App: React.FC<AppProps> = (props) => {
    const { boardKey, readOnly, refreshToken } = props;
    const [items, setItems] = React.useState<BoardComment[]>([]);
    const [editingId, setEditingId] = React.useState<number | null>(null);
    const [status, setStatus] = React.useState<{ text: string; error?: boolean } | null>(null);
    const [busy, setBusy] = React.useState(false);

    // The editors are UNCONTROLLED — their text lives in the DOM, not in React state, because a
    // contenteditable re-rendered on every keystroke loses the caret. Markdown is pulled out of
    // them on submit. Only "is it empty" is mirrored here, purely to gate the Post button.
    const composer = React.useRef<RichTextEditorHandle>(null);
    const editor = React.useRef<RichTextEditorHandle>(null);
    const [draftEmpty, setDraftEmpty] = React.useState(true);

    // Which region a new post is about, and which region the reader is looking at. Separate on
    // purpose: reading EMEA does not commit you to posting EMEA, and the composer defaults to
    // the region you're reading only as a starting value.
    const [draftRegion, setDraftRegion] = React.useState<Region | null>(null);
    const [editRegion, setEditRegion] = React.useState<Region | null>(null);
    const [filter, setFilter] = React.useState<RegionFilter>(null);

    const load = React.useCallback(async () => {
        try {
            setItems(await boardApi.list(boardKey));
            setStatus(null);
        } catch (e) {
            setStatus({ text: (e as Error).message, error: true });
        }
    }, [boardKey]);

    React.useEffect(() => { void load(); }, [load, refreshToken]);

    // Optimistic write helpers — the thread is small, so a reload after each
    // mutation keeps ordering authoritative without a noticeable pause.
    const run = async (fn: () => Promise<unknown>, done: string) => {
        setBusy(true);
        try {
            await fn();
            await load();
            setStatus({ text: done });
        } catch (e) {
            setStatus({ text: (e as Error).message, error: true });
        } finally {
            setBusy(false);
        }
    };

    const post = () => {
        const body = (composer.current?.getMarkdown() ?? "").trim();
        if (!body) return;
        const region = draftRegion;
        void run(async () => {
            await boardApi.add(boardKey, body, region);
            composer.current?.clear();
            // A post tagged for a region you aren't reading would vanish on success and look
            // like a failed save; follow it instead.
            if (region && filter && region !== filter) setFilter(region);
        }, "Posted");
    };

    const saveEdit = (id: number) => {
        const body = (editor.current?.getMarkdown() ?? "").trim();
        if (!body) return;
        void run(async () => { await boardApi.edit(id, body, editRegion); setEditingId(null); }, "Saved");
    };

    const beginEdit = (c: BoardComment) => {
        // No draft state to seed — the editor parses c.body into its own DOM on mount.
        setEditingId(c.id);
        setEditRegion(c.region);
    };

    // Untagged ("All regions") posts survive every filter — they're addressed to everyone.
    const shown = React.useMemo(
        () => (filter === null ? items : items.filter((c) => c.region === filter || c.region === null)),
        [items, filter]
    );

    const countFor = React.useCallback(
        (r: RegionFilter) =>
            r === null ? items.length : items.filter((c) => c.region === r || c.region === null).length,
        [items]
    );

    const regionSelect = (
        value: Region | null,
        onChange: (r: Region | null) => void,
        title: string
    ) => (
        <select
            className="obc-region-select"
            value={value ?? ""}
            title={title}
            onChange={(e) => onChange((e.target.value || null) as Region | null)}
        >
            <option value="">All regions</option>
            {REGIONS.map((r) => <option key={r} value={r}>{r}</option>)}
        </select>
    );

    const remove = (id: number) => void run(() => boardApi.remove(id), "Deleted");

    const canWrite = !readOnly;
    const me = getActorEmail();

    // The panel is only ~150px tall on the Summary tab, so the chips ride the title line rather
    // than claiming a row of their own; they only get one when the title is switched off.
    const filters = (
        <span className="obc-filters">
            {([null, ...REGIONS] as RegionFilter[]).map((r) => (
                <button
                    key={r ?? "all"}
                    className={"obc-chip" + (filter === r ? " obc-chip-on" : "") + (r ? " " + REGION_CLASS[r] : "")}
                    onClick={() => setFilter(r)}
                    title={r ? `${r} posts, plus any addressed to all regions` : "Every post"}
                >
                    {r ?? "All"}<span className="obc-chip-n">{countFor(r)}</span>
                </button>
            ))}
        </span>
    );

    return (
        <div className="obc-root" style={{ fontSize: props.fontSize }}>
            {props.showTitle ? (
                <div className="obc-head">
                    <span className="obc-title" style={{ fontSize: props.titleFontSize, color: props.titleColor }}>
                        {props.title}
                    </span>
                    {filters}
                    {status && (
                        <span className={"obc-status" + (status.error ? " obc-err" : "")}>{status.text}</span>
                    )}
                </div>
            ) : (
                <div className="obc-head">
                    {filters}
                    {status && (
                        <span className={"obc-status" + (status.error ? " obc-err" : "")}>{status.text}</span>
                    )}
                </div>
            )}

            {canWrite && (
                <div className="obc-composer">
                    <RichTextEditor
                        ref={composer}
                        placeholder={props.placeholder}
                        onSubmit={post}
                        onEmptyChange={setDraftEmpty}
                    >
                        <span className="obc-composer-side">
                            {regionSelect(draftRegion, setDraftRegion, "Which region this comment is about")}
                            <button className="obc-btn obc-btn-primary" onClick={post} disabled={busy || draftEmpty}>
                                Post
                            </button>
                        </span>
                    </RichTextEditor>
                </div>
            )}

            <div className="obc-thread">
                {shown.length === 0 && (
                    <div className="obc-empty">
                        {items.length === 0
                            ? "No comments yet."
                            : `Nothing for ${filter} yet — ${items.length} comment${items.length === 1 ? "" : "s"} on other regions.`}
                    </div>
                )}
                {shown.map((c) => (
                    <div className="obc-item" key={c.id}>
                        <div className="obc-meta">
                            <span className={"obc-badge " + (c.region ? REGION_CLASS[c.region] : "obc-rgn-all")}>
                                {c.region ?? "All"}
                            </span>
                            <span className="obc-author">{authorOf(c)}</span>
                            <span>{when(c.createdAt)}</span>
                            {c.updatedAt && <span className="obc-edited">edited</span>}
                            {canWrite && editingId !== c.id && (
                                <span className="obc-actions">
                                    <button className="obc-link" onClick={() => beginEdit(c)}>
                                        Edit
                                    </button>
                                    <button className="obc-link obc-danger" onClick={() => remove(c.id)}>
                                        Delete
                                    </button>
                                </span>
                            )}
                            {me && c.actorEmail === me && <span aria-hidden="true" />}
                        </div>
                        {editingId === c.id ? (
                            <div className="obc-edit">
                                {/* key pins the editor to this comment: without it, editing a
                                    second post would reuse the mounted instance and keep the
                                    first post's text, since the surface only seeds on mount. */}
                                <RichTextEditor
                                    key={c.id}
                                    ref={editor}
                                    initialValue={c.body}
                                    autoFocus
                                    onSubmit={() => saveEdit(c.id)}
                                    onEscape={() => setEditingId(null)}
                                >
                                    {regionSelect(editRegion, setEditRegion, "Which region this comment is about")}
                                    <button className="obc-btn obc-btn-primary" onClick={() => saveEdit(c.id)} disabled={busy}>
                                        Save
                                    </button>
                                    <button className="obc-btn" onClick={() => setEditingId(null)}>Cancel</button>
                                </RichTextEditor>
                            </div>
                        ) : (
                            <div className="obc-body">{renderRich(c.body, { launchUrl: props.launchUrl })}</div>
                        )}
                    </div>
                ))}
            </div>
        </div>
    );
};
