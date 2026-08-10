// Reason Code Editor — a STANDALONE editable grid over the D1 `reason_dim`
// table (the editable reason-code dimension; `otif`=true means a revision with
// that code counts as an OTIF miss, `active`=false is a retired dim row).
// Unlike the Order Line Comments / Revision Log Editor visuals, the grid rows
// come entirely from the worker (GET /reason-dim), NOT from the Power BI
// dataView — the only field-well binding is a `currentUser` measure
// (USERPRINCIPALNAME()) used for role resolution, write attribution + the
// per-user saved layout.
// Editing is ADMIN-ONLY: this table drives OTIF, so only people with an `admin`
// role in the D1 `people` table can edit; everyone else gets a read-only grid.
// The visual disables edit affordances for non-admins and the worker enforces
// the same gate (403). Admins manage the roster via the People panel. The grid
// carries every column from the source workbook so no data is lost. Grid
// mechanics (resize / reorder / sort / filters / frozen columns / windowed
// render) are ported from the comments visual.

import * as React from "react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import powerbi from "powerbi-visuals-api";
import DataView = powerbi.DataView;

import {
    otifHitsApi, getActorEmail, setActorEmail,
    ReasonCode, ReasonCodePatch, ReasonCodeHistoryEntry, DropdownReasonCode,
    ReasonCategory, Person, Role,
} from "./api";
import { normalizeActorEmail, PersistedSort, formatTimestamp, copyTable } from "./util";
import { PeoplePanel } from "./people/PeoplePanel";
import {
    ColumnFilters, ColumnFilterState, FilterDataType,
    matchesTextCond, matchesNumCond, matchesDateCond,
} from "./filters";
import { AutoSizeCol, estimateColumnWidths } from "./autosize";
import { ScrollPane } from "./grid/ScrollPane";
import { ResizableTH } from "./grid/ResizableTH";
import { HeaderMenu } from "./grid/HeaderMenu";
import { CellContextMenu } from "./grid/ContextMenu";
import { NotesCell } from "./cells/NotesCell";
import { HistoryPanel } from "./panels/HistoryPanel";
import { ClassificationsPanel } from "./panels/ClassificationsPanel";

const POLL_MS = 20000;
const INITIAL_RENDER_CHUNK = 200;
// Must match capabilities.json dataViewMappings[].table.rows.dataReductionAlgorithm.top.count.
const DATA_REDUCTION_CAP = 30000;
const RENDER_CHUNK_INCREMENT = 200;
const NEAR_BOTTOM_PX = 800;

// ─── Fixed column model (rows are ReasonCode objects, not a dataView) ──────────

type OtifField =
    | "code" | "otif" | "description" | "longDescription"
    | "exemptionCriteria" | "category"
    | "review530" | "review540" | "typicalHit"
    | "oldClassification" | "usageExamples" | "regionNote"
    | "active" | "sortOrder" | "updatedBy" | "updatedAt";
type EditKind = "readonly" | "text" | "number" | "toggle" | "select";

interface OtifCol {
    field: OtifField;
    key: string;            // stable colKey (persisted in column order / widths)
    header: string;
    dataType: FilterDataType;
    edit: EditKind;
    numeric: boolean;       // right-align header/body
}

// The grid shows the columns the maintenance team actually edits. The rest of the
// source workbook ("Reason Codes 20181017") — exemptionCriteria, oldClassification,
// the three X-mark milestone columns (review530 / review540 / typicalHit), active
// and sortOrder — is still read, written and versioned by the API; it is simply not
// surfaced here (Zack, 2026-07-30). sortOrder still drives the default row order and
// `active` still governs dim-row validity; dropping a column from this array only
// hides it. Re-add an entry to bring one back.
const COLUMNS: OtifCol[] = [
    { field: "code", key: "otif:code", header: "Code", dataType: "text", edit: "readonly", numeric: false },
    { field: "otif", key: "otif:otif", header: "OTIF Relevant", dataType: "text", edit: "toggle", numeric: false },
    { field: "description", key: "otif:description", header: "Description", dataType: "text", edit: "text", numeric: false },
    { field: "longDescription", key: "otif:longDescription", header: "Long Description", dataType: "text", edit: "text", numeric: false },
    // Classification is a managed picklist, not free text — see ClassificationsPanel.
    { field: "category", key: "otif:category", header: "Classification", dataType: "text", edit: "select", numeric: false },
    { field: "usageExamples", key: "otif:usageExamples", header: "Examples: When to Use", dataType: "text", edit: "text", numeric: false },
    { field: "regionNote", key: "otif:regionNote", header: "Region Note", dataType: "text", edit: "text", numeric: false },
    { field: "updatedBy", key: "otif:updatedBy", header: "Updated By", dataType: "text", edit: "readonly", numeric: false },
    { field: "updatedAt", key: "otif:updatedAt", header: "Updated At", dataType: "date", edit: "readonly", numeric: false },
];

// Toggle columns are backed by a boolean field on the row.
const BOOL_FIELDS: Record<string, (r: ReasonCode) => boolean> = {
    otif: (r) => r.otif,
    active: (r) => r.active,
    review530: (r) => r.review530,
    review540: (r) => r.review540,
    typicalHit: (r) => r.typicalHit,
};

