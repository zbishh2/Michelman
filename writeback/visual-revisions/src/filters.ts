// Power Query-style per-column filters. A column carries either a value
// checklist (exact display strings to keep) or a typed condition
// (contains / >= / between ...). Filters hide rows locally AND, for real model
// columns, are pushed to the report page via host.applyJsonFilter so sibling
// visuals respond. The editable override columns filter locally only.
//
// Ported from the DeliveryReliability visual; the report-filter push carries the
// same signature-dedupe guard that broke DR's applyJsonFilter feedback loop.

import powerbi from "powerbi-visuals-api";
import { BasicFilter, AdvancedFilter, IFilter, IFilterColumnTarget, IAdvancedFilterCondition } from "powerbi-models";
import DataViewMetadataColumn = powerbi.DataViewMetadataColumn;
import { isDateCol, isNumericCol, renderCell } from "./format";
import { ColSpec, EditField, PersistedSort } from "./types";

export type FilterDataType = "text" | "number" | "date";

export type ColumnFilterState =
    | { mode: "values"; selected: string[] }
    | { mode: "condition"; op: string; value: string; valueTo?: string }
    | null;

export type ColumnFilters = Record<string, ColumnFilterState>;

export const TEXT_OPS: ReadonlyArray<readonly [string, string]> = [
    ["contains", "Contains"], ["notContains", "Does not contain"],
    ["equals", "Equals"], ["notEquals", "Does not equal"],
    ["beginsWith", "Begins with"], ["endsWith", "Ends with"],
    ["isEmpty", "Is empty"], ["isNotEmpty", "Is not empty"],
];
export const NUMBER_OPS: ReadonlyArray<readonly [string, string]> = [
    ["equals", "="], ["notEquals", "≠"],
    ["greaterThan", ">"], ["greaterThanOrEqual", "≥"],
    ["lessThan", "<"], ["lessThanOrEqual", "≤"],
    ["between", "Between"], ["isEmpty", "Is empty"], ["isNotEmpty", "Is not empty"],
];
export const DATE_OPS: ReadonlyArray<readonly [string, string]> = [
    ["equals", "On"], ["notEquals", "Not on"],
    ["after", "After"], ["afterOrEqual", "On or after"],
    ["before", "Before"], ["beforeOrEqual", "On or before"],
    ["between", "Between"], ["isEmpty", "Is empty"], ["isNotEmpty", "Is not empty"],
];

export function opsForType(dt: FilterDataType): ReadonlyArray<readonly [string, string]> {
    return dt === "number" ? NUMBER_OPS : dt === "date" ? DATE_OPS : TEXT_OPS;
}
export function opNeedsValue(op: string): boolean {
    return op !== "isEmpty" && op !== "isNotEmpty";
}
export function opNeedsTwoValues(op: string): boolean {
    return op === "between";
}

