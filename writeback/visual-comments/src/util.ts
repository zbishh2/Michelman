// Shared helpers: cell formatting, clipboard, persisted-state parsers, and
// timestamp formatting. Ported from the DeliveryReliability + MRP visuals.

import powerbi from "powerbi-visuals-api";
import DataViewMetadataColumn = powerbi.DataViewMetadataColumn;

// ─── Column identity ──────────────────────────────────────────────────────────

export function colKey(c: DataViewMetadataColumn): string {
    return `data:${c.queryName ?? c.displayName ?? ""}`;
}

// Special (non-model) injected column: the single editable comment per line.
export const KEY_COMMENT = "comment:body";

// ─── Persisted-state parsers ──────────────────────────────────────────────────

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
    } catch {
        return {};
    }
}

export function parseColumnOrder(json: unknown): string[] {
    if (typeof json !== "string" || !json) return [];
    try {
        const parsed = JSON.parse(json);
        if (!Array.isArray(parsed)) return [];
        return parsed.filter((v): v is string => typeof v === "string" && v.length > 0);
    } catch {
        return [];
    }
}

export interface PersistedSort {
    key: string;
    direction: "asc" | "desc";
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
    } catch {
        return null;
    }
}

// The identity USERPRINCIPALNAME() hands back is NOT always an email. Published in the
// Service it is the AAD UPN ("zackbishop@michelman.com"), but Power BI Desktop returns the
// Windows principal of the machine ("DESKTOP-PKQSMBT\Zack"). Requiring an "@" silently
// dropped that form, so Desktop resolved to no identity at all, sent no x-actor-email, and
// every admin write came back 403 — which on a button with no error handling reads as the
// button doing nothing. Accept both shapes; anything else is still rejected so a stray text
// column bound to the field well cannot masquerade as an identity.
// (Ported from visual-otif-hits 1.0.7.0.)
export function normalizeActorEmail(value: unknown): string | null {
    if (typeof value !== "string") return null;
    const trimmed = value.trim().toLowerCase();
    if (!trimmed) return null;
    const isUpn = trimmed.includes("@");
    // DOMAIN\user — one backslash, non-empty either side, no whitespace.
    const isWindowsPrincipal = /^[^\s\\]+\\[^\s\\]+$/.test(trimmed);
    if (!isUpn && !isWindowsPrincipal) return null;
    return trimmed;
}

// ─── Cell formatting ──────────────────────────────────────────────────────────

export function isNumericCol(c: DataViewMetadataColumn): boolean {
    const t = c.type;
    return !!t && (!!t.numeric || !!t.integer);
}

export function isDateCol(c: DataViewMetadataColumn): boolean {
    return !!c.type && !!c.type.dateTime;
}

const MONTHS_SHORT = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
const MONTHS_LONG = ["January","February","March","April","May","June","July","August","September","October","November","December"];
const DAYS_SHORT = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
const DAYS_LONG = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];

function tokenValue(tok: string, d: Date): string {
    const y = d.getFullYear();
    const M = d.getMonth();
    const day = d.getDate();
    const dow = d.getDay();
    const h24 = d.getHours();
    const h12 = h24 % 12 === 0 ? 12 : h24 % 12;
    const mi = d.getMinutes();
    const s = d.getSeconds();
    const ampm = h24 < 12 ? "AM" : "PM";
    switch (tok) {
        case "yyyy": return String(y);
        case "yy":   return String(y).slice(-2);
        case "MMMM": return MONTHS_LONG[M];
        case "MMM":  return MONTHS_SHORT[M];
        case "MM":   return String(M + 1).padStart(2, "0");
        case "M":    return String(M + 1);
        case "dddd": return DAYS_LONG[dow];
        case "ddd":  return DAYS_SHORT[dow];
        case "dd":   return String(day).padStart(2, "0");
        case "d":    return String(day);
        case "HH":   return String(h24).padStart(2, "0");
        case "H":    return String(h24);
        case "hh":   return String(h12).padStart(2, "0");
        case "h":    return String(h12);
        case "mm":   return String(mi).padStart(2, "0");
        case "m":    return String(mi);
        case "ss":   return String(s).padStart(2, "0");
        case "s":    return String(s);
        case "tt":   return ampm;
        case "t":    return ampm.charAt(0);
        default:     return tok;
    }
}

