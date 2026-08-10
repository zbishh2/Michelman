// Admin CRUD for people — also the approved-editor list. Companies are what grant edit
// rights: a person may edit any row whose Order Company matches one of theirs; admins edit
// every company. Type 10, 0010 or 00010 — the Worker normalizes to the canonical 5-char code.
// Maps a
// USERPRINCIPALNAME email to a role (admin / editor / restricted). Gated to
// admins by the caller. Adapted (and slimmed) from DeliveryReliability.

import * as React from "react";
import { useEffect, useState } from "react";
import { ScrollPane } from "../grid/ScrollPane";
import { Person, PersonPatch, Role } from "../api";

interface PersonRowEditorProps {
    person: Person;
    onUpdate: (personKey: string, patch: PersonPatch) => Promise<void>;
}

const PersonRowEditor: React.FC<PersonRowEditorProps> = ({ person, onUpdate }) => {
    const [editing, setEditing] = useState(false);
    const [displayDraft, setDisplayDraft] = useState(person.displayName || person.personName);
    const [emailDraft, setEmailDraft] = useState(person.email ?? "");
    const [roleDraft, setRoleDraft] = useState<"" | Role>(person.role ?? "");
    const [companiesDraft, setCompaniesDraft] = useState((person.companies ?? []).join(", "));
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        if (!editing) {
            setDisplayDraft(person.displayName || person.personName);
            setEmailDraft(person.email ?? "");
            setRoleDraft(person.role ?? "");
            setCompaniesDraft((person.companies ?? []).join(", "));
            setError(null);
        }
    }, [person.displayName, person.personName, person.email, person.role, person.companies, editing]);

    const save = async () => {
        const patch: PersonPatch = {};
        const currentDisplay = person.displayName || person.personName;
        const trimmedDisplay = displayDraft.trim();
        if (trimmedDisplay !== currentDisplay) patch.displayName = trimmedDisplay || null;
        const trimmedEmail = emailDraft.trim().toLowerCase();
        if (trimmedEmail !== (person.email ?? "").toLowerCase()) patch.email = trimmedEmail || null;
        if (roleDraft !== (person.role ?? "")) patch.role = roleDraft === "" ? null : roleDraft;
        if (companiesDraft.trim() !== (person.companies ?? []).join(", ")) patch.companies = companiesDraft;
        if (Object.keys(patch).length === 0) { setEditing(false); return; }
        setSaving(true);
        setError(null);
        try {
            await onUpdate(person.personKey, patch);
            setEditing(false);
        } catch (e) {
            setError(e instanceof Error ? e.message : "save failed");
        } finally {
            setSaving(false);
        }
    };

    if (!editing) {
        return (
            <>
                <div className="rle-person-view">
                    <span className="rle-person-display">{person.displayName || person.personName}</span>
                    <button type="button" className="rle-btn rle-person-edit-btn" onClick={() => setEditing(true)}>Edit</button>
                </div>
                <div className="rle-person-admin-view">
                    <span className="rle-person-email-view">{person.email || "(no email)"}</span>
                    <span className="rle-person-role-view">{person.role === "admin" ? "admin (all companies)" : (person.companies ?? []).length ? (person.companies ?? []).join(", ") : "read-only"}</span>
                </div>
            </>
        );
    }
    return (
        <div className="rle-person-edit">
            <input className="rle-person-name-input" value={displayDraft} onChange={(e) => setDisplayDraft(e.target.value)} placeholder="Display name" disabled={saving} />
            <input className="rle-person-name-input" value={emailDraft} onChange={(e) => setEmailDraft(e.target.value)} placeholder="email@…" title="USERPRINCIPALNAME match" disabled={saving} />
            <select className="rle-people-select" value={roleDraft} onChange={(e) => setRoleDraft(e.target.value as "" | Role)} disabled={saving}>
                <option value="">(no role)</option>
                <option value="restricted">Restricted</option>
                <option value="editor">Editor</option>
                <option value="admin">Admin</option>
            </select>
            <input
                className="rle-person-name-input"
                value={companiesDraft}
                onChange={(e) => setCompaniesDraft(e.target.value)}
                placeholder="Companies e.g. 10, 20"
                title="Order companies this person may edit. Comma separated; 10 / 0010 / 00010 all mean 00010. Blank = read-only. Admins may edit every company."
                disabled={saving}
            />
            <div className="rle-person-edit-actions">
                <button type="button" className="rle-btn" disabled={saving} onClick={save}>{saving ? "Saving…" : "Save"}</button>
                <button type="button" className="rle-btn" disabled={saving} onClick={() => setEditing(false)}>Cancel</button>
            </div>
            {error && <div className="rle-person-edit-error">{error}</div>}
        </div>
    );
};

/**
 * The Active toggle and the Remove button. Both used to be a bare
 * `onClick={() => onX(key)}`: the promise rejected (a 403 from the Worker is the common
 * one — people writes are admin-only and Desktop's identity does not always resolve) and
 * nothing on screen changed, which is indistinguishable from a dead button. Errors now
 * land next to the control that caused them, and Remove confirms in place because
 * `window.confirm` is not dependable inside the Power BI visual sandbox.
 */