// Raw value used for sort + number/date filter conditions.
function rawValue(row: ReasonCode, field: OtifField): unknown {
    switch (field) {
        case "otif": return row.otif;
        case "active": return row.active;
        case "review530": return row.review530;
        case "review540": return row.review540;
        case "typicalHit": return row.typicalHit;
        case "sortOrder": return row.sortOrder;
        case "updatedAt": return row.updatedAt;
        case "code": return row.code;
        case "updatedBy": return row.updatedBy ?? null;
        default: return (row[field] as string | null) ?? null;
    }
}
// Display string used for rendering / copy / value-list filters.
function displayValue(row: ReasonCode, col: OtifCol): string {
    switch (col.field) {
        case "otif": return row.otif ? "Yes" : "No";
        case "active": return row.active ? "Yes" : "No";
        case "review530": return row.review530 ? "Yes" : "No";
        case "review540": return row.review540 ? "Yes" : "No";
        case "typicalHit": return row.typicalHit ? "Yes" : "No";
        case "sortOrder": return String(row.sortOrder);
        case "updatedAt": return row.updatedAt ? formatTimestamp(row.updatedAt) : "";
        case "code": return row.code;
        case "updatedBy": return row.updatedBy ?? "";
        default: return (row[col.field] as string | null) ?? "";
    }
}

interface SortState {
    key: string;
    direction: "asc" | "desc";
    col: OtifCol;
}

// ─── Inline single-line number editor (Sort Order) ─────────────────────────────
// Auto-commits on blur / Enter when the value changed; Esc reverts. While
// focused, incoming prop updates (the poll) are ignored so they can't clobber
// the in-progress draft — same discipline as NotesCell.
const NumberCell: React.FC<{ value: number; disabled: boolean; onCommit: (n: number) => void }> = ({ value, disabled, onCommit }) => {
    const [local, setLocal] = useState(String(value));
    const focusedRef = useRef(false);
    useEffect(() => { if (!focusedRef.current) setLocal(String(value)); }, [value]);
    const commit = () => {
        const n = Number(local);
        if (Number.isFinite(n) && Math.trunc(n) !== value) onCommit(Math.trunc(n));
        else setLocal(String(value));
    };
    return (
        <input
            className="olc-cell-num"
            type="number"
            disabled={disabled}
            value={local}
            onFocus={() => { focusedRef.current = true; }}
            onChange={(e) => setLocal(e.target.value)}
            onBlur={() => { focusedRef.current = false; commit(); }}
            onKeyDown={(e) => {
                if (e.key === "Enter") { (e.target as HTMLInputElement).blur(); }
                else if (e.key === "Escape") { setLocal(String(value)); focusedRef.current = false; (e.target as HTMLInputElement).blur(); }
            }}
            onClick={(e) => e.stopPropagation()}
        />
    );
};

// ─── Picklist cell (Classification) ────────────────────────────────────────────
// Commits on change — a <select> has no "in progress" state to protect, so unlike
// NotesCell / NumberCell there is no draft to guard against the poll.
// An off-list current value (a choice hidden after the row was set) is appended so the
// dropdown can still show what the row actually holds instead of snapping it to blank.
const SelectCell: React.FC<{
    value: string | null;
    options: string[];
    disabled: boolean;
    onCommit: (next: string | null) => void;
}> = ({ value, options, disabled, onCommit }) => {
    const current = value ?? "";
    const choices = current && !options.includes(current) ? [...options, current] : options;
    return (
        <select
            className="olc-cell-select"
            disabled={disabled}
            value={current}
            onClick={(e) => e.stopPropagation()}
            onChange={(e) => {
                const next = e.target.value;
                onCommit(next === "" ? null : next);
            }}
        >
            <option value="">(none)</option>
            {choices.map((o) => (
                <option key={o} value={o}>{o}</option>
            ))}
        </select>
    );
};

interface AppProps {
    dataView: DataView | null;
    title: { show: boolean; text: string; fontSize: number; color: string };
    tableFontSize: number;
    freezeColumns: number;
    initialWidths: Record<string, number>;
    initialColumnOrder: string[];
    initialSort: PersistedSort | null;
    initialColumnFilters: ColumnFilters;
    onPersistWidths: (widths: Record<string, number>) => void;
    onPersistColumnOrder: (order: string[]) => void;
    onPersistSort: (sort: PersistedSort | null) => void;
    onPersistColumnFilters: (filters: ColumnFilters) => void;
}