function matchToken(fmt: string, i: number): string | null {
    const ch = fmt[i];
    if (!"yMdHhmst".includes(ch)) return null;
    let j = i + 1;
    while (j < fmt.length && fmt[j] === ch) j++;
    return fmt.slice(i, j);
}

function applyDateFormat(d: Date, fmt: string): string {
    let out = "";
    let i = 0;
    while (i < fmt.length) {
        const ch = fmt[i];
        if (ch === "\\" && i + 1 < fmt.length) { out += fmt[i + 1]; i += 2; continue; }
        if (ch === "'" || ch === '"') {
            const end = fmt.indexOf(ch, i + 1);
            if (end === -1) { out += fmt.slice(i + 1); break; }
            out += fmt.slice(i + 1, end);
            i = end + 1;
            continue;
        }
        if (ch === "%") { i += 1; continue; }
        const tok = matchToken(fmt, i);
        if (tok) { out += tokenValue(tok, d); i += tok.length; continue; }
        out += ch;
        i += 1;
    }
    return out;
}

export function fmtDate(v: unknown, format?: string): string {
    if (v == null) return "";
    const d = v instanceof Date ? v : new Date(String(v));
    if (isNaN(d.getTime())) return String(v);
    if (format && format.trim()) return applyDateFormat(d, format);
    return d.toLocaleDateString();
}

export function fmtNumber(v: unknown, format?: string): string {
    if (v == null || v === "") return "";
    const n = typeof v === "number" ? v : Number(v);
    if (!isFinite(n)) return String(v);
    if (format && /%/.test(format)) {
        return `${(n * 100).toFixed(format.includes(".0") ? 1 : 0)}%`;
    }
    if (format && /[$£€]/.test(format)) {
        return n.toLocaleString(undefined, { style: "currency", currency: "USD" });
    }
    return n.toLocaleString(undefined, { maximumFractionDigits: Number.isInteger(n) ? 0 : 2 });
}

export function renderCell(v: unknown, c: DataViewMetadataColumn): string {
    if (v == null) return "";
    if (isDateCol(c)) return fmtDate(v, c.format);
    if (isNumericCol(c)) return fmtNumber(v, c.format);
    return String(v);
}

// ─── Clipboard (async API with execCommand fallback for sandboxed iframes) ─────

export async function copyToClipboard(text: string): Promise<void> {
    return copyPlainText(text);
}

