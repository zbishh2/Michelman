"use strict";

import * as React from "react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import powerbi from "powerbi-visuals-api";
import { IFilter } from "powerbi-models";
import DataView = powerbi.DataView;
import DataViewMetadataColumn = powerbi.DataViewMetadataColumn;

import {
    HistoryEntry, Override, OverrideMap, OverridePatch, Person, PersonPatch,
    ReasonCode, ReasonCodePatch, Role, revisionsApi, setActorEmail,
} from "./api";
import { colKey, isNumericCol, isDateCol, renderCell, normalizeActorEmail, fmtNumber } from "./format";
import {
    ColumnFilters, ColumnFilterState, FilterDataType, buildReportFilters, colDataType,
    matchesDateCond, matchesNumCond, matchesTextCond,
} from "./filters";
import { ColSpec, EditField, KEY_REASON, PersistedSort, SortState } from "./types";
import { AutoSizeCol, estimateColumnWidths } from "./autosize";
import { ScrollPane } from "./grid/ScrollPane";
import { ResizableTH } from "./grid/ResizableTH";
import { HeaderMenu } from "./grid/HeaderMenu";
import { SelectCell, SelectOption } from "./cells/SelectCell";
import { HistoryPanel } from "./panels/HistoryPanel";
import { ReasonCodesPanel } from "./panels/ReasonCodesPanel";
import { PeoplePanel } from "./panels/PeoplePanel";
import { buildPermissions } from "./permissions";
import { AuditLogPanel } from "./panels/AuditLogPanel";
import { CellContextMenu } from "./panels/CellContextMenu";
import { copyTable } from "./clipboard";

const POLL_MS = 20000;
const INITIAL_RENDER_CHUNK = 200;
// Must match capabilities.json dataViewMappings[].table.rows.dataReductionAlgorithm.top.count.
const DATA_REDUCTION_CAP = 30000;
const RENDER_CHUNK_INCREMENT = 200;
const NEAR_BOTTOM_PX = 800;

export interface AppProps {
    dataView: DataView | null;
    /**
     * The viewer's email, resolved by visual.tsx from the separate identity dataView.
     * Deliberately NOT read off `dataView`'s rows — see identity.ts for why that query had to
     * be split out. Null means the Current User field well is empty.
     */
    currentUserEmail: string | null;
    title: { show: boolean; text: string; fontSize: number; color: string };
    tableFontSize: number;
    editablePosition: number;
    freezeColumns: number;
    initialWidths: Record<string, number>;
    initialColumnOrder: string[];
    initialSort: PersistedSort | null;
    initialColumnFilters: ColumnFilters;
    onPersistWidths: (widths: Record<string, number>) => void;
    onPersistColumnOrder: (order: string[]) => void;
    onPersistSort: (sort: PersistedSort | null) => void;
    onPersistColumnFilters: (filters: ColumnFilters) => void;
    onApplyReportFilters: (filters: IFilter[]) => void;
}

function projectionIndex(c: DataViewMetadataColumn, fallback: number): number {
    if (typeof c.index === "number") return c.index;
    const extended = c as unknown as { rolesIndex?: Record<string, number>; rolesIndexes?: Record<string, number> };
    if (typeof extended.rolesIndex?.["columns"] === "number") return extended.rolesIndex["columns"];
    if (typeof extended.rolesIndexes?.["columns"] === "number") return extended.rolesIndexes["columns"];
    return fallback;
}

// Split the opaque revisionKey (orderLineId|yyyy-MM-dd|hhmmss) into its parts so
// the first write can populate the denormalized D1 columns. The Worker treats
// the key as opaque; this parse is best-effort and only used for readability.
function revisionKeyParts(key: string): { orderLineId: string | null; changeDate: string | null; changeTime: string | null } {
    const i1 = key.indexOf("|");
    if (i1 < 0) return { orderLineId: key || null, changeDate: null, changeTime: null };
    const i2 = key.indexOf("|", i1 + 1);
    if (i2 < 0) return { orderLineId: key.slice(0, i1) || null, changeDate: key.slice(i1 + 1) || null, changeTime: null };
    return {
        orderLineId: key.slice(0, i1) || null,
        changeDate: key.slice(i1 + 1, i2) || null,
        changeTime: key.slice(i2 + 1) || null,
    };
}

