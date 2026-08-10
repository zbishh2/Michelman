// Classification picklist manager — the choices behind the "Classification"
// dropdown. Admin-only, mirroring the People panel.
//
// Why a managed list at all: the column used to be free text, which let "Operations (??)"
// sit alongside "Operations" and quietly split the classification in every OTIF rollup.
//
// Rename is the important operation, not delete. Renaming cascades to every reason code
// carrying the old value (server-side, logged into each code's history), so it is how you
// merge a typo away. Delete is refused while a choice is still in use — the panel shows
// the usage count so that refusal is predictable rather than a surprise 409.

import * as React from "react";
import { useEffect, useState } from "react";
import { ReasonCategory } from "../api";
import { ScrollPane } from "../grid/ScrollPane";

interface ClassificationsPanelProps {
    categories: ReasonCategory[];
    isAdmin: boolean;
    onClose: () => void;
    onSave: (body: { name: string; renameFrom?: string; sortOrder?: number; active?: boolean }) => Promise<void>;
    onRemove: (name: string) => Promise<void>;
}

const CategoryRowEditor: React.FC<{
    category: ReasonCategory;
    isAdmin: boolean;
    onSave: ClassificationsPanelProps["onSave"];
    onRemove: ClassificationsPanelProps["onRemove"];
}> = ({ category, isAdmin, onSave, onRemove }) => {
    const [editing, setEditing] = useState(false);
    const [nameDraft, setNameDraft] = useState(category.name);
    const [sortDraft, setSortDraft] = useState(String(category.sortOrder));
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        if (!editing) {
            setNameDraft(category.name);
            setSortDraft(String(category.sortOrder));
            setError(null);
        }
    }, [category.name, category.sortOrder, editing]);

    const run = async (fn: () => Promise<void>) => {
        setBusy(true);
        setError(null);
        try {
            await fn();
            setEditing(false);
        } catch (e) {
            setError(e instanceof Error ? e.message : "save failed");
        } finally {
            setBusy(false);
        }
    };

    const save = () => {
        const name = nameDraft.trim();
        if (!name) { setError("Name cannot be empty."); return; }
        const sortOrder = Number(sortDraft);
        const renamed = name !== category.name;
        if (!renamed && (!Number.isFinite(sortOrder) || sortOrder === category.sortOrder)) {
            setEditing(false);
            return;
        }
        return run(() => onSave({
            name,
            renameFrom: renamed ? category.name : undefined,
            sortOrder: Number.isFinite(sortOrder) ? sortOrder : undefined,
        }));
    };

    if (!editing) {
        return (
            <>
                <div className="olc-person-view">
                    <span className="olc-person-display">{category.name}</span>
                    {isAdmin && (
                        <button type="button" className="olc-btn olc-person-edit-btn" onClick={() => setEditing(true)}>
                            Edit
                        </button>
                    )}
                </div>
                <div className="olc-person-sub">
                    {category.inUse === 0
                        ? "not used by any reason code"
                        : `used by ${category.inUse} reason code${category.inUse === 1 ? "" : "s"}`}
                    {!category.active && " · hidden from the dropdown"}
                </div>
            </>
        );
    }

    return (
        <div className="olc-person-edit">
            <input
                className="olc-input"
                value={nameDraft}
                onChange={(e) => setNameDraft(e.target.value)}
                placeholder="Classification"
                title="Renaming updates every reason code that currently carries this classification."
                disabled={busy}
                onKeyDown={(e) => { if (e.key === "Enter") save(); if (e.key === "Escape") setEditing(false); }}
            />
            <input
                className="olc-input olc-cat-sort"
                value={sortDraft}
                onChange={(e) => setSortDraft(e.target.value)}
                placeholder="Sort"
                title="Order in the dropdown (low first)."
                disabled={busy}
            />
            <div className="olc-person-edit-actions">
                <button type="button" className="olc-btn" disabled={busy} onClick={save}>
                    {busy ? "Saving…" : "Save"}
                </button>
                <button type="button" className="olc-btn" disabled={busy} onClick={() => setEditing(false)}>
                    Cancel
                </button>
                {category.active ? (
                    <button
                        type="button"
                        className="olc-btn"
                        disabled={busy}
                        title="Keep it on existing rows but hide it from the dropdown for new edits."
                        onClick={() => run(() => onSave({ name: category.name, active: false }))}
                    >Hide</button>
                ) : (
                    <button
                        type="button"
                        className="olc-btn"
                        disabled={busy}
                        onClick={() => run(() => onSave({ name: category.name, active: true }))}
                    >Show</button>
                )}
                <button
                    type="button"
                    className="olc-btn"
                    disabled={busy || category.inUse > 0}
                    title={category.inUse > 0
                        ? `Used by ${category.inUse} reason code${category.inUse === 1 ? "" : "s"} — rename it onto another choice instead of deleting.`
                        : "Delete this unused choice."}
                    onClick={() => run(() => onRemove(category.name))}
                >Delete</button>
            </div>
            {error && <div className="olc-person-edit-error">{error}</div>}
        </div>
    );
};

export const ClassificationsPanel: React.FC<ClassificationsPanelProps> = ({
    categories, isAdmin, onClose, onSave, onRemove,
}) => {
    const [name, setName] = useState("");
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const add = async () => {
        const trimmed = name.trim();
        if (!trimmed) return;
        setBusy(true);
        setError(null);
        try {
            const maxSort = categories.reduce((m, c) => Math.max(m, c.sortOrder), 0);
            await onSave({ name: trimmed, sortOrder: maxSort + 10, active: true });
            setName("");
        } catch (e) {
            setError(e instanceof Error ? e.message : "save failed");
        } finally {
            setBusy(false);
        }
    };

    return (
        <div className="olc-modal-backdrop" onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}>
            <div className="olc-people-panel">
                <div className="olc-people-head">
                    <div className="olc-people-title">Classifications</div>
                    <button type="button" className="olc-icon-btn" onClick={onClose} title="Close">×</button>
                </div>
                <div className="olc-cat-hint">
                    These are the choices in the Classification column dropdown. Renaming one
                    updates every reason code that carries it.
                </div>
                {isAdmin && (
                    <div className="olc-people-add olc-cat-add">
                        <input
                            className="olc-input"
                            value={name}
                            onChange={(e) => setName(e.target.value)}
                            placeholder="New classification e.g. Logistics"
                            onKeyDown={(e) => { if (e.key === "Enter") add(); }}
                        />
                        <button type="button" className="olc-btn" disabled={busy || !name.trim()} onClick={add}>
                            Add
                        </button>
                    </div>
                )}
                {error && <div className="olc-error">{error}</div>}
                <div className="olc-people-body">
                    <ScrollPane>
                        <div className="olc-people-list">
                            {categories.map((c) => (
                                <div className={"olc-person-row" + (!c.active ? " inactive" : "")} key={c.name}>
                                    <div className="olc-person-name">
                                        <CategoryRowEditor
                                            category={c}
                                            isAdmin={isAdmin}
                                            onSave={onSave}
                                            onRemove={onRemove}
                                        />
                                    </div>
                                </div>
                            ))}
                            {categories.length === 0 && <div className="olc-thread-empty">No classifications yet.</div>}
                        </div>
                    </ScrollPane>
                </div>
            </div>
        </div>
    );
};
