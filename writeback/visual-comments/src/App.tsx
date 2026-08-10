// Order Line Comments — read-only Orders grid (sales order line grain) with a
// single editable Comment column per line (one comment per line, inline edit).
// Grid mechanics (resize / reorder / sort / PQ filters / frozen columns /
// windowed render / report-filter push) are ported from the DeliveryReliability
// visual; the comment cell reuses the Revision Log Editor's auto-growing note cell.

import * as React from "react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import powerbi from "powerbi-visuals-api";
import { IFilter, BasicFilter } from "powerbi-models";
import DataView = powerbi.DataView;
import DataViewMetadataColumn = powerbi.DataViewMetadataColumn;

import { commentsApi, getActorEmail, LatestMap, Person, Role, setActorEmail } from "./api";
import {
    colKey, isDateCol, isNumericCol, renderCell, copyTable,
    PersistedSort, KEY_COMMENT,
} from "./util";
import {
    ColumnFilters, ColumnFilterState, FilterDataType, FilterColSpec, buildReportFilters,
    matchesTextCond, matchesNumCond, matchesDateCond, filterTargetFor,
} from "./filters";
import { AutoSizeCol, estimateColumnWidths } from "./autosize";
import { ScrollPane } from "./grid/ScrollPane";
import { ResizableTH } from "./grid/ResizableTH";
import { HeaderMenu } from "./grid/HeaderMenu";
import { CellContextMenu } from "./grid/ContextMenu";
import { NotesCell } from "./cells/NotesCell";
import { buildPermissions, companyOfKey, normalizeCompany } from "./permissions";
import { PeoplePanel } from "./people/PeoplePanel";
import { CommentAuditPanel } from "./panels/CommentAuditPanel";

const POLL_MS = 60000;
const INITIAL_RENDER_CHUNK = 200;
// Must match capabilities.json dataViewMappings[].table.rows.dataReductionAlgorithm.top.count.
const DATA_REDUCTION_CAP = 30000;
const RENDER_CHUNK_INCREMENT = 200;
const NEAR_BOTTOM_PX = 800;

const COMMENT_HEADER = "Comment";