const PersonRowActions: React.FC<{
    person: Person;
    onUpdate: (personKey: string, patch: PersonPatch) => Promise<void>;
    onRemove: (personKey: string) => Promise<void>;
}> = ({ person, onUpdate, onRemove }) => {
    const [busy, setBusy] = useState(false);
    const [confirming, setConfirming] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const run = async (fn: () => Promise<void>) => {
        setBusy(true);
        setError(null);
        try {
            await fn();
        } catch (e) {
            setError(e instanceof Error ? e.message : "failed");
        } finally {
            setBusy(false);
        }
    };

    return (
        <div className="rle-person-actions">
            <div className="rle-person-actions-row">
                <label className="rle-person-active">
                    <input
                        type="checkbox"
                        checked={person.active}
                        disabled={busy}
                        onChange={(e) => { const active = e.target.checked; void run(() => onUpdate(person.personKey, { active })); }}
                    />
                    Active
                </label>
                {confirming ? (
                    <>
                        <button type="button" className="rle-btn rle-btn-danger" disabled={busy} onClick={() => void run(() => onRemove(person.personKey))}>
                            {busy ? "Removing…" : "Confirm"}
                        </button>
                        <button type="button" className="rle-btn" disabled={busy} onClick={() => setConfirming(false)}>Cancel</button>
                    </>
                ) : (
                    <button type="button" className="rle-btn" disabled={busy} onClick={() => { setError(null); setConfirming(true); }}>Remove</button>
                )}
            </div>
            {confirming && !error && (
                <div className="rle-person-action-note">
                    Delete {person.displayName || person.personName} permanently? Untick <em>Active</em> instead to keep the row.
                </div>
            )}
            {error && <div className="rle-person-action-error">{error}</div>}
        </div>
    );
};

export interface PeoplePanelProps {
    people: Person[];
    /**
     * Resolved from the visual's `Current User` field well. Null means the Worker will 403 every
     * save here with no on-screen reason, so name the cause instead of leaving it a mystery.
     */
    currentUserEmail: string | null;
    onClose: () => void;
    onSave: (person: { personName: string; displayName?: string | null; email?: string | null; role?: Role | null; active?: boolean; companies?: string[] | string }) => Promise<void>;
    onUpdate: (personKey: string, patch: PersonPatch) => Promise<void>;
    /** Hard delete — the person row and its company grants are gone for good. */
    onRemove: (personKey: string) => Promise<void>;
}

export const PeoplePanel: React.FC<PeoplePanelProps> = ({ people, currentUserEmail, onClose, onSave, onUpdate, onRemove }) => {
    const [name, setName] = useState("");
    const [displayName, setDisplayName] = useState("");
    const [email, setEmail] = useState("");
    const [role, setRole] = useState<"" | Role>("");
    const [companies, setCompanies] = useState("");
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const add = async () => {
        const trimmed = name.trim();
        if (!trimmed) return;
        setSaving(true);
        setError(null);
        try {
            await onSave({
                personName: trimmed,
                displayName: displayName.trim() || null,
                email: email.trim().toLowerCase() || null,
                role: role === "" ? null : role,
                companies,
                active: true,
            });
            setName(""); setDisplayName(""); setEmail(""); setRole(""); setCompanies("");
        } catch (e) {
            setError(e instanceof Error ? e.message : "save failed");
        } finally {
            setSaving(false);
        }
    };

    return (
        <div className="rle-modal-backdrop">
            <div className="rle-people-panel">
                <div className="rle-people-head">
                    <div className="rle-people-title">People &amp; Roles</div>
                    <button type="button" className="rle-icon-btn" onClick={onClose} title="Close">×</button>
                </div>
                {currentUserEmail === null && (
                    <div className="rle-error">
                        This visual can’t tell who you are — its <em>Current User</em> field is empty, so saves
                        {" "}will be rejected. In Desktop, drop the <code>[Current User]</code> measure into the
                        {" "}visual’s <em>Current User</em> well.
                    </div>
                )}
                <div className="rle-people-add" style={{ gridTemplateColumns: "minmax(90px,0.7fr) minmax(90px,1fr) minmax(120px,1fr) 130px minmax(110px,0.8fr) auto" }}>
                    <input className="rle-people-input" value={name} onChange={(e) => setName(e.target.value)} placeholder="Name / key" />
                    <input className="rle-people-input" value={displayName} onChange={(e) => setDisplayName(e.target.value)} placeholder="Display name (optional)" />
                    <input className="rle-people-input" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email" />
                    <select className="rle-people-select" value={role} onChange={(e) => setRole(e.target.value as "" | Role)}>
                        <option value="">(no role)</option>
                        <option value="restricted">Restricted</option>
                        <option value="editor">Editor</option>
                        <option value="admin">Admin</option>
                    </select>
                    <input
                        className="rle-people-input"
                        value={companies}
                        onChange={(e) => setCompanies(e.target.value)}
                        placeholder="Companies e.g. 10, 20"
                        title="Order companies this person may edit. Blank = read-only."
                    />
                    <button type="button" className="rle-btn" disabled={saving || !name.trim()} onClick={add}>Add</button>
                </div>
                {error && <div className="rle-error">{error}</div>}
                <ScrollPane>
                    <div className="rle-people-list">
                        {people.map((p) => (
                            <div className={"rle-person-row" + (!p.active ? " inactive" : "")} key={p.personKey}>
                                <div className="rle-person-name">
                                    <PersonRowEditor person={p} onUpdate={onUpdate} />
                                    <div className="rle-person-sub">{p.personName}</div>
                                </div>
                                <PersonRowActions person={p} onUpdate={onUpdate} onRemove={onRemove} />
                            </div>
                        ))}
                    </div>
                </ScrollPane>
            </div>
        </div>
    );
};
