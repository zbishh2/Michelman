// Canvas-based default column widths. Estimates each column's natural width from
// its header (allowing a 2-line wrap) plus a sample of up to 50 cell values, so
// the grid starts compact without clipping. Persisted / drag-resized widths
// always override these — the App only falls back to them when no width exists.

const FONT_FAMILY = "-apple-system, Segoe UI, Roboto, sans-serif";
const SAMPLE_ROWS = 50;
const CELL_PAD = 8;          // 2px*2 cell padding + border/slack
const HEAD_AFFORDANCE = 22;  // sort caret + menu affordance + padding
const MIN_W = 44;
const TEXT_CAP = 240;
const WIDE_CAP = 600;        // numeric/date: size to widest sample, generous safety only

export interface AutoSizeCol {
    key: string;
    header: string;
    wide: boolean;                       // numeric/date → size to widest sample, skip text cap
    valueAt: (rowIndex: number) => string;
}

let sharedCanvas: HTMLCanvasElement | null = null;

export function estimateColumnWidths(
    columns: AutoSizeCol[],
    sampleCount: number,
    fontSize: number,
): Record<string, number> {
    const out: Record<string, number> = {};
    const canvas = sharedCanvas ?? (sharedCanvas = document.createElement("canvas"));
    const ctx = canvas.getContext("2d");
    if (!ctx) return out;
    const bodyFont = `${fontSize}px ${FONT_FAMILY}`;
    const headFont = `600 ${fontSize}px ${FONT_FAMILY}`;
    const n = Math.min(SAMPLE_ROWS, sampleCount);
    for (const col of columns) {
        ctx.font = headFont;
        const headerPx = ctx.measureText(col.header).width;
        // A 2-line wrap needs only ~half the single-line header width, but never
        // less than the widest single word (which cannot break across lines).
        let widestWord = 0;
        for (const w of col.header.split(/\s+/)) {
            const wpx = ctx.measureText(w).width;
            if (wpx > widestWord) widestWord = wpx;
        }
        const headerNeed = Math.max(headerPx / 2, widestWord) + HEAD_AFFORDANCE;
        ctx.font = bodyFont;
        let cellMax = 0;
        for (let i = 0; i < n; i++) {
            const s = col.valueAt(i);
            if (!s) continue;
            const wpx = ctx.measureText(s).width;
            if (wpx > cellMax) cellMax = wpx;
        }
        const natural = Math.max(headerNeed, cellMax + CELL_PAD);
        const cap = col.wide ? WIDE_CAP : TEXT_CAP;
        out[col.key] = Math.round(Math.max(MIN_W, Math.min(natural, cap)));
    }
    return out;
}
