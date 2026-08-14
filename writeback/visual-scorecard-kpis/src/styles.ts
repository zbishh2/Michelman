// Injected at runtime by visual.tsx so the rules live next to the components.
//
// The table is a deliberate pixel-match for the report's native tableEx tables
// (the two model-backed Scorecard tables it sits beside): #3F3F3F header with
// white bold text, #D6D6D6 gridlines, banded rows, 5px row padding, left-aligned
// headers, centered value columns. If those tables' styling ever changes, change
// this file to match — the three tables reading as one family is the point.
//
// Editing is INLINE (the row swaps to inputs), not a dialog: the visual is only
// ~160px tall and an overlay dialog cannot escape the visual's own box (see
// ARCHITECTURE.md on the sandboxed iframe), so there is no room for one.

export const CSS = `
.sck-root { display:flex; flex-direction:column; height:100%; width:100%; box-sizing:border-box; position:relative; }

/* min-height:0 so the scroll pane can shrink below its content (see ARCHITECTURE.md). */
.sck-scroll { flex:1 1 auto; min-height:0; overflow-y:auto; overflow-x:hidden; }
/* Thin themed scrollbar, never the Windows-native one: the native bar (arrow
   buttons, 17px gutter) reads as foreign chrome inside the report and renders
   blurry under Desktop's scaled WebView. */
.sck-scroll { scrollbar-width:thin; scrollbar-color:#c8c6c4 transparent; }

.sck-table { width:100%; border-collapse:collapse; table-layout:fixed; }
.sck-table th, .sck-table td {
  border:1px solid #D6D6D6; padding:5px 8px; box-sizing:border-box;
  overflow:hidden; text-overflow:ellipsis; word-wrap:break-word;
}
.sck-table th {
  background:#3F3F3F; color:#FFFFFF; font-weight:700; text-align:left; vertical-align:top;
}
.sck-table td { background:#FFFFFF; color:#000; vertical-align:middle; }
.sck-row-banded td { background:#F3F2F1; }
.sck-col-kpi { text-align:left; }
.sck-col-mid { text-align:center; }

/* The pencil reserves no column: it floats over the trend cell's right edge on
   hover only, so the resting table stays a byte-for-byte match with its native
   siblings. visibility (not display) so the row never reflows. */
/* The trend column never wraps: its verdicts are a fixed vocabulary and the column
   is sized so the longest ("Needs Improvement") fits on one line, exactly as it
   does in the native tables. */
.sck-cell-trend { position:relative; white-space:nowrap; }
.sck-edit-btn {
  position:absolute; right:2px; top:50%; transform:translateY(-50%);
  visibility:hidden; border:none; background:none; padding:0 2px; cursor:pointer;
  font-size:12px; line-height:1; color:#767676;
}
.sck-edit-btn:hover { color:#0078d4; }
tr:hover .sck-edit-btn, tr:focus-within .sck-edit-btn { visibility:visible; }

/* Inline edit mode. Inputs inherit the cell's font so nothing jumps. */
.sck-input, .sck-select {
  width:100%; box-sizing:border-box; font:inherit; color:inherit;
  border:1px solid #0078d4; border-radius:2px; padding:1px 3px; background:#fff;
}
.sck-input:focus, .sck-select:focus { outline:none; border-color:#005a9e; }
.sck-select { text-align:center; }

.sck-actions { display:flex; gap:4px; justify-content:center; margin-top:3px; }
.sck-btn {
  flex:0 0 auto; padding:1px 8px; border:1px solid #d0d0d0; border-radius:3px;
  background:#f3f2f1; font:inherit; font-size:.9em; cursor:pointer;
}
.sck-btn:hover:not(:disabled) { background:#edebe9; }
.sck-btn:disabled { opacity:.5; cursor:default; }
.sck-btn-primary { background:#0078d4; border-color:#0078d4; color:#fff; }
.sck-btn-primary:hover:not(:disabled) { background:#106ebe; }

/* Load / save problems render as a strip under the table, never inside it. */
.sck-status { flex:0 0 auto; font-size:11px; color:#767676; padding:2px 2px 0; }
.sck-status.sck-err { color:#a4262c; }
.sck-empty { color:#767676; font-style:italic; padding:8px 2px; }
`;
