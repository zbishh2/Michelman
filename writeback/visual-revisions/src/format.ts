// Cell value formatting: dates, numbers, and the column-key helper. Ported
// verbatim from the DeliveryReliability visual (proven .NET-style date parsing).

import powerbi from "powerbi-visuals-api";
import DataViewMetadataColumn = powerbi.DataViewMetadataColumn;

export function colKey(c: DataViewMetadataColumn): string {
    return `data:${c.queryName ?? c.displayName ?? ""}`;
}

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

// Derive fraction-digit counts from a Power BI numeric format string (e.g.
// "0.000" -> min 3 / max 3, "#,0.##" -> min 0 / max 2). `0` placeholders are
// always shown, `#` placeholders only when significant. Returns null when the
// format carries no decimal section so callers can fall back to a default.
function fractionDigitsFromFormat(format?: string): { min: number; max: number } | null {
    if (!format) return null;
    const dot = format.indexOf(".");
    if (dot === -1) return null;
    let min = 0, max = 0;
    for (let i = dot + 1; i < format.length; i++) {
        const ch = format[i];
        if (ch === "0") { min++; max++; }
        else if (ch === "#") { max++; }
        else break;
    }
    return { min, max };
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
    const fd = fractionDigitsFromFormat(format);
    if (fd) {
        return n.toLocaleString(undefined, {
            minimumFractionDigits: fd.min,
            maximumFractionDigits: Math.max(fd.min, fd.max),
            useGrouping: format!.includes(","),
        });
    }
    return n.toLocaleString(undefined, { maximumFractionDigits: Number.isInteger(n) ? 0 : 2 });
}

export function renderCell(v: unknown, c: DataViewMetadataColumn): string {
    if (v == null) return "";
    if (isDateCol(c)) return fmtDate(v, c.format);
    if (isNumericCol(c)) return fmtNumber(v, c.format);
    return String(v);
}

export function dateOnlyTime(v: unknown): number | null {
    if (v == null || v === "") return null;
    const d = v instanceof Date ? v : new Date(String(v));
    if (isNaN(d.getTime())) return null;
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

// "2h ago" style relative label for the audit log. Timestamps from the Worker
// are UTC without an offset suffix, so normalize to Z before parsing.
export function formatRelativeTime(iso: string): string {
    const t = Date.parse(iso.endsWith("Z") || /[+-]\d{2}:?\d{2}$/.test(iso) ? iso : iso + "Z");
    if (Number.isNaN(t)) return iso;
    const diff = Date.now() - t;
    if (diff < 45 * 1000) return "just now";
    const mins = Math.floor(diff / 60000);
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    if (days < 30) return `${days}d ago`;
    const months = Math.floor(days / 30);
    if (months < 12) return `${months}mo ago`;
    return `${Math.floor(days / 365)}y ago`;
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

export function formatHistoryTimestamp(iso: string): string {
    const t = Date.parse(iso.endsWith("Z") || /[+-]\d{2}:?\d{2}$/.test(iso) ? iso : iso + "Z");
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