interface AppProps {
    dataView: DataView | null;
    /**
     * The viewer's email, resolved by visual.tsx from the separate identity dataView.
     * Deliberately NOT read off `dataView`'s rows — see identity.ts for why that query had to
     * be split out. Null means the Current User field well is empty.
     */
    currentUserEmail: string | null;
    title: { show: boolean; text: string; fontSize: number; color: string };
    tableFontSize: number;
    commentsPosition: number;
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

interface ColSpec {
    metaIndex: number;
    column: DataViewMetadataColumn;
    projectionIndex: number;
}

type CommentField = "comment";

interface SortState {
    key: string;
    direction: "asc" | "desc";
    metaIndex: number;
    column: DataViewMetadataColumn | null;
    commentField: CommentField | null;
}

function projectionIndex(c: DataViewMetadataColumn, fallback: number): number {
    if (typeof c.index === "number") return c.index;
    const extended = c as unknown as { rolesIndex?: Record<string, number>; rolesIndexes?: Record<string, number> };
    if (typeof extended.rolesIndex?.["columns"] === "number") return extended.rolesIndex["columns"];
    if (typeof extended.rolesIndexes?.["columns"] === "number") return extended.rolesIndexes["columns"];
    return fallback;
}

function colDataType(column: DataViewMetadataColumn | null, commentField: CommentField | null): FilterDataType {
    if (commentField) return "text";
    if (!column) return "text";
    if (isDateCol(column)) return "date";
    if (isNumericCol(column)) return "number";
    return "text";
}

export const App: React.FC<AppProps> = ({
    dataView, currentUserEmail, title, tableFontSize, commentsPosition, freezeColumns,
    initialWidths, initialColumnOrder, initialSort, initialColumnFilters,
    onPersistWidths, onPersistColumnOrder, onPersistSort, onPersistColumnFilters, onApplyReportFilters,
}) => {
    const table = dataView?.table;
    const cols = table?.columns ?? [];
    const rows = table?.rows ?? [];

    // Resolve field-well roles. currentUser is NOT among them — it rides its own dataView so it
    // never widens this query (identity.ts).
    const { rawDisplayCols, orderLineIdx, companyListIdx, companyListIsMeasure } = useMemo(() => {
        let orderLineIdx = -1;
        let companyListIdx = -1;
        let companyListIsMeasure = false;
        const list: ColSpec[] = [];
        cols.forEach((c, i) => {
            const roles = c.roles || {};
            if (roles["orderLineId"] && orderLineIdx === -1) orderLineIdx = i;
            if (roles["companyList"] && companyListIdx === -1) { companyListIdx = i; companyListIsMeasure = !!c.isMeasure; }
            if (roles["columns"]) {
                list.push({ metaIndex: i, column: c, projectionIndex: projectionIndex(c, i) });
            }
        });
        list.sort((a, b) => (a.projectionIndex !== b.projectionIndex ? a.projectionIndex - b.projectionIndex : a.metaIndex - b.metaIndex));
        return { rawDisplayCols: list, orderLineIdx, companyListIdx, companyListIsMeasure };
    }, [cols]);

    useEffect(() => { setActorEmail(currentUserEmail); }, [currentUserEmail]);

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
                commentsApi.deleteLayout().catch(() => { /* best effort */ });
            }
        }
    }, [initialColumnOrder]);

    useEffect(() => {
        if (!currentUserEmail) return;
        if (userLayoutLoadedForRef.current === currentUserEmail) return;
        userLayoutLoadedForRef.current = currentUserEmail;
        let cancelled = false;
        commentsApi.getLayout()
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
        commentsApi.deleteLayout().catch(() => { /* best effort */ });
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
            if (fromIdx === -1 || toIdx === -1 || fromIdx === toIdx) return current;
            const next = [...current];
            const [moved] = next.splice(fromIdx, 1);
            next.splice(toIdx, 0, moved);
            onPersistColumnOrder(next);
            userLayoutAppliedRef.current = true;
            commentsApi.saveLayout(next).catch(() => { /* best effort */ });
            lastOrderSeededRef.current = JSON.stringify(next);
            return next;
        });
    }, [displayCols, onPersistColumnOrder]);

    const colByKey = useMemo(
        () => new Map<string, ColSpec>(rawDisplayCols.map((s) => [colKey(s.column), s])),
        [rawDisplayCols],
    );
    const filterColByKey = useMemo<Map<string, FilterColSpec>>(
        () => new Map(rawDisplayCols.map((s) => [colKey(s.column), { metaIndex: s.metaIndex, column: s.column }])),
        [rawDisplayCols],
    );

    // ─── Comments data ───
    const [latest, setLatest] = useState<LatestMap>({});
    const [people, setPeople] = useState<Person[]>([]);
    const [error, setError] = useState<string | null>(null);
    const [loaded, setLoaded] = useState(false);

    const refresh = useCallback(async () => {
        try {
            const [latestData, peopleData] = await Promise.all([
                commentsApi.latest(),
                commentsApi.getPeople(),
            ]);
            setLatest((prev) => (JSON.stringify(prev) === JSON.stringify(latestData) ? prev : latestData));
            setPeople((prev) => (JSON.stringify(prev) === JSON.stringify(peopleData) ? prev : peopleData));
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

    // The active listed person matching the viewer (if any).
    const currentPerson = useMemo<Person | null>(() => {
        if (!currentUserEmail) return null;
        return people.find((p) => p.active && p.email && p.email.toLowerCase() === currentUserEmail) ?? null;
    }, [people, currentUserEmail]);
    const isAdmin = currentPerson?.role === "admin";
    // Commenting is company-gated (changed 2026-07-28). A viewer may edit a line's comment
    // only if they are an admin, or the People list assigns them that line's Order Company.
    // The company is the first segment of the Order Line ID, so no extra field binding is
    // needed. This only disables the cell — the Worker returns 403 regardless.
    const perms = useMemo(() => buildPermissions(people, currentUserEmail), [people, currentUserEmail]);

    // Companies offered in the People panel's picker. The Company List field well wins when
    // bound; otherwise read the company off the Order Line ID ("00010,74,CM,4.000"), which is
    // always bound and costs nothing — no extra projection, so no risk of widening this query.
    //
    // A MEASURE bound here is the only binding that survives page filters. Anything else is a
    // group-by column, so a page filtered to one company yields a one-entry picker and an admin
    // cannot assign anyone to the companies that are filtered out. A measure like
    // [Company List (All)] = CONCATENATEX over an unrelated Companies table is evaluated per
    // group and carries the whole list on every row, so one non-empty value is all we read.
    const availableCompanies = useMemo(() => {
        const set = new Set<string>();
        const idx = companyListIdx !== -1 ? companyListIdx : orderLineIdx;
        if (idx === -1) return [];
        if (companyListIdx !== -1 && companyListIsMeasure) {
            for (const row of rows) {
                const raw = row[idx];
                if (raw === null || raw === undefined) continue;
                const text = String(raw).trim();
                if (!text) continue;
                for (const part of text.split(/[,;|]/)) {
                    const code = normalizeCompany(part);
                    if (code) set.add(code);
                }
                if (set.size) break;
            }
            return Array.from(set).sort();
        }
        const direct = companyListIdx !== -1;
        for (const row of rows) {
            const raw = row[idx];
            if (raw === null || raw === undefined) continue;
            const code = direct ? normalizeCompany(String(raw)) : companyOfKey(String(raw));
            if (code) set.add(code);
        }
        return Array.from(set).sort();
    }, [rows, companyListIdx, companyListIsMeasure, orderLineIdx]);

    const orderLineOf = useCallback(
        (row: powerbi.DataViewTableRow): string => (orderLineIdx === -1 || row[orderLineIdx] == null ? "" : String(row[orderLineIdx])),
        [orderLineIdx],
    );
    // The single comment body for a line (empty string when none).
    const commentBody = useCallback((olid: string): string => latest[olid]?.body ?? "", [latest]);

    // ─── Row selection → report cross-filter ───────────────────────────────
    // Track selection by the stable Order Line ID string (survives sort / column
    // filter / data refresh). Clicking a row pushes a BasicFilter("In") on the
    // Order Line ID model column so every standard visual on the page filters;
    // the visual's own filter does not reduce this grid, so it stays full.
    const [selectedOlids, setSelectedOlids] = useState<Set<string>>(new Set());

    // The (table, column) target for the Order Line ID field, or null if it can't
    // be resolved (then row-click cross-filtering is disabled, comments still work).
    const orderLineTarget = useMemo(
        () => (orderLineIdx === -1 ? null : filterTargetFor(cols[orderLineIdx])),
        [cols, orderLineIdx],
    );

    const onRowClick = useCallback((row: powerbi.DataViewTableRow, ev: React.MouseEvent) => {
        if (!orderLineTarget) return;
        const olid = orderLineOf(row);
        if (!olid) return;
        const multi = ev.ctrlKey || ev.metaKey;
        setSelectedOlids((prev) => {
            let next: Set<string>;
            if (multi) {
                next = new Set(prev);
                if (next.has(olid)) next.delete(olid); else next.add(olid);
            } else {
                next = prev.size === 1 && prev.has(olid) ? new Set() : new Set([olid]);
            }
            return next;
        });
    }, [orderLineTarget, orderLineOf]);

    const clearSelection = useCallback(() => setSelectedOlids(new Set()), []);

    // The row-selection filter, merged with the column filters below into a single
    // push on the canonical general.filter property (the same path slicers use).
    const selectionReportFilter = useMemo<IFilter[]>(
        () => (orderLineTarget && selectedOlids.size
            ? [new BasicFilter(orderLineTarget, "In", Array.from(selectedOlids)).toJSON()]
            : []),
        [orderLineTarget, selectedOlids],
    );

    // Inline save (optimistic). Empty body clears the comment. The 60s poll
    // reconciles; NotesCell keeps the draft while focused so a poll can't clobber it.
    const saveComment = useCallback(async (olid: string, next: string | null) => {
        if (!olid) return;
        const body = next && next.trim() ? next : null;
        setLatest((prev) => {
            const map = { ...prev };
            if (!body) {
                delete map[olid];
            } else {
                const existing = map[olid];
                map[olid] = existing
                    ? { ...existing, body, actorEmail: getActorEmail(), updatedAt: new Date().toISOString() }
                    : { id: 0, body, actorEmail: getActorEmail(), createdAt: new Date().toISOString(), updatedAt: null };
            }
            return map;
        });
        try {
            await commentsApi.saveLineComment(olid, body ?? "");
        } catch (e) {
            setError(e instanceof Error ? e.message : "save failed");
            refresh();
        }
    }, [refresh]);

    // ─── Sorting ───
    const commentFieldForKey = (key: string): CommentField | null =>
        key === KEY_COMMENT ? "comment" : null;

    const resolveSort = useCallback((s: PersistedSort | null): SortState | null => {
        if (!s) return null;
        const cf = commentFieldForKey(s.key);
        if (cf) return { key: s.key, direction: s.direction, metaIndex: -1, column: null, commentField: cf };
        const spec = rawDisplayCols.find((c) => colKey(c.column) === s.key);
        if (!spec) return null;
        return { key: s.key, direction: s.direction, metaIndex: spec.metaIndex, column: spec.column, commentField: null };
    }, [rawDisplayCols]);

    const [sort, setSort] = useState<SortState | null>(() => resolveSort(initialSort));
    const lastSortSeededRef = useRef<string>(JSON.stringify(initialSort ?? null));
    useEffect(() => {
        const incoming = JSON.stringify(initialSort ?? null);
        if (incoming === lastSortSeededRef.current) return;
        lastSortSeededRef.current = incoming;
        setSort(resolveSort(initialSort));
    }, [initialSort, resolveSort]);
    useEffect(() => {
        setSort((prev) => {
            if (!prev || prev.commentField) return prev;
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
        },
        [onPersistSort],
    );

    const sortedRows = useMemo(() => {
        if (!sort) return rows;
        const direction = sort.direction === "asc" ? 1 : -1;
        if (sort.commentField === "comment") {
            return [...rows].sort((a, b) => {
                const av = commentBody(orderLineOf(a));
                const bv = commentBody(orderLineOf(b));
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
    }, [rows, sort, commentBody, orderLineOf]);

    // ─── Column filters ───
    const [columnFilters, setColumnFilters] = useState<ColumnFilters>(initialColumnFilters);
    const lastFiltersSeededRef = useRef<string>(JSON.stringify(initialColumnFilters));
    useEffect(() => {
        const incoming = JSON.stringify(initialColumnFilters);
        if (incoming !== lastFiltersSeededRef.current) {
            lastFiltersSeededRef.current = incoming;
            setColumnFilters(initialColumnFilters);
        }
    }, [initialColumnFilters]);

    const valueForKey = useCallback(
        (row: powerbi.DataViewTableRow, key: string, spec?: ColSpec): string => {
            if (key === KEY_COMMENT) return commentBody(orderLineOf(row));
            const s = spec ?? colByKey.get(key);
            return s ? renderCell(row[s.metaIndex], s.column) : "";
        },
        [colByKey, commentBody, orderLineOf],
    );

    const distinctValuesFor = useCallback(
        (key: string): string[] => {
            const set = new Set<string>();
            const spec = colByKey.get(key);
            for (const row of rows) set.add(valueForKey(row, key, spec));
            return Array.from(set).sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: "base" }));
        },
        [rows, valueForKey, colByKey],
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
        (row: powerbi.DataViewTableRow): boolean => {
            for (const [key, f] of activeColFilters) {
                const isComment = key === KEY_COMMENT;
                const spec = isComment ? undefined : colByKey.get(key);
                if (!isComment && !spec) continue;
                const display = valueForKey(row, key, spec);
                if (f.mode === "values") {
                    const set = valueFilterSets.get(key);
                    if (set && !set.has(display)) return false;
                } else {
                    const dt: FilterDataType = isComment ? "text" : colDataType(spec!.column, null);
                    const raw = isComment ? display : row[spec!.metaIndex];
                    const ok = dt === "date" ? matchesDateCond(raw, f.op, f.value, f.valueTo)
                        : dt === "number" ? matchesNumCond(raw, f.op, f.value, f.valueTo)
                        : matchesTextCond(display, f.op, f.value);
                    if (!ok) return false;
                }
            }
            return true;
        },
        [activeColFilters, valueFilterSets, colByKey, valueForKey],
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

    useEffect(() => {
        onApplyReportFilters([...buildReportFilters(columnFilters, filterColByKey, rows), ...selectionReportFilter]);
    }, [columnFilters, filterColByKey, rows, selectionReportFilter, onApplyReportFilters]);

    // ─── Header menu ───
    const [headerMenu, setHeaderMenu] = useState<
        { key: string; column: DataViewMetadataColumn | null; commentField: CommentField | null; anchor: DOMRect } | null
    >(null);
    const openHeaderMenu = useCallback(
        (ctx: { key: string; column: DataViewMetadataColumn | null; commentField: CommentField | null }, anchor: DOMRect) =>
            setHeaderMenu((cur) => (cur && cur.key === ctx.key ? null : { ...ctx, anchor })),
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

    // Default column widths (canvas-estimated) used only when the user has no
    // persisted/drag width for that column. Drag + persisted widths still win.
    const autoWidths = useMemo(() => {
        const columns: AutoSizeCol[] = displayCols.map((spec) => ({
            key: colKey(spec.column),
            header: spec.column.displayName,
            wide: isNumericCol(spec.column) || isDateCol(spec.column),
            valueAt: (i: number) => renderCell(visibleRows[i][spec.metaIndex], spec.column),
        }));
        columns.push({ key: KEY_COMMENT, header: COMMENT_HEADER, wide: false, valueAt: (i) => commentBody(orderLineOf(visibleRows[i])) });
        return estimateColumnWidths(columns, visibleRows.length, tableFontSize);
    }, [displayCols, visibleRows, tableFontSize, commentBody, orderLineOf]);

    const widthFor = (key: string): number | undefined => widths[key] ?? autoWidths[key];
    const recordMeasuredWidth = useCallback((key: string, width: number) => {
        setMeasuredWidths((prev) => {
            const rounded = Math.round(width);
            return prev[key] === rounded ? prev : { ...prev, [key]: rounded };
        });
    }, []);

    // ─── Assemble the visible column list (data + injected comment column) ───
    const insertAt = Math.max(0, Math.min(displayCols.length, Math.floor(commentsPosition) - 1));
    const beforeCols = displayCols.slice(0, insertAt);
    const afterCols = displayCols.slice(insertAt);

    // Left→right key order used for frozen-offset math + copy.
    const orderedKeys = useMemo(
        () => [
            ...beforeCols.map((s) => colKey(s.column)),
            KEY_COMMENT,
            ...afterCols.map((s) => colKey(s.column)),
        ],
        [beforeCols, afterCols],
    );
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

    const allHeaders = useMemo(
        () => [
            ...beforeCols.map((s) => s.column.displayName),
            COMMENT_HEADER,
            ...afterCols.map((s) => s.column.displayName),
        ],
        [beforeCols, afterCols],
    );
    const rowValuesFor = useCallback((row: powerbi.DataViewTableRow): string[] => {
        const olid = orderLineOf(row);
        return [
            ...beforeCols.map((spec) => renderCell(row[spec.metaIndex], spec.column)),
            commentBody(olid),
            ...afterCols.map((spec) => renderCell(row[spec.metaIndex], spec.column)),
        ];
    }, [beforeCols, afterCols, orderLineOf, commentBody]);

    // ─── Column totals (numeric data columns) ───
    const columnTotals = useMemo(() => {
        const totals = new Map<number, number>();
        displayCols.forEach((spec) => {
            if (!isNumericCol(spec.column)) return;
            let sum = 0; let any = false;
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
    const firstColIsNumeric = beforeCols.length > 0 && isNumericCol(beforeCols[0].column);

    // ─── Panels / menus state ───
    const [peopleOpen, setPeopleOpen] = useState(false);
    const [auditOpen, setAuditOpen] = useState(false);
    const [ctxMenu, setCtxMenu] = useState<{ x: number; y: number; cellValue: string; rowValues: string[] } | null>(null);

    const openCellMenu = (ev: React.MouseEvent, cellValue: string, row: powerbi.DataViewTableRow) => {
        ev.preventDefault();
        ev.stopPropagation();
        setCtxMenu({ x: ev.clientX, y: ev.clientY, cellValue, rowValues: rowValuesFor(row) });
    };
    const copyWholeTable = () => {
        copyTable(allHeaders, visibleRows.map(rowValuesFor));
    };

    // ─── People CRUD ───
    const savePerson = useCallback(async (person: { personName: string; displayName?: string | null; email?: string | null; role?: Role | null; active?: boolean; companies?: string[] | string }) => {
        const saved = await commentsApi.savePerson(person);
        setPeople((prev) => {
            const others = prev.filter((p) => p.personKey !== saved.personKey);
            return [...others, saved].sort((a, b) => Number(b.active) - Number(a.active) || (a.displayName || a.personName).localeCompare(b.displayName || b.personName));
        });
    }, []);
    const updatePerson = useCallback(async (personKey: string, patch: { displayName?: string | null; email?: string | null; role?: Role | null; active?: boolean; companies?: string[] | string }) => {
        const saved = await commentsApi.updatePerson(personKey, patch);
        setPeople((prev) => prev.map((p) => (p.personKey === saved.personKey ? saved : p)));
    }, []);
    const deactivatePerson = useCallback(async (personKey: string) => {
        const saved = await commentsApi.deactivatePerson(personKey);
        setPeople((prev) => prev.map((p) => (p.personKey === saved.personKey ? saved : p)));
    }, []);
    const removePerson = useCallback(async (personKey: string) => {
        await commentsApi.removePerson(personKey);
        setPeople((prev) => prev.filter((p) => p.personKey !== personKey));
    }, []);

    // ─── Empty states ───
    if (!dataView) return <div className="olc-empty">No data.</div>;
    if (orderLineIdx === -1) {
        return <div className="olc-empty">Drag the <b>Order Line ID</b> field into the Order Line ID well to enable comments.</div>;
    }
    if (displayCols.length === 0) return <div className="olc-empty">Drag fields into the Columns well.</div>;

    const renderDataTd = (row: powerbi.DataViewTableRow, ri: number, spec: ColSpec, prefix: string) => {
        const k = colKey(spec.column);
        const stickyLeft = frozenLeftFor(k);
        const text = renderCell(row[spec.metaIndex], spec.column);
        return (
            <td
                key={`c-${ri}-${prefix}-${spec.metaIndex}`}
                className={[isNumericCol(spec.column) ? "num" : "", stickyLeft != null ? "olc-frozen-col" : "", isFrozenBoundary(k) ? "olc-frozen-boundary" : ""].filter(Boolean).join(" ")}
                style={stickyLeft != null ? { left: stickyLeft } : undefined}
                onContextMenu={(ev) => openCellMenu(ev, text, row)}
            >
                {text}
            </td>
        );
    };

    const dataTh = (spec: ColSpec, prefix: string) => {
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
                onOpenMenu={(rect) => openHeaderMenu({ key: k, column: spec.column, commentField: null }, rect)}
                filterActive={!!columnFilters[k]}
                stickyLeft={frozenLeftFor(k)}
                frozenBoundary={isFrozenBoundary(k)}
                onMeasured={(w) => recordMeasuredWidth(k, w)}
            />
        );
    };

    const commentLeftHead = frozenLeftFor(KEY_COMMENT);


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
                    {selectedOlids.size > 0 && (
                        <button
                            type="button"
                            className="olc-btn olc-filter-pill"
                            onClick={clearSelection}
                            title={orderLineTarget ? `Cross-filtering ${orderLineTarget.table}[${orderLineTarget.column}] — click to clear` : "Click to clear"}
                        >
                            Filtering {selectedOlids.size} line{selectedOlids.size === 1 ? "" : "s"} ✕
                        </button>
                    )}
                    <button type="button" className="olc-btn" onClick={() => setPeopleOpen(true)} title="View / manage approved editors and the companies they may edit">People</button>
                    {perms.isAdmin && (
                        <button type="button" className="olc-btn" onClick={() => setAuditOpen(true)} title="Every comment added, edited or deleted (admins only)">Audit log</button>
                    )}
                    <button type="button" className="olc-btn" onClick={resetUserLayout} title="Reset your saved column order to the report default">Reset layout</button>
                    <button type="button" className="olc-btn" onClick={() => refresh()} title="Reload comments now">⟳ Refresh comments</button>
                </div>
            </div>
            {error && <div className="olc-error">{error}</div>}

            <ScrollPane onScroll={handleTableScroll}>
                <table className="olc-table" style={{ fontSize: tableFontSize }}>
                    <colgroup>
                        {beforeCols.map((spec) => { const w = widthFor(colKey(spec.column)); return <col key={`cg-b-${spec.metaIndex}`} style={w != null ? { width: w } : undefined} />; })}
                        {(() => { const w = widthFor(KEY_COMMENT); return <col key="cg-comment" style={w != null ? { width: w } : undefined} />; })()}
                        {afterCols.map((spec) => { const w = widthFor(colKey(spec.column)); return <col key={`cg-a-${spec.metaIndex}`} style={w != null ? { width: w } : undefined} />; })}
                    </colgroup>
                    <thead>
                        <tr>
                            {beforeCols.map((spec) => dataTh(spec, "b"))}
                            <ResizableTH
                                label={COMMENT_HEADER}
                                width={widthFor(KEY_COMMENT)}
                                onResize={(n) => setColumnWidth(KEY_COMMENT, n)}
                                onResizeEnd={(n) => commitColumnWidth(KEY_COMMENT, n)}
                                sortDirection={sort?.key === KEY_COMMENT ? sort.direction : undefined}
                                onOpenMenu={(rect) => openHeaderMenu({ key: KEY_COMMENT, column: null, commentField: "comment" }, rect)}
                                filterActive={!!columnFilters[KEY_COMMENT]}
                                stickyLeft={commentLeftHead}
                                frozenBoundary={isFrozenBoundary(KEY_COMMENT)}
                                onMeasured={(w) => recordMeasuredWidth(KEY_COMMENT, w)}
                            />
                            {afterCols.map((spec) => dataTh(spec, "a"))}
                        </tr>
                    </thead>
                    <tbody>
                        {renderedRows.map((row, ri) => {
                            const olid = orderLineOf(row);
                            const body = commentBody(olid);
                            const commentLeft = frozenLeftFor(KEY_COMMENT);
                            const isSelected = !!olid && selectedOlids.has(olid);
                            return (
                                <tr
                                    key={`r-${ri}`}
                                    className={isSelected ? "olc-row-selected" : undefined}
                                    onClick={(ev) => onRowClick(row, ev)}
                                >
                                    {beforeCols.map((spec) => renderDataTd(row, ri, spec, "b"))}
                                    <td
                                        className={["olc-cell-comment-edit", commentLeft != null ? "olc-frozen-col" : "", isFrozenBoundary(KEY_COMMENT) ? "olc-frozen-boundary" : ""].filter(Boolean).join(" ")}
                                        style={commentLeft != null ? { left: commentLeft } : undefined}
                                        onContextMenu={(ev) => openCellMenu(ev, body, row)}
                                        onClick={(ev) => ev.stopPropagation()}
                                    >
                                        <NotesCell
                                            value={latest[olid]?.body ?? null}
                                            disabled={!olid || !loaded || !perms.canEditKey(olid)}
                                            disabledTitle={!olid || !loaded ? undefined : perms.denyReason(olid)}
                                            onCommit={(next) => saveComment(olid, next)}
                                        />
                                    </td>
                                    {afterCols.map((spec) => renderDataTd(row, ri, spec, "a"))}
                                </tr>
                            );
                        })}
                    </tbody>
                    <tfoot>
                        <tr className="olc-totals-row">
                            {beforeCols.map((spec, idx) => {
                                const k = colKey(spec.column);
                                const stickyLeft = frozenLeftFor(k);
                                const total = columnTotals.get(spec.metaIndex);
                                const showLabel = idx === 0 && !firstColIsNumeric;
                                return (
                                    <td key={`tot-b-${spec.metaIndex}`}
                                        className={["olc-totals-cell", isNumericCol(spec.column) ? "num" : "", stickyLeft != null ? "olc-frozen-col" : "", isFrozenBoundary(k) ? "olc-frozen-boundary" : ""].filter(Boolean).join(" ")}
                                        style={stickyLeft != null ? { left: stickyLeft } : undefined}>
                                        {showLabel ? "Total" : total != null ? total.toLocaleString(undefined, { maximumFractionDigits: 2 }) : ""}
                                    </td>
                                );
                            })}
                            <td className={["olc-totals-cell", frozenLeftFor(KEY_COMMENT) != null ? "olc-frozen-col" : ""].filter(Boolean).join(" ")}
                                style={frozenLeftFor(KEY_COMMENT) != null ? { left: frozenLeftFor(KEY_COMMENT) } : undefined}>
                                {beforeCols.length === 0 && !firstColIsNumeric ? "Total" : ""}
                            </td>
                            {afterCols.map((spec) => {
                                const total = columnTotals.get(spec.metaIndex);
                                return (
                                    <td key={`tot-a-${spec.metaIndex}`} className={["olc-totals-cell", isNumericCol(spec.column) ? "num" : ""].filter(Boolean).join(" ")}>
                                        {total != null ? total.toLocaleString(undefined, { maximumFractionDigits: 2 }) : ""}
                                    </td>
                                );
                            })}
                        </tr>
                    </tfoot>
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
                const menuLabel = hm.column ? hm.column.displayName : COMMENT_HEADER;
                const buildSort = (dir: "asc" | "desc"): SortState => {
                    if (hm.commentField) return { key: hm.key, direction: dir, metaIndex: -1, column: null, commentField: hm.commentField };
                    const spec = colByKey.get(hm.key);
                    return { key: hm.key, direction: dir, metaIndex: spec?.metaIndex ?? -1, column: spec?.column ?? null, commentField: null };
                };
                return (
                    <HeaderMenu
                        anchor={hm.anchor}
                        label={menuLabel}
                        dataType={colDataType(hm.column, hm.commentField)}
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

            {auditOpen && perms.isAdmin && (
                <CommentAuditPanel people={people} onClose={() => setAuditOpen(false)} />
            )}

            {peopleOpen && (
                <PeoplePanel
                    people={people}
                    isAdmin={perms.isAdmin}
                    availableCompanies={availableCompanies}
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
