// Injected at runtime by visual.tsx so the rules live next to the components.
//
// FORK NOTE — visual-board's stylesheet with the region chips and badges removed and a modal
// composer added. Layout is: fixed title row (title + Add comment button), then the thread taking
// every remaining pixel with its own scrollbar. Nothing else may scroll. The composer is not in
// the flow at all any more — it only exists inside .scb-dialog.

export const CSS = `
.scb-root { display:flex; flex-direction:column; height:100%; width:100%; box-sizing:border-box; padding:6px 8px; gap:6px; position:relative; }

.scb-head { display:flex; align-items:center; gap:8px; flex:0 0 auto; }
.scb-title { font-weight:600; }
/* margin-left:auto on the status pushes it and the Add button to the right together; the button
   then sits hard against the edge with the status text to its left. */
.scb-status { margin-left:auto; font-size:11px; color:#767676; }
.scb-status.scb-err { color:#a4262c; }
.scb-add { margin-left:auto; padding:3px 12px; font-size:12px; }
.scb-status + .scb-add { margin-left:0; }

.scb-btn {
  flex:0 0 auto; padding:5px 12px; border:1px solid #d0d0d0; border-radius:3px;
  background:#f3f2f1; font:inherit; cursor:pointer;
}
.scb-btn:hover:not(:disabled) { background:#edebe9; }
.scb-btn:disabled { opacity:.5; cursor:default; }
.scb-btn-primary { background:#0078d4; border-color:#0078d4; color:#fff; }
.scb-btn-primary:hover:not(:disabled) { background:#106ebe; }

/* min-height:0 is load-bearing, not tidying. A flex item defaults to min-height:auto, which
   resolves to its CONTENT height — so without this the thread refuses to shrink below the full
   stack of posts, grows straight past .scb-root, and .scb-container's overflow:hidden clips the
   overflow. overflow-y:auto never fires because the box is never smaller than its content: the
   panel silently loses every post below the fold with no scrollbar. Same reason .scb-rte-body
   carries it. */
.scb-thread { flex:1 1 auto; min-height:0; overflow-y:auto; overflow-x:hidden; border-top:1px solid #edebe9; padding-top:4px; }
.scb-empty { color:#767676; font-style:italic; padding:8px 2px; }

.scb-item { padding:5px 2px; border-bottom:1px solid #f3f2f1; }
.scb-item:last-child { border-bottom:none; }
/* The body leads and the metadata trails it. No author: this feed records what the business
   committed to, not who typed it, so the only standing line is the timestamp. D1 still stores
   actor_email for audit — it is simply never rendered. */
/* Carries no text of its own now — no author, no timestamp. It exists purely to reserve the row
   the hover actions appear in; the actions use visibility:hidden rather than display:none so the
   row does not jump as the pointer moves down the thread. */
.scb-meta { display:flex; align-items:baseline; gap:6px; font-size:11px; color:#767676; margin-top:2px; }
.scb-actions { margin-left:auto; display:flex; gap:6px; align-items:baseline; visibility:hidden; }
.scb-item:hover .scb-actions, .scb-item:focus-within .scb-actions { visibility:visible; }
.scb-confirm-q { color:#a4262c; }
.scb-link { background:none; border:none; padding:0; font:inherit; font-size:11px; color:#0078d4; cursor:pointer; }
.scb-link:hover { text-decoration:underline; }
.scb-link.scb-danger { color:#a4262c; }
/* Rendered body. No pre-wrap any more: renderRich() emits one element per line, so the line
   breaks are structural. Keeping pre-wrap as well would double every blank line. */
.scb-body { word-break:break-word; }
.scb-line { min-height:1em; }
.scb-gap { height:.5em; }
.scb-body strong { font-weight:700; }
.scb-body em { font-style:italic; }
.scb-body s { opacity:.75; }
.scb-code {
  font-family:Consolas,"Courier New",monospace; font-size:.92em; background:#f3f2f1;
  border:1px solid #e6e4e2; border-radius:3px; padding:0 3px;
}
.scb-list { margin:2px 0; padding-left:18px; }
.scb-list li { margin:1px 0; }
.scb-a { color:#0078d4; text-decoration:none; cursor:pointer; }
.scb-a:hover { text-decoration:underline; }
.scb-a-plain { color:#0078d4; }

/* ─── Composer dialog ──────────────────────────────────────────────────────────
   The overlay is absolutely positioned inside .scb-root (which is position:relative), NOT
   position:fixed against the viewport. Power BI renders each visual in its own sandboxed iframe,
   so "the viewport" is the visual's own box either way — but fixed positioning inside a
   transformed ancestor is unreliable across Desktop and Service, and absolute is not.
   Consequence worth knowing: the dialog cannot overflow the visual, so the visual has to be tall
   enough to hold it. Below ~200px the editor gets cramped; the Executive Scorecard gives it 262. */
.scb-overlay {
  position:absolute; inset:0; z-index:20; display:flex; align-items:center; justify-content:center;
  background:rgba(0,0,0,.28); padding:10px; box-sizing:border-box;
}
.scb-dialog {
  display:flex; flex-direction:column; gap:8px; width:100%; max-width:560px; max-height:100%;
  background:#fff; border:1px solid #c8c8c8; border-radius:6px;
  box-shadow:0 6px 20px rgba(0,0,0,.22); padding:10px 12px; box-sizing:border-box;
}
.scb-dialog-head { font-weight:600; flex:0 0 auto; }
/* min-height:0 for the same reason .scb-thread needs it — without it the editor's content height
   becomes the floor and a long draft pushes the footer buttons out of the dialog. */
.scb-dialog-body { display:flex; flex:1 1 auto; min-height:0; }
.scb-dialog-foot { display:flex; justify-content:flex-end; gap:6px; flex:0 0 auto; }

/* Editor. The toolbar is a flex row above the surface. */
.scb-rte { display:flex; flex-direction:column; gap:3px; flex:1 1 auto; min-width:0; }
.scb-toolbar { display:flex; align-items:center; gap:3px; flex:0 0 auto; }
.scb-tb {
  width:22px; height:20px; padding:0; flex:0 0 auto; border:1px solid #d0d0d0; border-radius:3px;
  background:#fff; color:#444; font-size:12px; line-height:1; cursor:pointer;
}
.scb-tb:hover { background:#f3f2f1; border-color:#b8b8b8; }
.scb-tb:active { background:#e6e4e2; }
.scb-tb-bold { font-weight:800; }
.scb-tb-italic { font-style:italic; font-family:Georgia,serif; }
.scb-tb-strike { text-decoration:line-through; }
.scb-tb-ol { font-size:10px; }
/* Lit while the caret sits inside that format, so the toolbar reports state as well as sets it. */
.scb-tb-on { background:#deecf9; border-color:#0078d4; color:#004578; }
.scb-tb-on:hover { background:#cfe4f7; }
.scb-toolbar .scb-btn { padding:3px 10px; font-size:11px; }

/* The editable surface. Formatting shows as formatting — the author never sees a marker.
   The scb-b / scb-i / scb-s / scb-c / scb-ul classes come from the Lexical theme in
   RichTextEditor.tsx; Lexical stamps them on the nodes it creates. */
/* Scopes the absolutely-positioned placeholder to the text box. Without it the placeholder
   anchors to .scb-rte and lands on top of the toolbar buttons. */
.scb-rte-body { position:relative; display:flex; flex:1 1 auto; min-height:0; min-width:0; }
/* No max-height here, unlike the inline composer this forked from. The surface is in a dialog
   now, so it grows to whatever the dialog allows and the flex chain above caps it. */
.scb-surface {
  flex:1 1 auto; min-width:0; min-height:72px; overflow-y:auto; padding:5px 7px;
  border:1px solid #d0d0d0; border-radius:3px; font:inherit; color:inherit; background:#fff;
  word-break:break-word; text-align:left;
}
.scb-surface:focus { outline:none; border-color:#0078d4; }
.scb-p { margin:0; min-height:1em; }
.scb-b { font-weight:700; }
.scb-i { font-style:italic; }
.scb-s { text-decoration:line-through; opacity:.75; }
.scb-c {
  font-family:Consolas,"Courier New",monospace; font-size:.92em; background:#f3f2f1;
  border:1px solid #e6e4e2; border-radius:3px; padding:0 3px;
}
.scb-ul, .scb-ol { margin:2px 0; padding-left:18px; }
.scb-li { margin:1px 0; }
/* Lexical renders the placeholder as a sibling element rather than a CSS trick, so it has to be
   pulled back over the empty surface. Pinning right as well as left keeps a long placeholder
   inside the box on a narrow visual instead of running out past its edge.
   NB: this whole file is a TS template literal — no backticks in these comments. */
.scb-placeholder {
  position:absolute; top:5px; left:8px; right:8px; color:#a19f9d;
  pointer-events:none; user-select:none;
  overflow:hidden; white-space:nowrap; text-overflow:ellipsis;
}
`;