export const App: React.FC<AppProps> = ({
    dataView, title, tableFontSize, freezeColumns,
    initialWidths, initialColumnOrder, initialSort, initialColumnFilters,
    onPersistWidths, onPersistColumnOrder, onPersistSort, onPersistColumnFilters,
}) => {
    const cols = dataView?.table?.columns ?? [];
    const rows = dataView?.table?.rows ?? [];

    // Resolve the currentUser measure (the only field-well binding).
    const currentUserIdx = useMemo(() => {
        for (let i = 0; i < cols.length; i++) if (cols[i].roles?.["currentUser"]) return i;
        return -1;
    }, [cols]);
    const currentUserEmail = useMemo<string | null>(() => {
        if (currentUserIdx === -1) return null;
        for (const row of rows) {
            const email = normalizeActorEmail(row[currentUserIdx]);
            if (email) return email;
        }
        return null;
    }, [rows, currentUserIdx]);
    // The unnormalized value, kept ONLY so the read-only banner can show what the field well
    // actually returned when we could not make an identity out of it. Never sent to the Worker.
    const currentUserRaw = useMemo<string | null>(() => {
        if (currentUserIdx === -1) return null;
        for (const row of rows) {
            const v = row[currentUserIdx];
            if (v != null && String(v).trim()) return String(v).trim();
        }
        return null;
    }, [rows, currentUserIdx]);
    useEffect(() => { setActorEmail(currentUserEmail); }, [currentUserEmail]);

    const colByKey = useMemo(() => new Map(COLUMNS.map((c) => [c.key, c])), []);

    // ─── Column order (persisted to .pbix objects AND per-user D1 layout) ───
    const [columnOrder, setColumnOrder] = useState<string[]>(initialColumnOrder);
    const lastOrderSeededRef = useRef<string>(JSON.stringify(initialColumnOrder));
    const userLayoutAppliedRef = useRef(false);
    const userLayoutLoadedForRef = useRef<string | null>(null);

    useEffect(() => {
        const incoming = JSON.stringify(initialColumnOrder);
        if (incoming !== lastOrderSeededRef.current) {
            lastOrderSeededRef.current = incoming;
            setColumnOrder(initialColumnOrder);
            if (userLayoutAppliedRef.current) {
                userLayoutAppliedRef.current = false;
                otifHitsApi.deleteLayout().catch(() => { /* best effort */ });
            }
        }
    }, [initialColumnOrder]);

    useEffect(() => {
        if (!currentUserEmail) return;
        if (userLayoutLoadedForRef.current === currentUserEmail) return;
        userLayoutLoadedForRef.current = currentUserEmail;
        let cancelled = false;
        otifHitsApi.getLayout()
            .then((res) => {
                if (cancelled) return;
                const order = res.columnOrder;
                if (order && order.length) {
                    userLayoutAppliedRef.current = true;
                    setColumnOrder(order);
                }
            })
            .catch(() => { /* fall back to .pbix order */ });
        return () => { cancelled = true; };
    }, [currentUserEmail]);

    const resetUserLayout = useCallback(() => {
        userLayoutAppliedRef.current = false;
        otifHitsApi.deleteLayout().catch(() => { /* best effort */ });
        lastOrderSeededRef.current = JSON.stringify(initialColumnOrder);
        setColumnOrder(initialColumnOrder);
        onPersistColumnOrder(initialColumnOrder);
    }, [initialColumnOrder, onPersistColumnOrder]);

    const displayCols = useMemo(() => {
        if (columnOrder.length === 0) return COLUMNS;
        const byKey = new Map(COLUMNS.map((c) => [c.key, c]));
        const ordered: OtifCol[] = [];
        columnOrder.forEach((key) => {
            const spec = byKey.get(key);
            if (spec) { ordered.push(spec); byKey.delete(key); }
        });
        return [...ordered, ...COLUMNS.filter((c) => byKey.has(c.key))];
    }, [columnOrder]);

    const moveColumn = useCallback((fromKey: string, toKey: string) => {
        setColumnOrder(() => {
            const current = displayCols.map((c) => c.key);
            const fromIdx = current.indexOf(fromKey);
            const toIdx = current.indexOf(toKey);
            if (fromIdx === -1 || toIdx === -1 || fromIdx === toIdx) return current;
            const next = [...current];
            const [moved] = next.splice(fromIdx, 1);
            next.splice(toIdx, 0, moved);
            onPersistColumnOrder(next);
            userLayoutAppliedRef.current = true;
            otifHitsApi.saveLayout(next).catch(() => { /* best effort */ });
            lastOrderSeededRef.current = JSON.stringify(next);
            return next;
        });
    }, [displayCols, onPersistColumnOrder]);

    // ─── Reason-code dimension data (rows come from the worker) ───
    const [hits, setHits] = useState<ReasonCode[]>([]);
    const [reasonCodes, setReasonCodes] = useState<DropdownReasonCode[]>([]);
    const [people, setPeople] = useState<Person[]>([]);
    const [categories, setCategories] = useState<ReasonCategory[]>([]);
    const [error, setError] = useState<string | null>(null);
    const [loaded, setLoaded] = useState(false);

    const refresh = useCallback(async () => {
        try {
            const [hitsData, reasonData, peopleData, categoryData] = await Promise.all([
                otifHitsApi.getAll(),
                otifHitsApi.getReasonCodes(),
                otifHitsApi.getPeople(),
                otifHitsApi.getCategories(),
            ]);
            // JSON-equality bailout keeps the poll from churning the grid (scroll /
            // in-progress edits) when nothing changed.
            setHits((prev) => (JSON.stringify(prev) === JSON.stringify(hitsData) ? prev : hitsData));
            setReasonCodes((prev) => (JSON.stringify(prev) === JSON.stringify(reasonData) ? prev : reasonData));
            setPeople((prev) => (JSON.stringify(prev) === JSON.stringify(peopleData) ? prev : peopleData));
            setCategories((prev) => (JSON.stringify(prev) === JSON.stringify(categoryData) ? prev : categoryData));
            setLoaded(true);
            setError(null);
        } catch (e) {
            setError(e instanceof Error ? e.message : "fetch failed");
        }
    }, []);

    useEffect(() => {
        refresh();
        const id = window.setInterval(refresh, POLL_MS);
        const onFocus = () => refresh();
        window.addEventListener("focus", onFocus);
        return () => { window.clearInterval(id); window.removeEventListener("focus", onFocus); };
    }, [refresh]);

    // ─── Role gating (admin-only editing) ───
    // Resolve the current user's role from the `people` roster by matching their
    // USERPRINCIPALNAME() email. This table drives OTIF, so only admins may edit;
    // everyone else gets a read-only grid. The worker enforces the same gate.
    const currentPerson = useMemo<Person | null>(() => {
        if (!currentUserEmail) return null;
        const email = currentUserEmail.toLowerCase();
        return people.find((p) => p.active && (p.email ?? "").toLowerCase() === email) ?? null;
    }, [people, currentUserEmail]);
    const isAdmin = currentPerson?.role === "admin";
    const canEdit = loaded && isAdmin;

    // ─── Classification picklist CRUD (admin-managed choices) ───
    // A rename cascades to reason_dim server-side, so the reason-code rows change too —
    // refresh() rather than patching `categories` in place, or the grid would keep showing
    // the old classification until the next poll.
    const [classificationsOpen, setClassificationsOpen] = useState(false);
    const saveCategory = useCallback(async (body: { name: string; renameFrom?: string; sortOrder?: number; active?: boolean }) => {
        await otifHitsApi.saveCategory(body);
        await refresh();
    }, [refresh]);
    const removeCategory = useCallback(async (name: string) => {
        await otifHitsApi.removeCategory(name);
        await refresh();
    }, [refresh]);

    // Choices offered in the cell dropdown: active ones, in list order. A row carrying a
    // since-hidden value keeps showing it (appended below) so an edit to another column
    // cannot silently blank the classification.
    const categoryOptions = useMemo(
        () => categories.filter((c) => c.active).map((c) => c.name),
        [categories]
    );

    // ─── People CRUD (admin-managed roster; mirrors the sibling visuals) ───
    const [peopleOpen, setPeopleOpen] = useState(false);
    const savePerson = useCallback(async (person: { personName: string; displayName?: string | null; email?: string | null; role?: Role | null; active?: boolean; companies?: string[] | string }) => {
        const saved = await otifHitsApi.savePerson(person);
        setPeople((prev) => {
            const idx = prev.findIndex((p) => p.personKey === saved.personKey);
            if (idx === -1) return [...prev, saved];
            const next = [...prev]; next[idx] = saved; return next;
        });
    }, []);
    const updatePerson = useCallback(async (personKey: string, patch: { displayName?: string | null; email?: string | null; role?: Role | null; active?: boolean; companies?: string[] | string }) => {
        const saved = await otifHitsApi.updatePerson(personKey, patch);
        setPeople((prev) => prev.map((p) => (p.personKey === saved.personKey ? saved : p)));
    }, []);
    const deactivatePerson = useCallback(async (personKey: string) => {
        const saved = await otifHitsApi.deactivatePerson(personKey);
        setPeople((prev) => prev.map((p) => (p.personKey === saved.personKey ? saved : p)));
    }, []);
    const removePerson = useCallback(async (personKey: string) => {
        await otifHitsApi.removePerson(personKey);
        setPeople((prev) => prev.filter((p) => p.personKey !== personKey));
    }, []);

    // ─── Inline save (optimistic). The poll reconciles; edit cells keep their
    // draft while focused so a poll can't clobber it. ───
    const saveField = useCallback(async (code: string, patch: ReasonCodePatch) => {
        setHits((prev) => prev.map((r) => (r.code === code
            ? { ...r, ...patch, updatedBy: getActorEmail(), updatedAt: new Date().toISOString() }
            : r)));
        try {
            const saved = await otifHitsApi.upsert(code, patch);
            setHits((prev) => prev.map((r) => (r.code === saved.code ? saved : r)));
        } catch (e) {
            setError(e instanceof Error ? e.message : "save failed");
            refresh();
        }
    }, [refresh]);

    // ─── Add a new code (editor+). Offers the UDC 42/RR list as a datalist but
    // allows free text. ───
    const [addCode, setAddCode] = useState("");
    const [addDesc, setAddDesc] = useState("");
    const [adding, setAdding] = useState(false);
    const submitAdd = useCallback(async () => {
        const code = addCode.trim();
        if (!code) return;
        setAdding(true);
        setError(null);
        try {
            const patch: ReasonCodePatch = { otif: false, active: true };
            const sd = addDesc.trim();
            if (sd) patch.description = sd;
            const saved = await otifHitsApi.upsert(code, patch);
            setHits((prev) => [saved, ...prev.filter((r) => r.code !== saved.code)]);
            setAddCode(""); setAddDesc("");
        } catch (e) {
            setError(e instanceof Error ? e.message : "add failed");
        } finally {
            setAdding(false);
        }
    }, [addCode, addDesc]);

    // ─── Sorting (default = server order: sortOrder, code) ───
    const resolveSort = useCallback((s: PersistedSort | null): SortState | null => {
        if (!s) return null;
        const col = colByKey.get(s.key);
        if (!col) return null;
        return { key: s.key, direction: s.direction, col };
    }, [colByKey]);

    const [sort, setSort] = useState<SortState | null>(() => resolveSort(initialSort));
    const lastSortSeededRef = useRef<string>(JSON.stringify(initialSort ?? null));
    useEffect(() => {
        const incoming = JSON.stringify(initialSort ?? null);
        if (incoming === lastSortSeededRef.current) return;
        lastSortSeededRef.current = incoming;
        setSort(resolveSort(initialSort));
    }, [initialSort, resolveSort]);

    const setSortForKey = useCallback(
        (direction: "asc" | "desc" | null, build: (dir: "asc" | "desc") => SortState) => {
            setSort(() => {
                const next = direction ? build(direction) : null;
                const persisted: PersistedSort | null = next ? { key: next.key, direction: next.direction } : null;
                lastSortSeededRef.current = JSON.stringify(persisted);
                onPersistSort(persisted);
                return next;
            });
        },
        [onPersistSort],
    );

    const sortedRows = useMemo(() => {
        if (!sort) return hits;
        const direction = sort.direction === "asc" ? 1 : -1;
        const col = sort.col;
        return [...hits].sort((a, b) => {
            if (col.dataType === "number") {
                const an = Number(rawValue(a, col.field));
                const bn = Number(rawValue(b, col.field));
                if (isFinite(an) && isFinite(bn) && an !== bn) return (an - bn) * direction;
            }
            if (col.dataType === "date") {
                const at = Date.parse(String(rawValue(a, col.field) ?? ""));
                const bt = Date.parse(String(rawValue(b, col.field) ?? ""));
                if (isFinite(at) && isFinite(bt) && at !== bt) return (at - bt) * direction;
            }
            const av = displayValue(a, col);
            const bv = displayValue(b, col);
            if (!av && !bv) return 0;
            if (!av) return 1;
            if (!bv) return -1;
            return av.localeCompare(bv, undefined, { numeric: true, sensitivity: "base" }) * direction;
        });
    }, [hits, sort]);

    // ─── Column filters (local only — no model columns to push to the report) ───
    const [columnFilters, setColumnFilters] = useState<ColumnFilters>(initialColumnFilters);
    const lastFiltersSeededRef = useRef<string>(JSON.stringify(initialColumnFilters));
    useEffect(() => {
        const incoming = JSON.stringify(initialColumnFilters);
        if (incoming !== lastFiltersSeededRef.current) {
            lastFiltersSeededRef.current = incoming;
            setColumnFilters(initialColumnFilters);
        }
    }, [initialColumnFilters]);

    const distinctValuesFor = useCallback(
        (key: string): string[] => {
            const col = colByKey.get(key);
            if (!col) return [];
            const set = new Set<string>();
            for (const row of hits) set.add(displayValue(row, col));
            return Array.from(set).sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" }));
        },
        [hits, colByKey],
    );

    const activeColFilters = useMemo(
        () => Object.entries(columnFilters).filter(([, f]) => f != null) as [string, Exclude<ColumnFilterState, null>][],
        [columnFilters],
    );
    const valueFilterSets = useMemo(() => {
        const m = new Map<string, Set<string>>();
        for (const [key, f] of activeColFilters) if (f.mode === "values") m.set(key, new Set(f.selected));
        return m;
    }, [activeColFilters]);
    const anyFilterOn = activeColFilters.length > 0;

    const isRowVisible = useCallback(
        (row: ReasonCode): boolean => {
            for (const [key, f] of activeColFilters) {
                const col = colByKey.get(key);
                if (!col) continue;
                const display = displayValue(row, col);
                if (f.mode === "values") {
                    const set = valueFilterSets.get(key);
                    if (set && !set.has(display)) return false;
                } else {
                    const ok = col.dataType === "date" ? matchesDateCond(rawValue(row, col.field), f.op, f.value, f.valueTo)
                        : col.dataType === "number" ? matchesNumCond(rawValue(row, col.field), f.op, f.value, f.valueTo)
                        : matchesTextCond(display, f.op, f.value);
                    if (!ok) return false;
                }
            }
            return true;
        },
        [activeColFilters, valueFilterSets, colByKey],
    );
    const visibleRows = useMemo(
        () => (anyFilterOn ? sortedRows.filter(isRowVisible) : sortedRows),
        [sortedRows, isRowVisible, anyFilterOn],
    );

    const setColumnFilter = useCallback((key: string, state: ColumnFilterState) => {
        setColumnFilters((prev) => {
            const next = { ...prev };
            if (state == null) delete next[key]; else next[key] = state;
            lastFiltersSeededRef.current = JSON.stringify(next);
            onPersistColumnFilters(next);
            return next;
        });
    }, [onPersistColumnFilters]);
    const clearAllColumnFilters = useCallback(() => {
        setColumnFilters({});
        lastFiltersSeededRef.current = "{}";
        onPersistColumnFilters({});
    }, [onPersistColumnFilters]);

    // ─── Header menu ───
    const [headerMenu, setHeaderMenu] = useState<{ col: OtifCol; anchor: DOMRect } | null>(null);
    const openHeaderMenu = useCallback(
        (col: OtifCol, anchor: DOMRect) =>
            setHeaderMenu((cur) => (cur && cur.col.key === col.key ? null : { col, anchor })),
        [],
    );

    // ─── Windowed render ───
    const [renderLimit, setRenderLimit] = useState(INITIAL_RENDER_CHUNK);
    useEffect(() => { setRenderLimit(INITIAL_RENDER_CHUNK); }, [visibleRows.length, sort, columnFilters]);
    const renderedRows = useMemo(
        () => (renderLimit >= visibleRows.length ? visibleRows : visibleRows.slice(0, renderLimit)),
        [visibleRows, renderLimit],
    );
    const handleTableScroll = useCallback((el: HTMLDivElement) => {
        if (el.scrollHeight - el.scrollTop - el.clientHeight > NEAR_BOTTOM_PX) return;
        setRenderLimit((n) => (n >= visibleRows.length ? n : Math.min(n + RENDER_CHUNK_INCREMENT, visibleRows.length)));
    }, [visibleRows.length]);

    // ─── Widths / frozen columns ───
    const [widths, setWidths] = useState<Record<string, number>>(initialWidths);
    const [measuredWidths, setMeasuredWidths] = useState<Record<string, number>>({});
    const lastSeededRef = useRef<string>(JSON.stringify(initialWidths));
    useEffect(() => {
        const incoming = JSON.stringify(initialWidths);
        if (incoming !== lastSeededRef.current) { lastSeededRef.current = incoming; setWidths(initialWidths); }
    }, [initialWidths]);
    const setColumnWidth = useCallback((key: string, w: number) => setWidths((prev) => ({ ...prev, [key]: w })), []);
    const commitColumnWidth = useCallback((key: string, w: number) => {
        setWidths((prev) => {
            const next = { ...prev, [key]: w };
            onPersistWidths(next);
            lastSeededRef.current = JSON.stringify(next);
            return next;
        });
    }, [onPersistWidths]);

    const autoWidths = useMemo(() => {
        const columns: AutoSizeCol[] = displayCols.map((col) => ({
            key: col.key,
            header: col.header,
            wide: col.numeric || col.dataType === "date",
            valueAt: (i: number) => displayValue(visibleRows[i], col),
        }));
        return estimateColumnWidths(columns, visibleRows.length, tableFontSize);
    }, [displayCols, visibleRows, tableFontSize]);

    const widthFor = (key: string): number | undefined => widths[key] ?? autoWidths[key];
    const recordMeasuredWidth = useCallback((key: string, width: number) => {
        setMeasuredWidths((prev) => {
            const rounded = Math.round(width);
            return prev[key] === rounded ? prev : { ...prev, [key]: rounded };
        });
    }, []);

    const orderedKeys = useMemo(() => displayCols.map((c) => c.key), [displayCols]);
    const freezeColCount = Math.max(0, Math.min(Math.floor(freezeColumns) || 0, orderedKeys.length));
    const frozenKeys = orderedKeys.slice(0, freezeColCount);
    const widthOrMeasured = (key: string): number => widthFor(key) ?? measuredWidths[key] ?? 120;
    const frozenLeftFor = (key: string): number | undefined => {
        if (!frozenKeys.includes(key)) return undefined;
        let left = 0;
        for (const k of frozenKeys) { if (k === key) return left; left += widthOrMeasured(k); }
        return undefined;
    };
    const isFrozenBoundary = (key: string): boolean => frozenKeys.length > 0 && frozenKeys[frozenKeys.length - 1] === key;

    const allHeaders = useMemo(() => displayCols.map((c) => c.header), [displayCols]);
    const rowValuesFor = useCallback(
        (row: ReasonCode): string[] => displayCols.map((c) => displayValue(row, c)),
        [displayCols],
    );

    // ─── Panels / menus state ───
    const [ctxMenu, setCtxMenu] = useState<{ x: number; y: number; cellValue: string; rowValues: string[] } | null>(null);
    const [history, setHistory] = useState<
        { code: string; loading: boolean; error: string | null; entries: ReasonCodeHistoryEntry[] } | null
    >(null);

    const openCellMenu = (ev: React.MouseEvent, cellValue: string, row: ReasonCode) => {
        ev.preventDefault();
        ev.stopPropagation();
        setCtxMenu({ x: ev.clientX, y: ev.clientY, cellValue, rowValues: rowValuesFor(row) });
    };
    const copyWholeTable = () => {
        copyTable(allHeaders, visibleRows.map(rowValuesFor));
    };

    const openHistory = useCallback(async (code: string) => {
        setHistory({ code, loading: true, error: null, entries: [] });
        try {
            const entries = await otifHitsApi.getHistory(code);
            setHistory((h) => (h && h.code === code ? { ...h, loading: false, entries } : h));
        } catch (e) {
            const msg = e instanceof Error ? e.message : "load failed";
            setHistory((h) => (h && h.code === code ? { ...h, loading: false, error: msg } : h));
        }
    }, []);

    // ─── Cell renderers ───
    const renderCellBody = (row: ReasonCode, col: OtifCol) => {
        switch (col.edit) {
            case "toggle": {
                // Boolean columns: `otif` (THE driver — counts as an OTIF miss),
                // `active` (dim-row validity — retired = "do not use"), and the
                // three X-mark milestone flags from the workbook.
                const checked = (BOOL_FIELDS[col.field] ?? ((r: ReasonCode) => Boolean((r as unknown as Record<string, unknown>)[col.field])))(row);
                const title = col.field === "otif"
                    ? (row.otif ? "Counts as an OTIF miss — click to stop counting" : "Not counting — click to count as an OTIF miss")
                    : col.field === "active"
                    ? (row.active ? "Active dimension row — click to retire (do not use)" : "Retired — click to reactivate")
                    : (checked ? `${col.header}: yes — click to clear` : `${col.header}: no — click to set`);
                return (
                    <input
                        type="checkbox"
                        className="olc-toggle"
                        checked={checked}
                        disabled={!canEdit}
                        title={title}
                        onClick={(ev) => ev.stopPropagation()}
                        onChange={() => saveField(row.code, { [col.field]: !checked } as ReasonCodePatch)}
                    />
                );
            }
            case "text":
                return (
                    <NotesCell
                        value={(row[col.field] as string | null) ?? null}
                        disabled={!canEdit}
                        onCommit={(next) => saveField(row.code, { [col.field]: next } as ReasonCodePatch)}
                    />
                );
            case "select":
                return (
                    <SelectCell
                        value={(row[col.field] as string | null) ?? null}
                        options={categoryOptions}
                        disabled={!canEdit}
                        onCommit={(next) => saveField(row.code, { [col.field]: next } as ReasonCodePatch)}
                    />
                );
            case "number":
                return (
                    <NumberCell
                        value={row.sortOrder}
                        disabled={!canEdit}
                        onCommit={(n) => saveField(row.code, { sortOrder: n })}
                    />
                );
            default:
                if (col.field === "code") {
                    return (
                        <span className="olc-code-cell">
                            <span className="olc-code-text">{row.code}</span>
                            <button
                                type="button"
                                className="olc-history-btn"
                                title="View change history"
                                onClick={(ev) => { ev.stopPropagation(); openHistory(row.code); }}
                            >🕑</button>
                        </span>
                    );
                }
                return displayValue(row, col);
        }
    };

    const dataTh = (col: OtifCol) => (
        <ResizableTH
            key={`h-${col.key}`}
            label={col.header}
            width={widthFor(col.key)}
            numeric={col.numeric}
            onResize={(n) => setColumnWidth(col.key, n)}
            onResizeEnd={(n) => commitColumnWidth(col.key, n)}
            dragKey={col.key}
            onColumnDrop={moveColumn}
            sortDirection={sort?.key === col.key ? sort.direction : undefined}
            onOpenMenu={(rect) => openHeaderMenu(col, rect)}
            filterActive={!!columnFilters[col.key]}
            stickyLeft={frozenLeftFor(col.key)}
            frozenBoundary={isFrozenBoundary(col.key)}
            onMeasured={(w) => recordMeasuredWidth(col.key, w)}
        />
    );

    // Text/number edit cells get the tight padding used by the comment cell.
    const editableClass = (col: OtifCol): string =>
        col.edit === "text" || col.edit === "number" || col.edit === "select" ? "olc-cell-comment-edit" : "";


    // ─── Row-count status bar (under the totals row) ───────────────────────
    // Rows render in windows of 200, so "what am I looking at?" was unanswerable:
    // a grid that had only rendered its first window looked identical to one that had
    // hit a cap. Spell out rendered / matching / loaded, and say when Power BI's
    // 30,000-row visual cap has truncated the data rather than letting it pass as complete.
    const rowStatus = useMemo(() => {
        const loaded = rows.length;
        const matching = visibleRows.length;
        const rendered = renderedRows.length;
        const n = (x: number) => x.toLocaleString();
        const parts: string[] = [];
        parts.push(rendered < matching ? `Showing ${n(rendered)} of ${n(matching)} rows — scroll for more` : `${n(matching)} row${matching === 1 ? "" : "s"}`);
        if (matching !== loaded) parts.push(`filtered from ${n(loaded)}`);
        const atCap = loaded >= DATA_REDUCTION_CAP;
        return { text: parts.join(" · "), atCap };
    }, [rows.length, visibleRows.length, renderedRows.length]);

    return (
        <div className="olc-root">
            <div className="olc-header">
                {title.show ? (
                    <div className="olc-title" style={{ fontSize: title.fontSize, color: title.color }}>{title.text}</div>
                ) : <div />}
                <div className="olc-actions">
                    <button type="button" className="olc-btn" onClick={resetUserLayout} title="Reset your saved column order to the report default">Reset layout</button>
                    <button type="button" className="olc-btn" onClick={() => refresh()} title="Reload reason codes now">⟳ Refresh</button>
                    {isAdmin && (
                        <button type="button" className="olc-btn" onClick={() => setClassificationsOpen(true)} title="Maintain the choices in the Classification dropdown">Classifications</button>
                    )}
                    {/* Shown to everyone, not just admins. Gating this on isAdmin made it
                        useless in the one case it is most needed — locked out and wanting to
                        see who can let you back in. Non-admins get a read-only roster (the
                        panel hides every mutation control, and the Worker 403s regardless). */}
                    <button
                        type="button"
                        className="olc-btn"
                        onClick={() => setPeopleOpen(true)}
                        title={isAdmin ? "Maintain admins, roles and companies" : "View the People list (admins only can edit it)"}
                    >People</button>
                </div>
            </div>

            {/* Say WHICH reason applies, and always name the identity we resolved. "Restricted
                to admins" on its own sent an actual admin hunting through D1 permissions when
                the real cause was an unbound field well. The bound-but-unreadable case then
                did the same in reverse: it borrowed the "no field bound" wording even though
                the field WAS bound, hiding that Desktop's "DOMAIN\\user" principal was being
                thrown away. Those are now three separate messages, and the last one prints the
                raw value so it can be pasted straight into the People list. */}
            {loaded && !isAdmin && (
                <div className="olc-readonly-banner">
                    {currentUserIdx === -1
                        ? "Read-only — no \"Current User Email\" field is bound on this visual, so it cannot tell who you are. Drag the [Current User] measure into that field well."
                        : !currentUserEmail
                            ? `Read-only — the "Current User Email" field is bound but returned ${currentUserRaw ? `"${currentUserRaw}"` : "no value"}, which is not a recognisable identity. Check that it is the [Current User] measure (USERPRINCIPALNAME()).`
                            : !currentPerson
                                ? `Read-only — ${currentUserEmail} is not on the People list. Open People to see who can add you.`
                                : `Read-only — ${currentUserEmail} is on the People list but not an admin, and editing the reason-code table is admin-only.`}
                </div>
            )}

            {isAdmin && (
                <div className="olc-add-bar">
                    <span className="olc-add-label">Add reason code</span>
                    <input
                        className="olc-input olc-add-code"
                        list="olc-reason-codes"
                        value={addCode}
                        placeholder="Code (e.g. RFRV)"
                        onChange={(e) => setAddCode(e.target.value)}
                        onKeyDown={(e) => { if (e.key === "Enter") submitAdd(); }}
                    />
                    <datalist id="olc-reason-codes">
                        {reasonCodes.map((rc) => (
                            <option key={rc.codeId} value={rc.code}>{rc.label ?? rc.code}</option>
                        ))}
                    </datalist>
                    <input
                        className="olc-input olc-add-desc"
                        value={addDesc}
                        placeholder="Description (optional)"
                        onChange={(e) => setAddDesc(e.target.value)}
                        onKeyDown={(e) => { if (e.key === "Enter") submitAdd(); }}
                    />
                    <button type="button" className="olc-btn primary" disabled={adding || !addCode.trim()} onClick={submitAdd}>Add</button>
                </div>
            )}
            {error && <div className="olc-error">{error}</div>}

            <ScrollPane onScroll={handleTableScroll}>
                <table className="olc-table" style={{ fontSize: tableFontSize }}>
                    <colgroup>
                        {displayCols.map((col) => { const w = widthFor(col.key); return <col key={`cg-${col.key}`} style={w != null ? { width: w } : undefined} />; })}
                    </colgroup>
                    <thead>
                        <tr>{displayCols.map((col) => dataTh(col))}</tr>
                    </thead>
                    <tbody>
                        {renderedRows.map((row) => (
                            <tr key={`r-${row.code}`} className={row.active ? undefined : "olc-row-inactive"}>
                                {displayCols.map((col) => {
                                    const stickyLeft = frozenLeftFor(col.key);
                                    const text = displayValue(row, col);
                                    return (
                                        <td
                                            key={`c-${row.code}-${col.key}`}
                                            className={[
                                                col.numeric ? "num" : "",
                                                col.edit === "toggle" ? "olc-toggle-cell" : "",
                                                editableClass(col),
                                                stickyLeft != null ? "olc-frozen-col" : "",
                                                isFrozenBoundary(col.key) ? "olc-frozen-boundary" : "",
                                            ].filter(Boolean).join(" ")}
                                            style={stickyLeft != null ? { left: stickyLeft } : undefined}
                                            onContextMenu={(ev) => openCellMenu(ev, text, row)}
                                        >
                                            {renderCellBody(row, col)}
                                        </td>
                                    );
                                })}
                            </tr>
                        ))}
                        {loaded && visibleRows.length === 0 && (
                            <tr><td className="olc-empty" colSpan={displayCols.length}>{hits.length === 0 ? "No reason codes yet." : "No rows match the current filters."}</td></tr>
                        )}
                        {!loaded && !error && (
                            <tr><td className="olc-empty" colSpan={displayCols.length}>Loading…</td></tr>
                        )}
                    </tbody>
                </table>
            </ScrollPane>

            <div className="olc-statusbar">
                <span>{rowStatus.text}</span>
                {rowStatus.atCap && (
                    <span className="olc-statusbar-warn" title="Power BI stops sending rows to a custom visual at this limit. Filter the page to bring the population under the cap.">
                        ⚠ {DATA_REDUCTION_CAP.toLocaleString()}-row visual cap reached — rows beyond it are not loaded
                    </span>
                )}
            </div>

            {ctxMenu && (
                <CellContextMenu
                    x={ctxMenu.x}
                    y={ctxMenu.y}
                    onClose={() => setCtxMenu(null)}
                    onCopyValue={() => { copyTable(null, [[ctxMenu.cellValue]]); setCtxMenu(null); }}
                    onCopyRow={() => { copyTable(null, [ctxMenu.rowValues]); setCtxMenu(null); }}
                    onCopyRowWithHeaders={() => { copyTable(allHeaders, [ctxMenu.rowValues]); setCtxMenu(null); }}
                    onCopyTable={() => { copyWholeTable(); setCtxMenu(null); }}
                />
            )}

            {headerMenu && (() => {
                const hm = headerMenu;
                const buildSort = (dir: "asc" | "desc"): SortState => ({ key: hm.col.key, direction: dir, col: hm.col });
                return (
                    <HeaderMenu
                        anchor={hm.anchor}
                        label={hm.col.header}
                        dataType={hm.col.dataType}
                        values={distinctValuesFor(hm.col.key)}
                        currentFilter={columnFilters[hm.col.key] ?? null}
                        sortDirection={sort?.key === hm.col.key ? sort.direction : undefined}
                        hasAnyFilter={activeColFilters.length > 0}
                        onSort={(dir) => setSortForKey(dir, buildSort)}
                        onClearSort={() => setSortForKey(null, buildSort)}
                        onApply={(state) => setColumnFilter(hm.col.key, state)}
                        onClearAll={clearAllColumnFilters}
                        onClose={() => setHeaderMenu(null)}
                    />
                );
            })()}

            {history && (
                <HistoryPanel
                    code={history.code}
                    loading={history.loading}
                    error={history.error}
                    entries={history.entries}
                    onClose={() => setHistory(null)}
                />
            )}

            {classificationsOpen && isAdmin && (
                <ClassificationsPanel
                    categories={categories}
                    isAdmin={isAdmin}
                    onClose={() => setClassificationsOpen(false)}
                    onSave={saveCategory}
                    onRemove={removeCategory}
                />
            )}

            {/* No isAdmin gate on the mount — the panel takes isAdmin as a prop and renders a
                read-only roster without it, which is the whole point of letting a locked-out
                user open it. Every write still goes through the Worker's admin check. */}
            {peopleOpen && (
                <PeoplePanel
                    people={people}
                    isAdmin={isAdmin}
                    currentUserEmail={currentUserEmail}
                    onClose={() => setPeopleOpen(false)}
                    onSave={savePerson}
                    onUpdate={updatePerson}
                    onDeactivate={deactivatePerson}
                    onRemove={removePerson}
                />
            )}
        </div>
    );
};
