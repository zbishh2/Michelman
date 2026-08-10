// Injected at runtime by visual.tsx so the rules live next to the components.
// The visual is short and wide on the Summary tab (roughly 1274 x 150), so the
// layout is: fixed title row, fixed composer row, and the thread taking every
// remaining pixel with its own scrollbar. Nothing else may scroll.

export const CSS = `
.obc-root { display:flex; flex-direction:column; height:100%; width:100%; box-sizing:border-box; padding:6px 8px; gap:6px; }

.obc-head { display:flex; align-items:center; gap:8px; flex:0 0 auto; }
.obc-title { font-weight:600; }
.obc-count { color:#767676; font-size:11px; }
.obc-status { margin-left:auto; font-size:11px; color:#767676; }
.obc-status.obc-err { color:#a4262c; }

/* Region chips — Yvonne reads one region at a time. Counts live on the chip so the
   header needs no separate total. Each chip carries its region's accent only when active,
   so the unselected row stays quiet. */
.obc-filters { display:flex; gap:3px; flex:0 1 auto; align-items:center; flex-wrap:wrap; }
.obc-chip {
  display:inline-flex; align-items:center; gap:4px; padding:1px 7px; font:inherit; font-size:11px;
  line-height:16px; border:1px solid #d0d0d0; border-radius:9px; background:#fff; color:#444;
  cursor:pointer; white-space:nowrap;
}
.obc-chip:hover { background:#f3f2f1; }
.obc-chip-n { color:#767676; font-size:10px; }
.obc-chip-on { color:#fff; border-color:transparent; }
.obc-chip-on .obc-chip-n { color:rgba(255,255,255,.8); }
.obc-chip-on:hover { filter:brightness(1.08); }
.obc-chip-on.obc-rgn-americas { background:#0078d4; }
.obc-chip-on.obc-rgn-emea     { background:#107c41; }
.obc-chip-on.obc-rgn-asia     { background:#8a6d00; }
.obc-chip-on:not([class*="obc-rgn-"]) { background:#484644; }

/* Region tag on each post. Muted fills — the badge labels the row, it shouldn't outshout it. */
.obc-badge {
  flex:0 0 auto; padding:0 5px; border-radius:8px; font-size:10px; line-height:15px;
  font-weight:600; letter-spacing:.02em;
}
.obc-badge.obc-rgn-americas { background:#deecf9; color:#004578; }
.obc-badge.obc-rgn-emea     { background:#dff6e6; color:#0b5a2f; }
.obc-badge.obc-rgn-asia     { background:#fdf3d3; color:#6b5400; }
.obc-badge.obc-rgn-all      { background:#f0f0f0; color:#616161; }

.obc-region-select {
  flex:0 0 auto; padding:3px 5px; border:1px solid #d0d0d0; border-radius:3px;
  background:#fff; font:inherit; font-size:11px; color:inherit; cursor:pointer;
}
.obc-region-select:focus { outline:none; border-color:#0078d4; }
.obc-btn {
  flex:0 0 auto; padding:5px 12px; border:1px solid #d0d0d0; border-radius:3px;
  background:#f3f2f1; font:inherit; cursor:pointer;
}
.obc-btn:hover:not(:disabled) { background:#edebe9; }
.obc-btn:disabled { opacity:.5; cursor:default; }
.obc-btn-primary { background:#0078d4; border-color:#0078d4; color:#fff; }
.obc-btn-primary:hover:not(:disabled) { background:#106ebe; }

/* min-height:0 is load-bearing, not tidying. A flex item defaults to min-height:auto, which
   resolves to its CONTENT height — so without this the thread refuses to shrink below the full
   stack of posts, grows straight past .obc-root, and .obc-container's overflow:hidden clips the
   overflow. overflow-y:auto never fires because the box is never smaller than its content: the
   panel silently loses every post below the fold with no scrollbar. Same reason .obc-rte-body
   carries it. */
.obc-thread { flex:1 1 auto; min-height:0; overflow-y:auto; overflow-x:hidden; border-top:1px solid #edebe9; padding-top:4px; }
.obc-empty { color:#767676; font-style:italic; padding:8px 2px; }

.obc-item { padding:5px 2px; border-bottom:1px solid #f3f2f1; }
.obc-item:last-child { border-bottom:none; }
.obc-meta { display:flex; align-items:baseline; gap:6px; font-size:11px; color:#767676; }
.obc-author { font-weight:600; color:#444; }
.obc-edited { font-style:italic; }
.obc-actions { margin-left:auto; display:flex; gap:6px; visibility:hidden; }
.obc-item:hover .obc-actions { visibility:visible; }
.obc-link { background:none; border:none; padding:0; font:inherit; font-size:11px; color:#0078d4; cursor:pointer; }
.obc-link:hover { text-decoration:underline; }
.obc-link.obc-danger { color:#a4262c; }
/* Rendered body. No pre-wrap any more: renderRich() emits one element per line, so the line
   breaks are structural. Keeping pre-wrap as well would double every blank line. */
.obc-body { word-break:break-word; margin-top:1px; }
.obc-line { min-height:1em; }
.obc-gap { height:.5em; }
.obc-body strong { font-weight:700; }
.obc-body em { font-style:italic; }
.obc-body s { opacity:.75; }
.obc-code {
  font-family:Consolas,"Courier New",monospace; font-size:.92em; background:#f3f2f1;
  border:1px solid #e6e4e2; border-radius:3px; padding:0 3px;
}
.obc-list { margin:2px 0; padding-left:18px; }
.obc-list li { margin:1px 0; }
.obc-a { color:#0078d4; text-decoration:none; cursor:pointer; }
.obc-a:hover { text-decoration:underline; }
.obc-a-plain { color:#0078d4; }

/* Composer / editor. The toolbar is the flex row that already held the region picker and Post
   button, so adding it costs no vertical space on the 150px panel. */
.obc-rte { display:flex; flex-direction:column; gap:3px; flex:1 1 auto; min-width:0; }
.obc-toolbar { display:flex; align-items:center; gap:3px; flex:0 0 auto; }
.obc-tb {
  width:22px; height:20px; padding:0; flex:0 0 auto; border:1px solid #d0d0d0; border-radius:3px;
  background:#fff; color:#444; font-size:12px; line-height:1; cursor:pointer;
}
.obc-tb:hover { background:#f3f2f1; border-color:#b8b8b8; }
.obc-tb:active { background:#e6e4e2; }
.obc-tb-bold { font-weight:800; }
.obc-tb-italic { font-style:italic; font-family:Georgia,serif; }
.obc-tb-strike { text-decoration:line-through; }
.obc-tb-ol { font-size:10px; }
/* Lit while the caret sits inside that format, so the toolbar reports state as well as sets it. */
.obc-tb-on { background:#deecf9; border-color:#0078d4; color:#004578; }
.obc-tb-on:hover { background:#cfe4f7; }
/* Whatever the caller slotted in (region picker, Post/Save/Cancel) rides the toolbar's right. */
.obc-toolbar .obc-composer-side { margin-left:auto; flex-direction:row; align-items:center; gap:4px; }
.obc-toolbar > .obc-region-select { margin-left:auto; }
.obc-toolbar .obc-btn { padding:3px 10px; font-size:11px; }

.obc-composer { display:flex; gap:6px; flex:0 0 auto; align-items:stretch; }
.obc-composer-side { display:flex; flex-direction:column; gap:4px; flex:0 0 auto; justify-content:center; }

/* The editable surface. Formatting shows as formatting — the author never sees a marker.
   The obc-b / obc-i / obc-s / obc-c / obc-ul classes come from the Lexical theme in
   RichTextEditor.tsx; Lexical stamps them on the nodes it creates. */
/* Scopes the absolutely-positioned placeholder to the text box. Without it the placeholder
   anchors to .obc-rte and lands on top of the toolbar buttons. */
.obc-rte-body { position:relative; display:flex; flex:1 1 auto; min-height:0; min-width:0; }
.obc-surface {
  flex:1 1 auto; min-width:0; min-height:30px; max-height:64px; overflow-y:auto; padding:5px 7px;
  border:1px solid #d0d0d0; border-radius:3px; font:inherit; color:inherit; background:#fff;
  word-break:break-word; text-align:left;
}
.obc-surface:focus { outline:none; border-color:#0078d4; }
.obc-p { margin:0; min-height:1em; }
.obc-b { font-weight:700; }
.obc-i { font-style:italic; }
.obc-s { text-decoration:line-through; opacity:.75; }
.obc-c {
  font-family:Consolas,"Courier New",monospace; font-size:.92em; background:#f3f2f1;
  border:1px solid #e6e4e2; border-radius:3px; padding:0 3px;
}
.obc-ul, .obc-ol { margin:2px 0; padding-left:18px; }
.obc-li { margin:1px 0; }
/* Lexical renders the placeholder as a sibling element rather than a CSS trick, so it has to be
   pulled back over the empty surface. Pinning right as well as left keeps a long placeholder
   inside the box on a narrow visual instead of running out past its edge.
   NB: this whole file is a TS template literal — no backticks in these comments. */
.obc-placeholder {
  position:absolute; top:5px; left:8px; right:8px; color:#a19f9d;
  pointer-events:none; user-select:none;
  overflow:hidden; white-space:nowrap; text-overflow:ellipsis;
}

.obc-edit { display:flex; gap:6px; margin-top:3px; align-items:flex-start; }
.obc-edit .obc-surface { min-height:44px; max-height:120px; border-color:#0078d4; }
`;
