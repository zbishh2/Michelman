"use strict";

import * as React from "react";
import { boardApi, BoardComment } from "./api";
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
    /** Caption on the button that opens the composer dialog. */
    addLabel: string;
    readOnly: boolean;
    /** Bumped by the host on every update() so a report refresh re-pulls the thread. */
    refreshToken: number;
    /** host.launchUrl — the sandboxed iframe cannot follow a plain <a href> on its own. */
    launchUrl?: (url: string) => void;
}

/**
 * What the dialog is currently for. `null` = closed. Add and edit share one surface because they
 * are the same operation with a different verb; keeping two near-identical editors mounted was
 * what made the OTIF version's caret bugs so fiddly.
 */
type DialogMode = { kind: "add" } | { kind: "edit"; comment: BoardComment } | null;

export const App: React.FC<AppProps> = (props) => {
    const { boardKey, readOnly, refreshToken } = props;
    const [items, setItems] = React.useState<BoardComment[]>([]);
    const [status, setStatus] = React.useState<{ text: string; error?: boolean } | null>(null);
    const [busy, setBusy] = React.useState(false);
    const [dialog, setDialog] = React.useState<DialogMode>(null);

    // The editor is UNCONTROLLED — its text lives in the DOM, not in React state, because a
    // contenteditable re-rendered on every keystroke loses the caret. Markdown is pulled out of
    // it on submit. Only "is it empty" is mirrored here, purely to gate the save button.
    const editorRef = React.useRef<RichTextEditorHandle>(null);
    const [draftEmpty, setDraftEmpty] = React.useState(true);

    const load = React.useCallback(async () => {
        try {
            setItems(await boardApi.list(boardKey));
            setStatus(null);
        } catch (e) {
            setStatus({ text: (e as Error).message, error: true });
        }
    }, [boardKey]);

    React.useEffect(() => { void load(); }, [load, refreshToken]);

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

    const openAdd = () => { setDraftEmpty(true); setDialog({ kind: "add" }); };
    const openEdit = (c: BoardComment) => { setDraftEmpty(false); setDialog({ kind: "edit", comment: c }); };
    const closeDialog = () => setDialog(null);

    const submit = () => {
        const body = (editorRef.current?.getMarkdown() ?? "").trim();
        if (!body || !dialog) return;
        const mode = dialog;
        void run(async () => {
            if (mode.kind === "add") await boardApi.add(boardKey, body);
            else await boardApi.edit(mode.comment.id, body);
            setDialog(null);
        }, mode.kind === "add" ? "Posted" : "Saved");
    };

    // Deletes are immediate and irreversible from the reader's point of view, so they ask first.
    // window.confirm is unreliable inside the visual sandbox (see writeback/HANDOFF.md), so the
    // confirmation is an inline two-step on the row itself.
    const [confirmingId, setConfirmingId] = React.useState<number | null>(null);
    const remove = (id: number) => {
        setConfirmingId(null);
        void run(() => boardApi.remove(id), "Deleted");
    };

    const canWrite = !readOnly;

    return (
        <div className="scb-root" style={{ fontSize: props.fontSize }}>
            <div className="scb-head">
                {props.showTitle && (
                    <span className="scb-title" style={{ fontSize: props.titleFontSize, color: props.titleColor }}>
                        {props.title}
                    </span>
                )}
                {status && (
                    <span className={"scb-status" + (status.error ? " scb-err" : "")}>{status.text}</span>
                )}
                {canWrite && (
                    <button className="scb-btn scb-btn-primary scb-add" onClick={openAdd} disabled={busy}>
                        {props.addLabel}
                    </button>
                )}
            </div>

            <div className="scb-thread">
                {items.length === 0 && <div className="scb-empty">No comments yet.</div>}
                {items.map((c) => (
                    <div className="scb-item" key={c.id}>
                        <div className="scb-body">{renderRich(c.body, { launchUrl: props.launchUrl })}</div>
                        {/* No timestamp and no author. This feed records what the business
                            committed to, not when someone typed it — createdAt still drives the
                            newest-first ORDER BY server-side, it is simply never shown. The row
                            survives as the hover target for Edit / Delete. */}
                        <div className="scb-meta">
                            {canWrite && (
                                <span className="scb-actions">
                                    {confirmingId === c.id ? (
                                        <>
                                            <span className="scb-confirm-q">Delete?</span>
                                            <button className="scb-link scb-danger" onClick={() => remove(c.id)}>
                                                Yes
                                            </button>
                                            <button className="scb-link" onClick={() => setConfirmingId(null)}>
                                                No
                                            </button>
                                        </>
                                    ) : (
                                        <>
                                            <button className="scb-link" onClick={() => openEdit(c)}>Edit</button>
                                            <button
                                                className="scb-link scb-danger"
                                                onClick={() => setConfirmingId(c.id)}
                                            >
                                                Delete
                                            </button>
                                        </>
                                    )}
                                </span>
                            )}
                        </div>
                    </div>
                ))}
            </div>

            {dialog && (
                // Not a <dialog> element: Power BI's sandboxed iframe gives showModal() no top
                // layer to render into, so it lands behind the visual. A plain overlay inside the
                // visual's own box is what the other writeback visuals use for the same reason.
                <div className="scb-overlay" onMouseDown={closeDialog}>
                    <div
                        className="scb-dialog"
                        role="dialog"
                        aria-modal="true"
                        aria-label={dialog.kind === "add" ? "Add comment" : "Edit comment"}
                        onMouseDown={(e) => e.stopPropagation()}
                    >
                        <div className="scb-dialog-head">
                            {dialog.kind === "add" ? "Add comment" : "Edit comment"}
                        </div>
                        <div className="scb-dialog-body">
                            {/* key pins the editor to what it is editing: without it, opening the
                                dialog on a second post would reuse the mounted instance and keep
                                the first post's text, since the surface only seeds on mount. */}
                            <RichTextEditor
                                key={dialog.kind === "add" ? "add" : `edit-${dialog.comment.id}`}
                                ref={editorRef}
                                initialValue={dialog.kind === "edit" ? dialog.comment.body : undefined}
                                placeholder={props.placeholder}
                                autoFocus
                                onSubmit={submit}
                                onEscape={closeDialog}
                                onEmptyChange={setDraftEmpty}
                            />
                        </div>
                        <div className="scb-dialog-foot">
                            <button className="scb-btn" onClick={closeDialog} disabled={busy}>Cancel</button>
                            <button
                                className="scb-btn scb-btn-primary"
                                onClick={submit}
                                disabled={busy || draftEmpty}
                            >
                                {dialog.kind === "add" ? "Post" : "Save"}
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};
