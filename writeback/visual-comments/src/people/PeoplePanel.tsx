// People management panel — also the approved-editor list.
// Companies are what actually grant edit rights: a person may edit any row whose
// Order Company matches one of theirs; admins edit every company. Type 10, 0010 or
// 00010 — the Worker normalizes to the canonical 5-char code.
// (was) People management panel. Admins add / edit / deactivate people and set their
// role (admin / editor / restricted). Non-admins get a read-only roster.
// Role gating mirrors the worker (people writes are admin-only, 403 otherwise).

import * as React from "react";
import { useEffect, useState } from "react";
import { Person, Role } from "../api";
import { ScrollPane } from "../grid/ScrollPane";
import { CompanyMultiSelect } from "./CompanyMultiSelect";

interface PeoplePanelProps {
    people: Person[];
    isAdmin: boolean;
    /**
     * Companies offered in the picker — distinct Order Companies visible to the visual
     * (see App.tsx). Empty is survivable: the picker still lets an admin type a code.
     */
    availableCompanies: string[];
    /**
     * Resolved from the visual's `Current User` field well. Null means Power BI never told us
     * who is looking — every admin control silently disappears and the roster looks read-only
     * for no stated reason. That happened for real (Desktop dropped the binding), so say so
     * out loud rather than letting it read as a missing feature.
     */
    currentUserEmail: string | null;
    onClose: () => void;
    onSave: (person: { personName: string; displayName?: string | null; email?: string | null; role?: Role | null; active?: boolean; companies?: string[] | string }) => Promise<void>;
    onUpdate: (personKey: string, patch: { displayName?: string | null; email?: string | null; role?: Role | null; active?: boolean; companies?: string[] | string }) => Promise<void>;
    onDeactivate: (personKey: string) => Promise<void>;
    /** Hard delete — the person row and its company grants are gone for good. */
    onRemove: (personKey: string) => Promise<void>;
}

interface RowEditorProps {
    person: Person;
    isAdmin: boolean;
    availableCompanies: string[];
    onUpdate: (personKey: string, patch: { displayName?: string | null; email?: string | null; role?: Role | null; companies?: string[] }) => Promise<void>;
}

const PersonRowEditor: React.FC<RowEditorProps> = ({ person, isAdmin, availableCompanies, onUpdate }) => {
    const [editing, setEditing] = useState(false);
    const [displayDraft, setDisplayDraft] = useState(person.displayName || person.personName);
    const [emailDraft, setEmailDraft] = useState(person.email ?? "");
    const [roleDraft, setRoleDraft] = useState<"" | Role>(person.role ?? "");
    const [companiesDraft, setCompaniesDraft] = useState<string[]>(person.companies ?? []);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        if (!editing) {
            setDisplayDraft(person.displayName || person.personName);
            setEmailDraft(person.email ?? "");
            setRoleDraft(person.role ?? "");
            setCompaniesDraft(person.companies ?? []);
            setError(null);
        }
    }, [person.displayName, person.personName, person.email, person.role, person.companies, editing]);

    const save = async () => {
        const patch: { displayName?: string | null; email?: string | null; role?: Role | null; companies?: string[] } = {};
        const currentDisplay = person.displayName || person.personName;
        const trimmedDisplay = displayDraft.trim();
        if (trimmedDisplay !== currentDisplay) patch.displayName = trimmedDisplay || null;
        if (isAdmin) {
            const trimmedEmail = emailDraft.trim().toLowerCase();
            if (trimmedEmail !== (person.email ?? "").toLowerCase()) patch.email = trimmedEmail || null;
            if (roleDraft !== (person.role ?? "")) patch.role = roleDraft === "" ? null : roleDraft;
            // Whole-list replace, so send it whenever the set changed — including to empty,
            // which is how an admin revokes everything.
            if (companiesDraft.join(",") !== (person.companies ?? []).join(",")) patch.companies = companiesDraft;
        }
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
                <div className="olc-person-view">
                    <span className="olc-person-display">{person.displayName || person.personName}</span>
                    <button type="button" className="olc-btn olc-person-edit-btn" onClick={() => setEditing(true)}>Edit</button>
                </div>
                <div className="olc-person-sub">
                    {person.email || "(no email)"} · {person.role === "admin" ? "admin (all companies)" : (person.companies ?? []).length ? `companies ${(person.companies ?? []).join(", ")}` : "read-only"}
                </div>
            </>
        );
    }

    return (
        <div className="olc-person-edit">
            <input
                className="olc-input"
                value={displayDraft}
                onChange={(e) => setDisplayDraft(e.target.value)}
                placeholder="Display name"
                disabled={saving}
            />
            {isAdmin && (
                <>
                    <input
                        className="olc-input"
                        value={emailDraft}
                        onChange={(e) => setEmailDraft(e.target.value)}
                        placeholder="email@…"
                        title="User email (matched against USERPRINCIPALNAME)"
                        disabled={saving}
                    />
                    <select className="olc-input" value={roleDraft} onChange={(e) => setRoleDraft(e.target.value as "" | Role)} disabled={saving}>
                        <option value="">(no role)</option>
                        <option value="restricted">Restricted</option>
                        <option value="editor">Editor</option>
                        <option value="admin">Admin</option>
                    </select>
                    <CompanyMultiSelect
                        value={companiesDraft}
                        options={availableCompanies}
                        disabled={saving || roleDraft === "admin"}
                        disabledLabel={roleDraft === "admin" ? "All companies" : undefined}
                        onChange={setCompaniesDraft}
                    />
                </>
            )}
            <div className="olc-person-edit-actions">
                <button type="button" className="olc-btn" disabled={saving} onClick={save}>{saving ? "Saving…" : "Save"}</button>
                <button type="button" className="olc-btn" disabled={saving} onClick={() => setEditing(false)}>Cancel</button>
            </div>
            {error && <div className="olc-person-edit-error">{error}</div>}
        </div>
    );
};

