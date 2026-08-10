// Admin CRUD for the revision-reason dropdown codes (D1 dropdown_reason_codes).
// Each code has a UDC 42/RR `code` (the value written into overrides) and an
// optional human `label`. Renaming a code cascades to stored overrides in the
// Worker. Adapted from DeliveryReliability's ReasonCodesPanel.

import * as React from "react";
import { useState } from "react";
import { ScrollPane } from "../grid/ScrollPane";
import { ReasonCode, ReasonCodePatch } from "../api";

export interface ReasonCodesPanelProps {
    codes: ReasonCode[];
    onClose: () => void;
    onSave: (code: { code: string; label?: string | null; sortOrder?: number }) => Promise<void>;
    onUpdate: (codeId: number, patch: ReasonCodePatch) => Promise<void>;
    onDeactivate: (codeId: number) => Promise<void>;
}

export const ReasonCodesPanel: React.FC<ReasonCodesPanelProps> = ({ codes, onClose, onSave, onUpdate, onDeactivate }) => {
    const [code, setCode] = useState("");
    const [label, setLabel] = useState("");
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [codeEdits, setCodeEdits] = useState<Record<number, string>>({});
    const [labelEdits, setLabelEdits] = useState<Record<number, string>>({});

    const add = async () => {
        const trimmedCode = code.trim();
        if (!trimmedCode) return;
        const maxSort = codes.reduce((m, c) => Math.max(m, c.sortOrder), 0);
        setSaving(true);
        setError(null);
        try {
            await onSave({ code: trimmedCode, label: label.trim() || null, sortOrder: maxSort + 10 });
            setCode("");
            setLabel("");
        } catch (e) {
            setError(e instanceof Error ? e.message : "save failed");
        } finally {
            setSaving(false);
        }
    };

    const clearEdit = (setter: React.Dispatch<React.SetStateAction<Record<number, string>>>, id: number) =>
        setter((prev) => { const n = { ...prev }; delete n[id]; return n; });

    const commitField = async (c: ReasonCode, field: "code" | "label") => {
        const draft = field === "code" ? codeEdits[c.codeId] : labelEdits[c.codeId];
        if (draft === undefined) return;
        const next = draft.trim();
        const current = field === "code" ? c.code : (c.label ?? "");
        const setter = field === "code" ? setCodeEdits : setLabelEdits;
        if (next === current || (field === "code" && !next)) { clearEdit(setter, c.codeId); return; }
        try {
            await onUpdate(c.codeId, field === "code" ? { code: next } : { label: next || null });
            clearEdit(setter, c.codeId);
        } catch (e) {
            setError(e instanceof Error ? e.message : "save failed");
        }
    };

    const move = async (c: ReasonCode, dir: -1 | 1) => {
        const sorted = [...codes].filter((x) => x.active).sort((a, b) => a.sortOrder - b.sortOrder || a.code.localeCompare(b.code));
        const idx = sorted.findIndex((x) => x.codeId === c.codeId);
        const swap = sorted[idx + dir];
        if (!swap) return;
        try {
            await Promise.all([
                onUpdate(c.codeId, { sortOrder: swap.sortOrder }),
                onUpdate(swap.codeId, { sortOrder: c.sortOrder }),
            ]);
        } catch (e) {
            setError(e instanceof Error ? e.message : "save failed");
        }
    };

    return (
        <div className="rle-modal-backdrop">
            <div className="rle-people-panel">
                <div className="rle-people-head">
                    <div className="rle-people-title">Revision Reason Codes</div>
                    <button type="button" className="rle-icon-btn" onClick={onClose} title="Close">×</button>
                </div>
                <div className="rle-people-add" style={{ gridTemplateColumns: "120px 1fr auto" }}>
                    <input
                        className="rle-people-input"
                        value={code}
                        onChange={(e) => setCode(e.target.value)}
                        placeholder="Code (e.g. RFRV)"
                        onKeyDown={(e) => { if (e.key === "Enter") add(); }}
                    />
                    <input
                        className="rle-people-input"
                        value={label}
                        onChange={(e) => setLabel(e.target.value)}
                        placeholder="Label (optional)"
                        onKeyDown={(e) => { if (e.key === "Enter") add(); }}
                    />
                    <button type="button" className="rle-btn" disabled={saving || !code.trim()} onClick={add}>Add</button>
                </div>
                {error && <div className="rle-error">{error}</div>}
                <ScrollPane>
                    <div className="rle-people-list">
                        {codes.map((c) => {
                            const codeVal = codeEdits[c.codeId] ?? c.code;
                            const labelVal = labelEdits[c.codeId] ?? (c.label ?? "");
                            return (
                                <div className={"rle-reason-row" + (!c.active ? " inactive" : "")} key={c.codeId}>
                                    <input
                                        className="rle-people-input"
                                        value={codeVal}
                                        title="UDC 42/RR code (stored on overrides)"
                                        onChange={(e) => setCodeEdits((prev) => ({ ...prev, [c.codeId]: e.target.value }))}
                                        onBlur={() => commitField(c, "code")}
                                        onKeyDown={(e) => {
                                            if (e.key === "Enter") (e.target as HTMLInputElement).blur();
                                            if (e.key === "Escape") clearEdit(setCodeEdits, c.codeId);
                                        }}
                                    />
                                    <input
                                        className="rle-people-input"
                                        value={labelVal}
                                        placeholder="(no label)"
                                        onChange={(e) => setLabelEdits((prev) => ({ ...prev, [c.codeId]: e.target.value }))}
                                        onBlur={() => commitField(c, "label")}
                                        onKeyDown={(e) => {
                                            if (e.key === "Enter") (e.target as HTMLInputElement).blur();
                                            if (e.key === "Escape") clearEdit(setLabelEdits, c.codeId);
                                        }}
                                    />
                                    <button type="button" className="rle-icon-btn" disabled={!c.active} title="Move up" onClick={() => move(c, -1)}>▲</button>
                                    <button type="button" className="rle-icon-btn" disabled={!c.active} title="Move down" onClick={() => move(c, 1)}>▼</button>
                                    <label className="rle-person-active">
                                        <input
                                            type="checkbox"
                                            checked={c.active}
                                            onChange={(e) => onUpdate(c.codeId, { active: e.target.checked })}
                                        />
                                        Active
                                    </label>
                                    <button type="button" className="rle-btn" disabled={!c.active} onClick={() => onDeactivate(c.codeId)}>Remove</button>
                                </div>
                            );
                        })}
                    </div>
                </ScrollPane>
            </div>
        </div>
    );
};