export const App: React.FC<AppProps> = ({
    dataView, currentUserEmail, title, tableFontSize, editablePosition, freezeColumns, initialWidths, initialColumnOrder,
    initialSort, initialColumnFilters, onPersistWidths, onPersistColumnOrder, onPersistSort,
    onPersistColumnFilters, onApplyReportFilters,
}) => {
    const table = dataView?.table;
    const cols = table?.columns ?? [];
    const rows = table?.rows ?? [];

    // Resolve the revisionKey column and gather the display columns (role "columns"). A column
    // tagged revisionKey AND columns both renders and acts as the join key. currentUser is NOT
    // resolved here — it rides its own dataView so it never widens this query (identity.ts).
    const { rawDisplayCols, revisionKeyIdx } = useMemo(() => {
        let revisionKeyIdx = -1;
        const list: ColSpec[] = [];
        cols.forEach((c, i) => {
            const roles = c.roles || {};
            const isKey = !!roles["revisionKey"];
            if (isKey && revisionKeyIdx === -1) revisionKeyIdx = i;
            if (roles["columns"]) {
                list.push({ metaIndex: i, column: c, isRevisionKey: isKey, projectionIndex: projectionIndex(c, i) });
            }
        });
        list.sort((a, b) => (a.projectionIndex !== b.projectionIndex ? a.projectionIndex - b.projectionIndex : a.metaIndex - b.metaIndex));
        return { rawDisplayCols: list, revisionKeyIdx };
    }, [cols]);

    useEffect(() => { setActorEmail(currentUserEmail); }, [currentUserEmail]);

    // ─── Column order (report objects + per-user D1 layout) ───
    const [columnOrder, setColumnOrder] = useState<string[]>(initialColumnOrder);
    const lastOrderSeededRef = useRef<string>(JSON.stringify(initialColumnOrder));
    const userLayoutAppliedRef = useRef(false);
    const userLayoutLoadedForRef = useRef<string | null>(null);

    useEffect(() => {
        const incoming = JSON.stringify(initialColumnOrder);
        if (incoming !== lastOrderSeededRef.current) {
            lastOrderSeededRef.current = incoming;
            setColumnOrder(initialColumnOrder);
            // .pbix order reverted mid-session while a per-user override was live
            // (native "Reset to default") — clear the saved layout so it stays reset.
            if (userLayoutAppliedRef.current) {
                userLayoutAppliedRef.current = false;
                revisionsApi.deleteLayout().catch(() => { /* best effort */ });
            }
        }
    }, [initialColumnOrder]);

    useEffect(() => {
        if (!currentUserEmail) return;
        if (userLayoutLoadedForRef.current === currentUserEmail) return;
        userLayoutLoadedForRef.current = currentUserEmail;
        let cancelled = false;
        revisionsApi.getLayout()
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
        revisionsApi.deleteLayout().catch(() => { /* best effort */ });
        lastOrderSeededRef.current = JSON.stringify(initialColumnOrder);
        setColumnOrder(initialColumnOrder);
        onPersistColumnOrder(initialColumnOrder);
    }, [initialColumnOrder, onPersistColumnOrder]);

    const displayCols = useMemo(() => {
        if (columnOrder.length === 0) return rawDisplayCols;
        const byKey = new Map(rawDisplayCols.map((spec) => [colKey(spec.column), spec]));
        const ordered: ColSpec[] = [];
        columnOrder.forEach((key) => {
            const spec = byKey.get(key);
            if (spec) { ordered.push(spec); byKey.delete(key); }
        });
        return [...ordered, ...rawDisplayCols.filter((spec) => byKey.has(colKey(spec.column)))];
    }, [rawDisplayCols, columnOrder]);

    const moveColumn = useCallback((fromKey: string, toKey: string) => {
        setColumnOrder(() => {
            const current = displayCols.map((spec) => colKey(spec.column));
            const fromIdx = current.indexOf(fromKey);
            const toIdx = current.indexOf(toKey);
            if (fromIdx === -1 || toIdx === -1 || fromIdx === toIdx) return columnOrder;
            const next = [...current];
            const [moved] = next.splice(fromIdx, 1);
            next.splice(toIdx, 0, moved);
            onPersistColumnOrder(next);
            userLayoutAppliedRef.current = true;
            revisionsApi.saveLayout(next).catch(() => { /* best effort */ });
            lastOrderSeededRef.current = JSON.stringify(next);
            return next;
        });
    }, [displayCols, columnOrder, onPersistColumnOrder]);

    // ─── Sort ───
    const editFieldForKey = (key: string): EditField | null =>
        key === KEY_REASON ? "revisionReason" : null;

    const resolveSort = useCallback((s: PersistedSort | null): SortState | null => {
        if (!s) return null;
        const ef = editFieldForKey(s.key);
        if (ef) return { key: s.key, direction: s.direction, metaIndex: -1, column: null, editField: ef };
        const spec = rawDisplayCols.find((c) => colKey(c.column) === s.key);
        if (!spec) return null;
        return { key: s.key, direction: s.direction, metaIndex: spec.metaIndex, column: spec.column, editField: null };
    }, [rawDisplayCols]);

    const [sort, setSort] = useState<SortState | null>(() => resolveSort(initialSort));
    const lastSortSeededRef = useRef<string>(JSON.stringify(initialSort ?? null));
    useEffect(() => {
        const incoming = JSON.stringify(initialSort ?? null);
        if (incoming === lastSortSeededRef.current) return;
        lastSortSeededRef.current = incoming;
        setSort(resolveSort(initialSort));
    }, [initialSort, resolveSort]);
    // Re-resolve metaIndex/column when the dataView refreshes (ordinals shift).
    useEffect(() => {
        setSort((prev) => {
            if (!prev || prev.editField) return prev;
            const spec = rawDisplayCols.find((s) => colKey(s.column) === prev.key);
            if (!spec) return null;
            if (spec.metaIndex === prev.metaIndex && spec.column === prev.column) return prev;
            return { ...prev, metaIndex: spec.metaIndex, column: spec.column };
        });
    }, [rawDisplayCols]);

    const setSortForKey = useCallback(
        (direction: "asc" | "desc" | null, build: (dir: "asc" | "desc") => SortState) => {
            setSort(() => {
                const next = direction ? build(direction) : null;
                const persisted: PersistedSort | null = next ? { key: next.key, direction: next.direction } : null;
                lastSortSeededRef.current = JSON.stringify(persisted);
                onPersistSort(persisted);
                return next;
            });
        }, [onPersistSort]);

    // ─── State ───
    const [overrides, setOverrides] = useState<OverrideMap>({});
    const [people, setPeople] = useState<Person[]>([]);
    const [reasonCodes, setReasonCodes] = useState<ReasonCode[]>([]);
    const [peopleOpen, setPeopleOpen] = useState(false);
    const [codesOpen, setCodesOpen] = useState(false);
    const [auditOpen, setAuditOpen] = useState(false);
    const [loaded, setLoaded] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [widths, setWidths] = useState<Record<string, number>>(initialWidths);
    const [measuredWidths, setMeasuredWidths] = useState<Record<string, number>>({});
    const [editedFilterOn, setEditedFilterOn] = useState(false);
    const [ctxMenu, setCtxMenu] = useState<{ x: number; y: number; cellValue: string; rowValues: string[]; revisionKey: string | null } | null>(null);
    const [historyKey, setHistoryKey] = useState<string | null>(null);
    const [history, setHistory] = useState<HistoryEntry[]>([]);
    const [historyLoading, setHistoryLoading] = useState(false);
    const [historyError, setHistoryError] = useState<string | null>(null);

    useEffect(() => {
        if (!historyKey) return;
        let cancelled = false;
        setHistoryLoading(true);
        setHistoryError(null);
        setHistory([]);
        revisionsApi.getHistory(historyKey)
            .then((rows) => { if (!cancelled) setHistory(rows); })
            .catch((e: unknown) => { if (!cancelled) setHistoryError(e instanceof Error ? e.message : "Failed to load history"); })
            .finally(() => { if (!cancelled) setHistoryLoading(false); });
        return () => { cancelled = true; };
    }, [historyKey]);

    // ─── Reason code options + code→label ───
    const activeReasonCodes = useMemo(
        () => reasonCodes.filter((c) => c.active).slice().sort((a, b) => a.sortOrder - b.sortOrder || a.code.localeCompare(b.code)),
        [reasonCodes]);
    const codeToLabel = useMemo(() => {
        const m = new Map<string, string>();
        for (const c of reasonCodes) m.set(c.code, c.label ? `${c.code} - ${c.label}` : c.code);
        return m;
    }, [reasonCodes]);
    const reasonOptions = useMemo<SelectOption[]>(
        () => activeReasonCodes.map((c) => ({ value: c.code, label: c.label ? `${c.code} - ${c.label}` : c.code })),
        [activeReasonCodes]);
    const reasonDisplay = useCallback((code: string | null | undefined): string => {
        if (!code) return "";
        return codeToLabel.get(code) ?? code;
    }, [codeToLabel]);

    // ─── Roles ───
    const currentPerson = useMemo<Person | null>(() => {
        if (!currentUserEmail) return null;
        return people.find((p) => p.active && p.email && p.email.toLowerCase() === currentUserEmail) ?? null;
    }, [people, currentUserEmail]);
    const isAdmin = currentPerson?.role === "admin";
    // Company-gated editing (2026-07-28), matching the Order Line Comments visual: a viewer
    // may edit a revision only if they are an admin, or the People list assigns them that
    // row's Order Company. revision_key opens with the Order Line ID, so its first comma
    // segment is the company — no extra field binding needed. The Worker enforces this too.
    const perms = useMemo(() => buildPermissions(people, currentUserEmail), [people, currentUserEmail]);
    // Editing is open to anyone with report access — no People-list membership
    // required. People are fetched only for admin buttons and email→name display.

    // ─── Column filters ───
    const colByKey = useMemo(() => new Map<string, ColSpec>(rawDisplayCols.map((s) => [colKey(s.column), s])), [rawDisplayCols]);
    const [columnFilters, setColumnFilters] = useState<ColumnFilters>(initialColumnFilters);
    const lastFiltersSeededRef = useRef<string>(JSON.stringify(initialColumnFilters));
    useEffect(() => {
        const incoming = JSON.stringify(initialColumnFilters);
        if (incoming !== lastFiltersSeededRef.current) {
            lastFiltersSeededRef.current = incoming;
            setColumnFilters(initialColumnFilters);
        }
    }, [initialColumnFilters]);

    const overrideFor = useCallback((row: powerbi.DataViewTableRow): Override | undefined => {
        const rk = row[revisionKeyIdx] == null ? "" : String(row[revisionKeyIdx]);
        return rk ? overrides[rk] : undefined;
    }, [overrides, revisionKeyIdx]);

    // The string a column shows for a row (data columns via renderCell; editable
    // columns via the overrides map).
    const valueForKey = useCallback((row: powerbi.DataViewTableRow, key: string, spec?: ColSpec): string => {
        if (key === KEY_REASON) {
            const o = overrideFor(row);
            return o ? reasonDisplay(o.revisionReason) : "";
        }
        const s = spec ?? colByKey.get(key);
        return s ? renderCell(row[s.metaIndex], s.column) : "";
    }, [overrideFor, reasonDisplay, colByKey]);

    const distinctValuesFor = useCallback((key: string): string[] => {
        const set = new Set<string>();
        const spec = colByKey.get(key);
        for (const row of rows) set.add(valueForKey(row, key, spec));
        return Array.from(set).sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" }));
    }, [rows, valueForKey, colByKey]);

    const activeColFilters = useMemo(
        () => Object.entries(columnFilters).filter(([, f]) => f != null) as [string, Exclude<ColumnFilterState, null>][],
        [columnFilters]);
    const valueFilterSets = useMemo(() => {
        const m = new Map<string, Set<string>>();
        for (const [key, f] of activeColFilters) if (f.mode === "values") m.set(key, new Set(f.selected));
        return m;
    }, [activeColFilters]);

    const anyFilterOn = editedFilterOn || activeColFilters.length > 0;

    const isRowVisible = useCallback((row: powerbi.DataViewTableRow): boolean => {
        if (editedFilterOn) {
            // An override row only exists once someone has written to it, so its
            // presence *is* the "edited" flag — no time window.
            if (!overrideFor(row)) return false;
        }
        for (const [key, f] of activeColFilters) {
            const isEditable = key.startsWith("edit:");
            const spec = isEditable ? undefined : colByKey.get(key);
            if (!isEditable && !spec) continue; // column gone → inert
            const display = valueForKey(row, key, spec);
            if (f.mode === "values") {
                const set = valueFilterSets.get(key);
                if (set && !set.has(display)) return false;
            } else {
                const dt: FilterDataType = isEditable ? "text" : colDataType(spec!.column, null);
                const raw = isEditable ? display : row[spec!.metaIndex];
                const ok = dt === "date" ? matchesDateCond(raw, f.op, f.value, f.valueTo)
                    : dt === "number" ? matchesNumCond(raw, f.op, f.value, f.valueTo)
                    : matchesTextCond(display, f.op, f.value);
                if (!ok) return false;
            }
        }
        return true;
    }, [editedFilterOn, overrideFor, activeColFilters, valueFilterSets, colByKey, valueForKey]);

    // ─── Sort rows ───
    const sortedRows = useMemo(() => {
        if (!sort) return rows;
        const direction = sort.direction === "asc" ? 1 : -1;
        if (sort.editField) {
            const field = sort.editField;
            const valueFor = (row: powerbi.DataViewTableRow): string => {
                const o = overrideFor(row);
                if (!o) return "";
                return field === "revisionReason" ? reasonDisplay(o.revisionReason) : "";
            };
            return [...rows].sort((a, b) => {
                const av = valueFor(a);
                const bv = valueFor(b);
                if (!av && !bv) return 0;
                if (!av) return 1;
                if (!bv) return -1;
                return av.localeCompare(bv, undefined, { numeric: true, sensitivity: "base" }) * direction;
            });
        }
        const col = sort.column;
        if (!col) return rows;
        return [...rows].sort((a, b) => {
            const av = a[sort.metaIndex];
            const bv = b[sort.metaIndex];
            if (av == null && bv == null) return 0;
            if (av == null) return 1;
            if (bv == null) return -1;
            if (isDateCol(col)) {
                const at = av instanceof Date ? av.getTime() : new Date(String(av)).getTime();
                const bt = bv instanceof Date ? bv.getTime() : new Date(String(bv)).getTime();
                if (isFinite(at) && isFinite(bt) && at !== bt) return (at - bt) * direction;
            }
            if (isNumericCol(col)) {
                const an = typeof av === "number" ? av : Number(av);
                const bn = typeof bv === "number" ? bv : Number(bv);
                if (isFinite(an) && isFinite(bn) && an !== bn) return (an - bn) * direction;
            }
            return String(av).localeCompare(String(bv), undefined, { numeric: true, sensitivity: "base" }) * direction;
        });
    }, [rows, sort, overrideFor, reasonDisplay]);

    const visibleRows = useMemo(() => (anyFilterOn ? sortedRows.filter(isRowVisible) : sortedRows), [sortedRows, isRowVisible, anyFilterOn]);

    // ─── Filter commit + report-page push ───
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
        lastFiltersSeededRef.current = JSON.stringify({});
        onPersistColumnFilters({});
    }, [onPersistColumnFilters]);

    useEffect(() => {
        onApplyReportFilters(buildReportFilters(columnFilters, colByKey, rows));
    }, [columnFilters, colByKey, rows, onApplyReportFilters]);

    // ─── Header menu ───
    const [headerMenu, setHeaderMenu] = useState<{ key: string; column: DataViewMetadataColumn | null; editField: EditField | null; anchor: DOMRect } | null>(null);
    const openHeaderMenu = useCallback(
        (ctx: { key: string; column: DataViewMetadataColumn | null; editField: EditField | null }, anchor: DOMRect) =>
            setHeaderMenu((cur) => (cur && cur.key === ctx.key ? null : { ...ctx, anchor })), []);

    // ─── Windowed rendering ───
    const [renderLimit, setRenderLimit] = useState(INITIAL_RENDER_CHUNK);
    useEffect(() => { setRenderLimit(INITIAL_RENDER_CHUNK); }, [visibleRows.length, sort, columnFilters, editedFilterOn]);
    const renderedRows = useMemo(
        () => (renderLimit >= visibleRows.length ? visibleRows : visibleRows.slice(0, renderLimit)),
        [visibleRows, renderLimit]);
    const handleTableScroll = useCallback((el: HTMLDivElement) => {
        if (el.scrollHeight - el.scrollTop - el.clientHeight > NEAR_BOTTOM_PX) return;
        setRenderLimit((n) => (n >= visibleRows.length ? n : Math.min(n + RENDER_CHUNK_INCREMENT, visibleRows.length)));
    }, [visibleRows.length]);

    // ─── Widths ───
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
    // Default column widths (canvas-estimated) used only when the user has no
    // persisted/drag width for that column. Drag + persisted widths still win.
    const autoWidths = useMemo(() => {
        const columns: AutoSizeCol[] = displayCols.map((spec) => ({
            key: colKey(spec.column),
            header: spec.column.displayName,
            wide: isNumericCol(spec.column) || isDateCol(spec.column),
            valueAt: (i: number) => renderCell(visibleRows[i][spec.metaIndex], spec.column),
        }));
        columns.push({ key: KEY_REASON, header: "Override Reason", wide: false, valueAt: (i) => valueForKey(visibleRows[i], KEY_REASON) });
        return estimateColumnWidths(columns, visibleRows.length, tableFontSize);
    }, [displayCols, visibleRows, tableFontSize, valueForKey]);

    const widthFor = (key: string): number | undefined => widths[key] ?? autoWidths[key];
    const recordMeasuredWidth = useCallback((key: string, width: number) => {
        setMeasuredWidths((prev) => {
            const rounded = Math.round(width);
            if (prev[key] === rounded) return prev;
            return { ...prev, [key]: rounded };
        });
    }, []);

    // ─── Data refresh (poll) ───
    const refresh = useCallback(async () => {
        try {
            const [data, personData, codeData] = await Promise.all([
                revisionsApi.getAll(),
                revisionsApi.getPeople(),
                revisionsApi.getReasonCodes(),
            ]);
            // Bail out when polled data is unchanged so the 20s poll doesn't churn
            // sortedRows/visibleRows and reset the scroll window under the user.
            setOverrides((prev) => (JSON.stringify(prev) === JSON.stringify(data) ? prev : data));
            setPeople((prev) => (JSON.stringify(prev) === JSON.stringify(personData) ? prev : personData));
            setReasonCodes((prev) => (JSON.stringify(prev) === JSON.stringify(codeData) ? prev : codeData));
            setLoaded(true);
            setError(null);
        } catch (e) {
            setError(e instanceof Error ? e.message : "fetch failed");
        }
    }, []);
    useEffect(() => {
        refresh();
        const id = window.setInterval(refresh, POLL_MS);
        return () => window.clearInterval(id);
    }, [refresh]);

    // ─── Override edits (optimistic) ───
    const commitPatch = useCallback(async (revisionKey: string, patch: OverridePatch) => {
        setOverrides((prev) => {
            const cur = prev[revisionKey];
            const base: Override = cur ?? {
                revisionKey,
                ...revisionKeyParts(revisionKey),
                revisionReason: null,
                note: null,
                excludeFlag: false,
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString(),
            };
            return { ...prev, [revisionKey]: { ...base, ...patch, updatedAt: new Date().toISOString() } };
        });
        try {
            // Send denormalized key parts so a first-time INSERT stores them.
            const parts = revisionKeyParts(revisionKey);
            await revisionsApi.upsert(revisionKey, { ...parts, ...patch });
        } catch (e) {
            setError(e instanceof Error ? e.message : "save failed");
            refresh();
        }
    }, [refresh]);

    // ─── People CRUD ───
    const savePerson = useCallback(async (person: { personName: string; displayName?: string | null; email?: string | null; role?: Role | null; active?: boolean; companies?: string[] | string }) => {
        const saved = await revisionsApi.savePerson(person);
        setPeople((prev) => {
            const others = prev.filter((p) => p.personKey !== saved.personKey);
            return [...others, saved].sort((a, b) => Number(b.active) - Number(a.active) || (a.displayName || a.personName).localeCompare(b.displayName || b.personName));
        });
    }, []);
    const updatePerson = useCallback(async (personKey: string, patch: PersonPatch) => {
        const saved = await revisionsApi.updatePerson(personKey, patch);
        setPeople((prev) => prev.map((p) => (p.personKey === saved.personKey ? saved : p)));
    }, []);
    // Deactivate is reached through the panel's Active toggle (updatePerson with
    // { active }), so there is no separate handler for it here.
    const removePerson = useCallback(async (personKey: string) => {
        await revisionsApi.removePerson(personKey);
        setPeople((prev) => prev.filter((p) => p.personKey !== personKey));
    }, []);

    // ─── Reason code CRUD ───
    const upsertReasonCodeLocal = (saved: ReasonCode) =>
        setReasonCodes((prev) => {
            const others = prev.filter((c) => c.codeId !== saved.codeId);
            return [...others, saved].sort((a, b) => Number(b.active) - Number(a.active) || a.sortOrder - b.sortOrder || a.code.localeCompare(b.code));
        });
    const saveReasonCode = useCallback(async (code: { code: string; label?: string | null; sortOrder?: number }) => {
        upsertReasonCodeLocal(await revisionsApi.saveReasonCode(code));
    }, []);
    const updateReasonCode = useCallback(async (codeId: number, patch: ReasonCodePatch) => {
        upsertReasonCodeLocal(await revisionsApi.updateReasonCode(codeId, patch));
    }, []);
    const deactivateReasonCode = useCallback(async (codeId: number) => {
        upsertReasonCodeLocal(await revisionsApi.deactivateReasonCode(codeId));
    }, []);

    // ─── Layout geometry ───
    const insertAt = Math.max(0, Math.min(displayCols.length, Math.floor(editablePosition) - 1));
    const beforeCols = displayCols.slice(0, insertAt);
    const afterCols = displayCols.slice(insertAt);
    const firstColIsNumeric = displayCols.length > 0 && isNumericCol(displayCols[0].column);

    const freezeColCount = Math.max(0, Math.min(Math.floor(freezeColumns) || 0, displayCols.length));
    const frozenCols = displayCols.slice(0, freezeColCount);
    const frozenLeftFor = (key: string): number | undefined => {
        let left = 0;
        for (const spec of frozenCols) {
            const specKey = colKey(spec.column);
            if (specKey === key) return left;
            left += widthFor(specKey) ?? measuredWidths[specKey] ?? 100;
        }
        return undefined;
    };
    const isFrozenBoundary = (key: string): boolean => {
        const last = frozenCols[frozenCols.length - 1];
        return !!last && colKey(last.column) === key;
    };

    const columnTotals = useMemo(() => {
        const totals = new Map<number, number>();
        displayCols.forEach((spec) => {
            if (!isNumericCol(spec.column)) return;
            let sum = 0;
            let any = false;
            for (const row of visibleRows) {
                const v = row[spec.metaIndex];
                if (v == null || v === "") continue;
                const n = typeof v === "number" ? v : Number(v);
                if (!isFinite(n)) continue;
                sum += n; any = true;
            }
            if (any) totals.set(spec.metaIndex, sum);
        });
        return totals;
    }, [displayCols, visibleRows]);

    // ─── Guards ───
    if (!dataView) return <div className="rle-empty">No data.</div>;
    if (revisionKeyIdx === -1) {
        return <div className="rle-empty">Drag the <b>Revision Key</b> field into the Revision Key well to enable editing.</div>;
    }
    if (displayCols.length === 0) return <div className="rle-empty">Drag fields into the Columns well.</div>;

    const EDITABLE_HEADERS = ["Override Reason"];
    const allHeaders = [
        ...beforeCols.map((s) => s.column.displayName),
        ...EDITABLE_HEADERS,
        ...afterCols.map((s) => s.column.displayName),
    ];
    const rowValuesFor = (row: powerbi.DataViewTableRow): string[] => {
        const o = overrideFor(row);
        return [
            ...beforeCols.map((spec) => renderCell(row[spec.metaIndex], spec.column)),
            reasonDisplay(o?.revisionReason),
            ...afterCols.map((spec) => renderCell(row[spec.metaIndex], spec.column)),
        ];
    };
    const openCellMenu = (ev: React.MouseEvent, cellValue: string, row: powerbi.DataViewTableRow, revisionKey: string | null) => {
        ev.preventDefault();
        ev.stopPropagation();
        setCtxMenu({ x: ev.clientX, y: ev.clientY, cellValue, rowValues: rowValuesFor(row), revisionKey });
    };
    const copyWholeTable = () => {
        copyTable(allHeaders, visibleRows.map(rowValuesFor));
    };

    const editableTH = (label: string, key: string, editField: EditField) => (
        <ResizableTH
            label={label}
            width={widthFor(key)}
            onResize={(n) => setColumnWidth(key, n)}
            onResizeEnd={(n) => commitColumnWidth(key, n)}
            sortDirection={sort?.key === key ? sort.direction : undefined}
            onOpenMenu={(rect) => openHeaderMenu({ key, column: null, editField }, rect)}
            filterActive={!!columnFilters[key]}
        />
    );
    const dataTH = (spec: ColSpec, prefix: string) => {
        const k = colKey(spec.column);
        return (
            <ResizableTH
                key={`h-${prefix}-${spec.metaIndex}`}
                label={spec.column.displayName}
                width={widthFor(k)}
                numeric={isNumericCol(spec.column)}
                onResize={(n) => setColumnWidth(k, n)}
                onResizeEnd={(n) => commitColumnWidth(k, n)}
                dragKey={k}
                onColumnDrop={moveColumn}
                sortDirection={sort?.key === k ? sort.direction : undefined}
                onOpenMenu={(rect) => openHeaderMenu({ key: k, column: spec.column, editField: null }, rect)}
                filterActive={!!columnFilters[k]}
                stickyLeft={frozenLeftFor(k)}
                frozenBoundary={isFrozenBoundary(k)}
                onMeasured={(w) => recordMeasuredWidth(k, w)}
            />
        );
    };


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
        <div className="rle-root">
            <div className="rle-header">
                {title.show ? (
                    <div className="rle-title" style={{ fontSize: title.fontSize, color: title.color }}>{title.text}</div>
                ) : <div />}
                <div className="rle-actions">
                    <button
                        type="button"
                        className={`rle-legend-item${editedFilterOn ? " on" : " off"}`}
                        onClick={() => setEditedFilterOn((v) => !v)}
                        title="Show only rows that have been edited"
                        aria-pressed={editedFilterOn}
                    >
                        <span className="rle-legend-swatch rle-legend-edited">{editedFilterOn ? <span className="rle-legend-check">✓</span> : null}</span>
                        Edited
                    </button>
                    {isAdmin && (
                        <button type="button" className="rle-btn" onClick={() => setCodesOpen(true)} title="Maintain revision reason codes">Codes</button>
                    )}
                    {isAdmin && (
                        <button type="button" className="rle-btn" onClick={() => setPeopleOpen(true)} title="Maintain people and roles">People</button>
                    )}
                    <button type="button" className="rle-btn" onClick={() => setAuditOpen(true)} title="View a read-only log of all revision override changes">Audit Log</button>
                    <button type="button" className="rle-btn" onClick={resetUserLayout} title="Reset your saved column order back to the report default.">Reset layout</button>
                    <button type="button" className="rle-btn" onClick={() => refresh()} title="Reload overrides, reason codes, and people from the writeback store. Does not refresh the underlying Power BI data.">⟳ Refresh</button>
                </div>
            </div>
            {error && <div className="rle-error">{error}</div>}
            {peopleOpen && isAdmin && (
                <PeoplePanel people={people} currentUserEmail={currentUserEmail} onClose={() => setPeopleOpen(false)} onSave={savePerson} onUpdate={updatePerson} onRemove={removePerson} />
            )}
            {codesOpen && isAdmin && (
                <ReasonCodesPanel codes={reasonCodes} onClose={() => setCodesOpen(false)} onSave={saveReasonCode} onUpdate={updateReasonCode} onDeactivate={deactivateReasonCode} />
            )}
            {auditOpen && (
                <AuditLogPanel people={people} reasonDisplay={reasonDisplay} onClose={() => setAuditOpen(false)} />
            )}
            <ScrollPane onScroll={handleTableScroll}>
                <table className="rle-table" style={{ fontSize: tableFontSize }}>
                    <colgroup>
                        {beforeCols.map((spec) => {
                            const w = widthFor(colKey(spec.column));
                            return <col key={`cg-b-${spec.metaIndex}`} style={w != null ? { width: w } : undefined} />;
                        })}
                        {[KEY_REASON].map((k) => {
                            const w = widthFor(k);
                            return <col key={`cg-${k}`} style={w != null ? { width: w } : undefined} />;
                        })}
                        {afterCols.map((spec) => {
                            const w = widthFor(colKey(spec.column));
                            return <col key={`cg-a-${spec.metaIndex}`} style={w != null ? { width: w } : undefined} />;
                        })}
                    </colgroup>
                    <thead>
                        <tr>
                            {beforeCols.map((spec) => dataTH(spec, "b"))}
                            {editableTH("Override Reason", KEY_REASON, "revisionReason")}
                            {afterCols.map((spec) => dataTH(spec, "a"))}
                        </tr>
                    </thead>
                    <tbody>
                        {renderedRows.map((row, ri) => {
                            const rkRaw = row[revisionKeyIdx];
                            const revisionKey = rkRaw == null ? "" : String(rkRaw);
                            const o = revisionKey ? overrides[revisionKey] : undefined;
                            const disabled = !revisionKey || !loaded || !perms.canEditKey(revisionKey);
                            const denyTitle = !revisionKey || !loaded ? "" : perms.denyReason(revisionKey);
                            const renderDataTd = (spec: ColSpec, prefix: string) => {
                                const k = colKey(spec.column);
                                const stickyLeft = frozenLeftFor(k);
                                const text = renderCell(row[spec.metaIndex], spec.column);
                                return (
                                    <td
                                        key={`c-${ri}-${prefix}-${spec.metaIndex}`}
                                        className={[
                                            isNumericCol(spec.column) ? "num" : "",
                                            stickyLeft != null ? "rle-frozen-col" : "",
                                            isFrozenBoundary(k) ? "rle-frozen-boundary" : "",
                                        ].filter(Boolean).join(" ")}
                                        style={stickyLeft != null ? { left: stickyLeft } : undefined}
                                        onContextMenu={(ev) => openCellMenu(ev, text, row, revisionKey || null)}
                                    >
                                        {text}
                                    </td>
                                );
                            };
                            const rowClass = o ? "rle-row-edited" : "";
                            return (
                                <tr key={`r-${ri}`} className={rowClass}>
                                    {beforeCols.map((spec) => renderDataTd(spec, "b"))}
                                    <td
                                        title={denyTitle || undefined}
                                        onContextMenu={(ev) => openCellMenu(ev, reasonDisplay(o?.revisionReason), row, revisionKey || null)}
                                    >
                                        <SelectCell
                                            value={o?.revisionReason ?? null}
                                            options={reasonOptions}
                                            disabled={disabled}
                                            searchable
                                            onCommit={(next) => commitPatch(revisionKey, { revisionReason: next })}
                                        />
                                    </td>
                                    {afterCols.map((spec) => renderDataTd(spec, "a"))}
                                </tr>
                            );
                        })}
                    </tbody>
                    <tfoot>
                        <tr className="rle-totals-row">
                            {beforeCols.map((spec, idx) => {
                                const k = colKey(spec.column);
                                const stickyLeft = frozenLeftFor(k);
                                const total = columnTotals.get(spec.metaIndex);
                                const showLabel = idx === 0 && !firstColIsNumeric;
                                return (
                                    <td
                                        key={`tot-b-${spec.metaIndex}`}
                                        className={["rle-totals-cell", isNumericCol(spec.column) ? "num" : "", stickyLeft != null ? "rle-frozen-col" : "", isFrozenBoundary(k) ? "rle-frozen-boundary" : ""].filter(Boolean).join(" ")}
                                        style={stickyLeft != null ? { left: stickyLeft } : undefined}
                                    >
                                        {showLabel ? "Total" : total != null ? fmtNumber(total, spec.column.format) : ""}
                                    </td>
                                );
                            })}
                            <td className="rle-totals-cell" />
                            {afterCols.map((spec, idx) => {
                                const k = colKey(spec.column);
                                const stickyLeft = frozenLeftFor(k);
                                const total = columnTotals.get(spec.metaIndex);
                                const showLabel = beforeCols.length === 0 && idx === 0 && !firstColIsNumeric;
                                return (
                                    <td
                                        key={`tot-a-${spec.metaIndex}`}
                                        className={["rle-totals-cell", isNumericCol(spec.column) ? "num" : "", stickyLeft != null ? "rle-frozen-col" : "", isFrozenBoundary(k) ? "rle-frozen-boundary" : ""].filter(Boolean).join(" ")}
                                        style={stickyLeft != null ? { left: stickyLeft } : undefined}
                                    >
                                        {showLabel ? "Total" : total != null ? fmtNumber(total, spec.column.format) : ""}
                                    </td>
                                );
                            })}
                        </tr>
                    </tfoot>
                </table>
            </ScrollPane>

            <div className="rle-statusbar">
                <span>{rowStatus.text}</span>
                {rowStatus.atCap && (
                    <span className="rle-statusbar-warn" title="Power BI stops sending rows to a custom visual at this limit. Filter the page to bring the population under the cap.">
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
                    canViewHistory={!!ctxMenu.revisionKey}
                    onViewHistory={() => { if (ctxMenu.revisionKey) setHistoryKey(ctxMenu.revisionKey); setCtxMenu(null); }}
                />
            )}
            {historyKey && (
                <HistoryPanel revisionKey={historyKey} loading={historyLoading} error={historyError} entries={history} onClose={() => setHistoryKey(null)} />
            )}
            {headerMenu && (() => {
                const hm = headerMenu;
                const menuLabel = hm.column ? hm.column.displayName
                    : hm.editField === "revisionReason" ? "Override Reason" : "Note";
                const buildSort = (dir: "asc" | "desc"): SortState => {
                    if (hm.editField) return { key: hm.key, direction: dir, metaIndex: -1, column: null, editField: hm.editField };
                    const spec = colByKey.get(hm.key);
                    return { key: hm.key, direction: dir, metaIndex: spec?.metaIndex ?? -1, column: spec?.column ?? null, editField: null };
                };
                return (
                    <HeaderMenu
                        anchor={hm.anchor}
                        label={menuLabel}
                        dataType={colDataType(hm.column, hm.editField)}
                        values={distinctValuesFor(hm.key)}
                        currentFilter={columnFilters[hm.key] ?? null}
                        sortDirection={sort?.key === hm.key ? sort.direction : undefined}
                        hasAnyFilter={activeColFilters.length > 0}
                        onSort={(dir) => setSortForKey(dir, buildSort)}
                        onClearSort={() => setSortForKey(null, buildSort)}
                        onApply={(state) => setColumnFilter(hm.key, state)}
                        onClearAll={clearAllColumnFilters}
                        onClose={() => setHeaderMenu(null)}
                    />
                );
            })()}
        </div>
    );
};