/**
 * Deactivate / Reactivate / Remove for one row. These used to be bare
 * `onClick={() => onX(key)}` calls: the promise rejected (a 403 from the Worker is the
 * common one — people writes are admin-only and Desktop's identity does not always
 * resolve) and nothing on screen changed, which is indistinguishable from a dead button.
 * Errors now land next to the control that caused them, and Remove confirms in place
 * because `window.confirm` is not dependable inside the Power BI visual sandbox.
 */
const PersonRowActions: React.FC<{
    person: Person;
    onUpdate: PeoplePanelProps["onUpdate"];
    onDeactivate: PeoplePanelProps["onDeactivate"];
    onRemove: PeoplePanelProps["onRemove"];
}> = ({ person, onUpdate, onDeactivate, onRemove }) => {
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
        <div className="olc-person-actions">
            <div className="olc-person-actions-row">
                {person.active ? (
                    <button type="button" className="olc-btn" disabled={busy || confirming} onClick={() => void run(() => onDeactivate(person.personKey))}>
                        Deactivate
                    </button>
                ) : (
                    <button type="button" className="olc-btn" disabled={busy || confirming} onClick={() => void run(() => onUpdate(person.personKey, { active: true }))}>
                        Reactivate
                    </button>
                )}
                {confirming ? (
                    <>
                        <button type="button" className="olc-btn olc-btn-danger" disabled={busy} onClick={() => void run(() => onRemove(person.personKey))}>
                            {busy ? "Removing…" : "Confirm"}
                        </button>
                        <button type="button" className="olc-btn" disabled={busy} onClick={() => setConfirming(false)}>Cancel</button>
                    </>
                ) : (
                    <button type="button" className="olc-btn" disabled={busy} onClick={() => { setError(null); setConfirming(true); }}>Remove</button>
                )}
            </div>
            {confirming && !error && (
                <div className="olc-person-action-note">
                    Delete {person.displayName || person.personName} permanently? <em>Deactivate</em> keeps the row.
                </div>
            )}
            {error && <div className="olc-person-action-error">{error}</div>}
        </div>
    );
};

export const PeoplePanel: React.FC<PeoplePanelProps> = ({ people, isAdmin, availableCompanies, currentUserEmail, onClose, onSave, onUpdate, onDeactivate, onRemove }) => {
    const [name, setName] = useState("");
    const [displayName, setDisplayName] = useState("");
    const [email, setEmail] = useState("");
    const [role, setRole] = useState<"" | Role>("");
    const [companies, setCompanies] = useState<string[]>([]);
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
            setName(""); setDisplayName(""); setEmail(""); setRole(""); setCompanies([]);
        } catch (e) {
            setError(e instanceof Error ? e.message : "save failed");
        } finally {
            setSaving(false);
        }
    };

    return (
        <div className="olc-modal-backdrop" onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}>
            <div className="olc-people-panel">
                <div className="olc-people-head">
                    <div className="olc-people-title">People</div>
                    <button type="button" className="olc-icon-btn" onClick={onClose} title="Close">×</button>
                </div>
                {!isAdmin && (
                    <div className="olc-people-note">
                        {currentUserEmail === null ? (
                            <>
                                <strong>This visual can’t tell who you are.</strong> Its <em>Current User</em>
                                {" "}field is empty, so admin controls are hidden. In Desktop, drop the
                                {" "}<code>[Current User]</code> measure into the visual’s <em>Current User</em> well.
                            </>
                        ) : (
                            <>
                                Signed in as <strong>{currentUserEmail}</strong> — not an admin, so the roster is
                                {" "}read-only. Only admins add people or set companies.
                            </>
                        )}
                    </div>
                )}
                {isAdmin && (
                    <div className="olc-people-add">
                        <input className="olc-input" value={name} onChange={(e) => setName(e.target.value)} placeholder="Name / login (key)" />
                        <input className="olc-input" value={displayName} onChange={(e) => setDisplayName(e.target.value)} placeholder="Display name (optional)" />
                        <input className="olc-input" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email" />
                        <select className="olc-input" value={role} onChange={(e) => setRole(e.target.value as "" | Role)}>
                            <option value="">(no role)</option>
                            <option value="restricted">Restricted</option>
                            <option value="editor">Editor</option>
                            <option value="admin">Admin</option>
                        </select>
                        <CompanyMultiSelect
                            value={companies}
                            options={availableCompanies}
                            disabled={saving || role === "admin"}
                            disabledLabel={role === "admin" ? "All companies" : undefined}
                            onChange={setCompanies}
                        />
                        <button type="button" className="olc-btn" disabled={saving || !name.trim()} onClick={add}>Add</button>
                    </div>
                )}
                {error && <div className="olc-error">{error}</div>}
                <div className="olc-people-body">
                    <ScrollPane>
                        <div className="olc-people-list">
                            {people.map((p) => (
                                <div className={"olc-person-row" + (!p.active ? " inactive" : "")} key={p.personKey}>
                                    <div className="olc-person-name">
                                        <PersonRowEditor person={p} isAdmin={isAdmin} availableCompanies={availableCompanies} onUpdate={onUpdate} />
                                    </div>
                                    {isAdmin && (
                                        <PersonRowActions person={p} onUpdate={onUpdate} onDeactivate={onDeactivate} onRemove={onRemove} />
                                    )}
                                </div>
                            ))}
                            {people.length === 0 && <div className="olc-thread-empty">No people yet.</div>}
                        </div>
                    </ScrollPane>
                </div>
            </div>
        </div>
    );
};
