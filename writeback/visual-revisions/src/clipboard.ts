// Clipboard copy with an execCommand fallback — the async Clipboard API is
// often blocked inside Power BI's sandboxed visual iframe.
export async function copyToClipboard(text: string): Promise<void> {
    return copyPlainText(text);
}

// Grid values are free text and can be multi-line (reason notes, descriptions),
// so a raw "\t"/"\n" join loses the table shape the moment Excel parses it:
// every newline INSIDE a cell starts a new spreadsheet row. Two defences, both
// needed:
//   • text/plain is TSV with RFC-4180 quoting — Excel honours a quoted field and
//     keeps its newlines inside the one cell;
//   • text/html carries a real <table>, which Excel prefers when both flavors are
//     present and whose cell boundaries are unambiguous.
// Markup a user typed into a value (a literal "<br>") is escaped, not
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
        // Fall through to the execCommand fallback.
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