function dayTimeFromInput(s: string): number | null {
    const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s.trim());
    if (!m) return null;
    return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3])).getTime();
}
function dateOnlyTime(v: unknown): number | null {
    if (v == null || v === "") return null;
    const d = v instanceof Date ? v : new Date(String(v));
    if (isNaN(d.getTime())) return null;
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

export function matchesTextCond(display: string, op: string, value: string): boolean {
    const d = display.toLowerCase();
    const v = (value ?? "").toLowerCase();
    switch (op) {
        case "contains": return d.includes(v);
        case "notContains": return !d.includes(v);
        case "equals": return d === v;
        case "notEquals": return d !== v;
        case "beginsWith": return d.startsWith(v);
        case "endsWith": return d.endsWith(v);
        case "isEmpty": return display === "";
        case "isNotEmpty": return display !== "";
        default: return true;
    }
}
export function matchesNumCond(raw: unknown, op: string, value: string, valueTo?: string): boolean {
    const empty = raw == null || raw === "";
    if (op === "isEmpty") return empty;
    if (op === "isNotEmpty") return !empty;
    const n = typeof raw === "number" ? raw : Number(raw);
    if (!isFinite(n)) return false;
    const a = Number(value);
    if (!isFinite(a)) return true;
    switch (op) {
        case "equals": return n === a;
        case "notEquals": return n !== a;
        case "greaterThan": return n > a;
        case "greaterThanOrEqual": return n >= a;
        case "lessThan": return n < a;
        case "lessThanOrEqual": return n <= a;
        case "between": { const b = Number(valueTo); return isFinite(b) ? n >= a && n <= b : n >= a; }
        default: return true;
    }
}
export function matchesDateCond(raw: unknown, op: string, value: string, valueTo?: string): boolean {
    const t = dateOnlyTime(raw);
    if (op === "isEmpty") return t == null;
    if (op === "isNotEmpty") return t != null;
    if (t == null) return false;
    const a = dayTimeFromInput(value);
    if (a == null) return true;
    switch (op) {
        case "equals": return t === a;
        case "notEquals": return t !== a;
        case "after": return t > a;
        case "afterOrEqual": return t >= a;
        case "before": return t < a;
        case "beforeOrEqual": return t <= a;
        case "between": { const b = valueTo ? dayTimeFromInput(valueTo) : null; return b != null ? t >= a && t <= b : t >= a; }
        default: return true;
    }
}

export function colDataType(column: DataViewMetadataColumn | null, editField: EditField | null): FilterDataType {
    // The editable override columns (reason, note, exclude) are all treated as
    // free-form text for filtering purposes.
    if (editField) return "text";
    if (!column) return "text";
    if (isDateCol(column)) return "date";
    if (isNumericCol(column)) return "number";
    return "text";
}

// ─── Persisted-property parsers (report objects.general) ────────────────────

export function parseWidths(json: unknown): Record<string, number> {
    if (typeof json !== "string" || !json) return {};
    try {
        const parsed = JSON.parse(json);
        if (!parsed || typeof parsed !== "object") return {};
        const out: Record<string, number> = {};
        for (const [k, v] of Object.entries(parsed)) {
            if (typeof v === "number" && isFinite(v)) out[k] = v;
        }
        return out;
    } catch { return {}; }
}

export function parseColumnOrder(json: unknown): string[] {
    if (typeof json !== "string" || !json) return [];
    try {
        const parsed = JSON.parse(json);
        if (!Array.isArray(parsed)) return [];
        return parsed.filter((v): v is string => typeof v === "string" && v.length > 0);
    } catch { return []; }
}

export function parseSortState(json: unknown): PersistedSort | null {
    if (typeof json !== "string" || !json) return null;
    try {
        const parsed = JSON.parse(json);
        if (!parsed || typeof parsed !== "object") return null;
        const key = (parsed as { key?: unknown }).key;
        const direction = (parsed as { direction?: unknown }).direction;
        if (typeof key !== "string" || !key) return null;
        if (direction !== "asc" && direction !== "desc") return null;
        return { key, direction };
    } catch { return null; }
}

export function parseColumnFilters(json: unknown): ColumnFilters {
    if (typeof json !== "string" || !json) return {};
    try {
        const parsed = JSON.parse(json);
        if (!parsed || typeof parsed !== "object") return {};
        const out: ColumnFilters = {};
        for (const [k, v] of Object.entries(parsed as Record<string, unknown>)) {
            if (!v || typeof v !== "object") continue;
            const o = v as Record<string, unknown>;
            if (o.mode === "values" && Array.isArray(o.selected)) {
                const selected = o.selected.filter((s): s is string => typeof s === "string");
                out[k] = { mode: "values", selected };
            } else if (o.mode === "condition" && typeof o.op === "string" && typeof o.value === "string") {
                const entry: ColumnFilterState = { mode: "condition", op: o.op, value: o.value };
                if (typeof o.valueTo === "string") entry.valueTo = o.valueTo;
                out[k] = entry;
            }
        }
        return out;
    } catch { return {}; }
}

// ─── Report-page filter push ────────────────────────────────────────────────

// Derive an (table, column) report-filter target from a column's queryName.
// Returns null for measures / aggregates / unresolvable names — those filter
// locally only and are never pushed to the report.
function filterTargetFor(col: DataViewMetadataColumn): IFilterColumnTarget | null {
    if (!col || col.isMeasure) return null;
    const qn = col.queryName;
    if (!qn || qn.includes("(")) return null;
    const i = qn.lastIndexOf(".");
    if (i <= 0 || i >= qn.length - 1) return null;
    return { table: qn.slice(0, i), column: qn.slice(i + 1) };
}

const ADVANCED_OP_MAP: Record<string, string | null> = {
    contains: "Contains", notContains: "DoesNotContain",
    equals: "Is", notEquals: "IsNot",
    beginsWith: "StartsWith", endsWith: null, // no AdvancedFilter equivalent — local only
    greaterThan: "GreaterThan", greaterThanOrEqual: "GreaterThanOrEqual",
    lessThan: "LessThan", lessThanOrEqual: "LessThanOrEqual",
    after: "GreaterThan", afterOrEqual: "GreaterThanOrEqual",
    before: "LessThan", beforeOrEqual: "LessThanOrEqual",
    isEmpty: "IsBlank", isNotEmpty: "IsNotBlank",
};

// Build the IFilter[] to push to the report from the current column filters.
// Editable (override) columns and unresolvable targets are skipped (local only).
export function buildReportFilters(
    columnFilters: ColumnFilters,
    colByKey: Map<string, ColSpec>,
    rows: powerbi.DataViewTableRow[],
): IFilter[] {
    const out: IFilter[] = [];
    for (const [key, f] of Object.entries(columnFilters)) {
        if (!f || key.startsWith("edit:")) continue;
        const spec = colByKey.get(key);
        if (!spec) continue;
        const target = filterTargetFor(spec.column);
        if (!target) continue;

        if (f.mode === "values") {
            if (isDateCol(spec.column)) continue; // value-mode dates can't be a BasicFilter — local only
            const wanted = new Set(f.selected);
            const rawByDisplay = new Map<string, unknown>();
            for (const row of rows) {
                const disp = renderCell(row[spec.metaIndex], spec.column);
                if (wanted.has(disp) && !rawByDisplay.has(disp)) rawByDisplay.set(disp, row[spec.metaIndex]);
            }
            const values: (string | number | boolean)[] = [];
            for (const raw of rawByDisplay.values()) {
                if (raw == null || raw instanceof Date) continue;
                if (typeof raw === "number" || typeof raw === "string" || typeof raw === "boolean") values.push(raw);
                else values.push(String(raw));
            }
            if (values.length) out.push(new BasicFilter(target, "In", values).toJSON());
        } else {
            const dt = colDataType(spec.column, null);
            const conditions: IAdvancedFilterCondition[] = [];
            if (f.op === "between") {
                const lo = dt === "date" ? f.value : Number(f.value);
                const hi = dt === "date" ? (f.valueTo ?? "") : Number(f.valueTo);
                if (f.value !== "") conditions.push({ operator: "GreaterThanOrEqual", value: lo as string | number });
                if ((f.valueTo ?? "") !== "") conditions.push({ operator: "LessThanOrEqual", value: hi as string | number });
            } else {
                const adv = ADVANCED_OP_MAP[f.op];
                if (!adv) continue; // unsupported (e.g. endsWith) — local only
                if (opNeedsValue(f.op)) {
                    const v = dt === "number" ? Number(f.value) : f.value;
                    if (f.value === "" || (dt === "number" && !isFinite(v as number))) continue;
                    conditions.push({ operator: adv as IAdvancedFilterCondition["operator"], value: v as string | number });
                } else {
                    conditions.push({ operator: adv as IAdvancedFilterCondition["operator"] });
                }
            }
            if (conditions.length) out.push(new AdvancedFilter(target, "And", conditions).toJSON());
        }
    }
    return out;
}