// Comments are free text and routinely multi-line, so a raw "\t"/"\n" join loses
// the table shape the moment Excel parses it: every newline INSIDE a cell starts
// a new spreadsheet row. Two defences, both needed:
//   • text/plain is TSV with RFC-4180 quoting — Excel honours a quoted field and
//     keeps its newlines inside the one cell;
//   • text/html carries a real <table>, which Excel prefers when both flavors are
//     present and whose cell boundaries are unambiguous.
// Markup a user typed into a comment (Ivan's literal "<br>") is escaped, not
// interpreted, so it pastes as the text it is on either path.
function tsvField(v: string): string {
    return /[\t\r\n"]/.test(v) ? `"${v.replace(/"/g, '""')}"` : v;
}

function htmlText(v: string): string {
    return v
        .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        .replace(/\r\n|\r|\n/g, "<br>");
}

function buildTable(headers: string[] | null, rows: string[][]): { text: string; html: string } {
    const singleCell = !headers && rows.length === 1 && rows[0].length === 1;
    const textRows = headers ? [headers, ...rows] : rows;
    // A lone value keeps its raw text so pasting into mail/Teams doesn't pick up
    // quote marks; Excel still gets one cell because it reads the HTML flavor.
    const text = singleCell
        ? rows[0][0]
        : textRows.map((r) => r.map(tsvField).join("\t")).join("\r\n");
    const tr = (cells: string[], tag: "th" | "td") =>
        `<tr>${cells.map((c) => `<${tag} style="white-space:pre-wrap;vertical-align:top">${htmlText(c)}</${tag}>`).join("")}</tr>`;
    const html = `<table>${headers ? tr(headers, "th") : ""}${rows.map((r) => tr(r, "td")).join("")}</table>`;
    return { text, html };
}

/** Copy a grid selection so Excel receives it as cells, not as reflowed text. */
export async function copyTable(headers: string[] | null, rows: string[][]): Promise<void> {
    const { text, html } = buildTable(headers, rows);
    const w = window as unknown as { ClipboardItem?: new (items: Record<string, Blob>) => unknown };
    if (typeof w.ClipboardItem === "function" && navigator.clipboard?.write) {
        try {
            await navigator.clipboard.write([
                new w.ClipboardItem({
                    "text/html": new Blob([html], { type: "text/html" }),
                    "text/plain": new Blob([text], { type: "text/plain" }),
                }),
            ] as unknown as ClipboardItem[]);
            return;
        } catch {
            // Fall through — the sandboxed iframe often refuses the rich write.
        }
    }
    if (copyTableViaSelection(headers, rows)) return;
    return copyPlainText(text);
}

// execCommand copy over a selected detached node: the browser derives BOTH the
// HTML and plain-text flavors from the DOM, which is the path that survives the
// visual's sandbox when navigator.clipboard.write is blocked. Built with
// createElement rather than innerHTML — the pbiviz linter bans innerHTML, and
// text nodes escape the values for free. Newlines become <br> so Excel keeps
// them inside the cell.
function copyTableViaSelection(headers: string[] | null, rows: string[][]): boolean {
    const host = document.createElement("div");
    host.contentEditable = "true";
    host.style.position = "fixed";
    host.style.left = "-10000px";
    host.style.top = "0";
    host.style.whiteSpace = "pre-wrap";
    const table = document.createElement("table");
    const addRow = (cells: string[], tag: "th" | "td") => {
        const tr = document.createElement("tr");
        for (const value of cells) {
            const cell = document.createElement(tag);
            cell.style.verticalAlign = "top";
            value.split(/\r\n|\r|\n/).forEach((line, i) => {
                if (i > 0) cell.appendChild(document.createElement("br"));
                cell.appendChild(document.createTextNode(line));
            });
            tr.appendChild(cell);
        }
        table.appendChild(tr);
    };
    if (headers) addRow(headers, "th");
    for (const row of rows) addRow(row, "td");
    host.appendChild(table);
    document.body.appendChild(host);
    let ok = false;
    try {
        const range = document.createRange();
        range.selectNodeContents(host);
        const sel = window.getSelection();
        sel?.removeAllRanges();
        sel?.addRange(range);
        ok = document.execCommand("copy");
        sel?.removeAllRanges();
    } catch {
        ok = false;
    }
    host.remove();
    return ok;
}

async function copyPlainText(text: string): Promise<void> {
    try {
        await navigator.clipboard.writeText(text);
        return;
    } catch {
        // Fall through.
    }
    const ta = document.createElement("textarea");
    ta.value = text;
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand("copy"); } catch { /* ignore */ }
    ta.remove();
}

// ─── Timestamps ───────────────────────────────────────────────────────────────

// Worker timestamps are UTC without a zone suffix (SQLite datetime('now')).
// Treat a bare timestamp as UTC before displaying in local time.
function parseServerTime(iso: string): number {
    const hasZone = iso.endsWith("Z") || /[+-]\d{2}:?\d{2}$/.test(iso);
    return Date.parse(hasZone ? iso : iso.replace(" ", "T") + "Z");
}

export function formatRelative(iso: string): string {
    const t = parseServerTime(iso);
    if (!Number.isFinite(t)) return iso;
    const diff = (Date.now() - t) / 1000;
    if (diff < 60) return "just now";
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
    const d = new Date(t);
    return `${d.getMonth() + 1}/${d.getDate()}/${String(d.getFullYear()).slice(2)}`;
}

export function formatTimestamp(iso: string): string {
    const t = parseServerTime(iso);
    if (Number.isNaN(t)) return iso;
    const d = new Date(t);
    const mm = String(d.getMonth() + 1).padStart(2, "0");
    const dd = String(d.getDate()).padStart(2, "0");
    const yyyy = d.getFullYear();
    let hh = d.getHours();
    const ampm = hh >= 12 ? "PM" : "AM";
    hh = hh % 12 || 12;
    const min = String(d.getMinutes()).padStart(2, "0");
    return `${mm}/${dd}/${yyyy} ${hh}:${min} ${ampm}`;
}
