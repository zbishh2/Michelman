// All runtime CSS for the visual, injected into the sandbox via a <style> tag
// in the Visual constructor. Grid rules adapted from the DeliveryReliability
// visual; thread-panel / comment rules adapted from the MRP visual.

export const CSS = `
.olc-container { height: 100%; overflow: hidden; font: 12px -apple-system, Segoe UI, Roboto, sans-serif; color: #222; }
.olc-root { display: flex; flex-direction: column; height: 100%; }
.olc-header { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 4px 6px; }
.olc-title { font-weight: 600; }
.olc-actions { display: flex; align-items: center; gap: 6px; }
.olc-btn { border: 1px solid #c8c8c8; background: #fff; color: #222; font: inherit; font-size: 11px; padding: 2px 8px; border-radius: 3px; cursor: pointer; }
.olc-btn:hover { background: #f0f4ff; border-color: #7aa7ff; }
.olc-btn:active { background: #e2eaff; }
.olc-btn:disabled { color: #999; cursor: default; background: #f7f7f7; }
.olc-filter-pill { background: #eaf1ff; border-color: #7aa7ff; color: #1d4ed8; font-weight: 600; }
.olc-filter-pill:hover { background: #dbe6ff; }
.olc-btn.primary { background: #1d4ed8; color: #fff; border-color: #1d4ed8; }
.olc-btn.primary:hover:not(:disabled) { background: #1a44bd; }
.olc-btn.primary:disabled { background: #9db4ee; border-color: #9db4ee; color: #fff; }
.olc-icon-btn { display: inline-flex; align-items: center; justify-content: center; border: 0; background: transparent; color: #444; font: inherit; font-size: 16px; line-height: 1; padding: 2px 6px; cursor: pointer; border-radius: 3px; }
.olc-icon-btn:hover { background: #f0f4ff; color: #111; }
.olc-icon-btn svg { width: 13px; height: 13px; }
.olc-icon-btn.danger:hover { color: #b91c1c; background: rgba(239,68,68,0.12); }
.olc-input { min-width: 0; border: 1px solid #c8c8c8; background: #fff; color: #222; font: inherit; padding: 3px 5px; border-radius: 3px; box-sizing: border-box; }
.olc-error { padding: 4px 8px; background: #fdecea; color: #b71c1c; font-size: 11px; }
.olc-empty { padding: 12px; color: #666; }

/* ─── Context menu ─── */
.olc-ctx-menu { position: fixed; z-index: 50; background: #fff; border: 1px solid #c8c8c8; box-shadow: 0 2px 8px rgba(0,0,0,0.15); border-radius: 3px; padding: 3px 0; min-width: 150px; display: flex; flex-direction: column; }
.olc-ctx-item { border: 0; background: transparent; color: #222; font: inherit; font-size: 12px; text-align: left; padding: 5px 12px; cursor: pointer; }
.olc-ctx-item:hover:not(:disabled), .olc-ctx-item:focus:not(:disabled) { background: #f0f4ff; outline: none; }
.olc-ctx-item:disabled { color: #aaa; cursor: default; background: transparent; }

/* ─── Scroll pane (custom overlay scrollbars) ─── */
.olc-scroll-pane { position: relative; flex: 1 1 auto; min-width: 0; min-height: 0; overflow: hidden; }
.olc-scroll-inner { width: 100%; height: 100%; min-width: 0; overflow: auto; scrollbar-width: none; -ms-overflow-style: none; }
.olc-scroll-inner.has-h { height: calc(100% - 10px); }
.olc-scroll-inner.has-v { width: calc(100% - 10px); }
.olc-scroll-inner::-webkit-scrollbar { display: none; width: 0; height: 0; }
.olc-htrack { position: absolute; bottom: 0; left: 0; right: 0; height: 10px; z-index: 10; }
.olc-hthumb { position: absolute; bottom: 2px; height: 6px; background: rgba(0,0,0,0.30); border-radius: 3px; cursor: pointer; }
.olc-hthumb:hover, .olc-hthumb.dragging { background: rgba(0,0,0,0.55); }
.olc-vtrack { position: absolute; top: 0; right: 0; bottom: 0; width: 10px; z-index: 10; }
.olc-vthumb { position: absolute; right: 2px; width: 6px; background: rgba(0,0,0,0.30); border-radius: 3px; cursor: pointer; }
.olc-vthumb:hover, .olc-vthumb.dragging { background: rgba(0,0,0,0.55); }

/* ─── Table ─── */
.olc-table { border-collapse: collapse; width: max-content; min-width: 100%; }
.olc-table th, .olc-table td { border-bottom: 1px solid #e3e3e3; border-right: 1px solid #f0f0f0; padding: 4px 2px; text-align: left; vertical-align: top; max-width: 320px; white-space: pre-wrap; word-break: break-word; overflow-wrap: anywhere; }
.olc-table th { position: sticky; top: -1px; background: #f7f7f7; font-weight: 600; z-index: 5; user-select: none; cursor: pointer; }
.olc-table th.olc-frozen-col { z-index: 6; }
.olc-table td.olc-frozen-col { position: sticky; z-index: 2; background: #fff; }
.olc-table tr:hover td { background: #f9fbff; }
.olc-table tr:hover td.olc-frozen-col { background: #f9fbff; }
.olc-table .olc-frozen-boundary { box-shadow: 2px 0 3px rgba(0,0,0,0.12); }
/* ─── Selected rows (cross-filter the report) ─── */
.olc-table tbody tr { cursor: pointer; }
.olc-table tbody tr.olc-row-selected td { background: #e8f0ff; }
.olc-table tbody tr.olc-row-selected td.olc-frozen-col { background: #e8f0ff; }
.olc-table tbody tr.olc-row-selected:hover td { background: #dbe6ff; }
.olc-table tbody tr.olc-row-selected:hover td.olc-frozen-col { background: #dbe6ff; }
.olc-table td.num, .olc-table th.num { text-align: right; }
.olc-resizer { position: absolute; top: 0; right: 0; width: 6px; height: 100%; cursor: col-resize; user-select: none; }
.olc-resizer:hover, .olc-resizer.active { background: #b8d4ff; }
.olc-th-inner { position: relative; display: flex; align-items: flex-start; gap: 2px; padding-right: 6px; }
.olc-th-label { flex: 1 1 auto; min-width: 0; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; word-break: break-word; line-height: 1.15; }
.olc-table th.num .olc-th-label { text-align: right; }
.olc-th-inner > .olc-sort-indicator, .olc-th-inner > .olc-th-filter-icon, .olc-th-inner > .olc-th-menu-caret { flex: 0 0 auto; }
.olc-sort-indicator { color: #555; font-size: 10px; }
.olc-th-menu-caret { color: #b0b0b0; font-size: 9px; margin-left: 3px; }
.olc-th-filter-icon { color: #2b6cb0; font-size: 10px; margin-left: 3px; }
.olc-draggable-th { cursor: grab; }
.olc-draggable-th:active { cursor: grabbing; }
.olc-table tfoot .olc-totals-cell { position: sticky; bottom: -2px; padding-bottom: 6px; background: #f7f7f7; font-weight: 600; border-top: 2px solid #c8c8c8; border-right: 0; border-bottom: 0; z-index: 5; }
.olc-table tfoot .olc-totals-cell.olc-frozen-col { z-index: 6; }

/* ─── Editable comment cell (auto-growing textarea, one comment per line) ─── */
.olc-readonly-note { padding: 3px 8px; background: #f4f6fb; color: #555; font-size: 11px; border-bottom: 1px solid #e3e3e3; }
.olc-cell-comment-edit { padding: 2px; }
.olc-cell-notes { border: 1px solid transparent; background: transparent; font: inherit; color: inherit; padding: 2px 4px; width: 100%; max-width: 100%; min-width: 0; box-sizing: border-box; display: block; min-height: 24px; resize: none; overflow: hidden; white-space: pre-wrap; word-wrap: break-word; overflow-wrap: break-word; }
.olc-cell-notes:hover, .olc-cell-notes:focus { border-color: #c8c8c8; background: #fff; outline: none; }
.olc-cell-notes:disabled { color: #999; background: transparent; }

/* ─── Header sort/filter popover ─── */
.olc-hdr-menu { position: fixed; z-index: 50; width: 248px; background: #fff; border: 1px solid #c8c8c8; box-shadow: 0 4px 14px rgba(0,0,0,0.18); border-radius: 4px; font-size: 12px; display: flex; flex-direction: column; overflow: hidden; }
.olc-hdr-menu-section { padding: 2px 0; border-bottom: 1px solid #eee; display: flex; flex-direction: column; flex: 0 0 auto; }
.olc-hdr-menu-item { border: 0; background: transparent; color: #222; font: inherit; text-align: left; padding: 4px 12px; cursor: pointer; display: flex; align-items: center; gap: 4px; }
.olc-hdr-menu-item:hover:not(:disabled) { background: #f0f4ff; }
.olc-hdr-menu-item:disabled { color: #bbb; cursor: default; }
.olc-hdr-menu-item.active { background: #e2eaff; }
.olc-hdr-chevron { margin-left: auto; color: #888; }
.olc-hdr-filter { display: flex; flex-direction: column; padding: 5px 6px; gap: 4px; border-bottom: 1px solid #eee; flex: 1 1 auto; min-height: 0; overflow: hidden; }
.olc-hdr-filter-search { box-sizing: border-box; width: 100%; border: 1px solid #c8c8c8; border-radius: 3px; font: inherit; padding: 4px 6px; outline: none; flex: 0 0 auto; }
.olc-hdr-filter-search:focus { border-color: #7aa7ff; box-shadow: 0 0 0 2px rgba(122,167,255,0.2); }
/* The value checklist scrolls via the ScrollPane overlay (no native scrollbar,
   which blurs under the sandbox iframe transform). */
.olc-hdr-filter-scroll { flex: 1 1 auto; min-height: 120px; display: flex; }
.olc-hdr-filter-list { list-style: none; margin: 0; padding: 0; }
.olc-hdr-filter-opt { display: flex; align-items: center; gap: 6px; padding: 2px 4px; cursor: pointer; white-space: nowrap; overflow: hidden; }
.olc-hdr-filter-opt:hover { background: #f0f4ff; }
.olc-hdr-filter-empty { color: #999; font-style: italic; cursor: default; }
.olc-hdr-filter-label { overflow: hidden; text-overflow: ellipsis; }
.olc-hdr-check { flex: 0 0 auto; width: 14px; height: 14px; border: 1px solid #b0b0b0; border-radius: 2px; display: inline-flex; align-items: center; justify-content: center; font-size: 10px; line-height: 1; color: #fff; background: #fff; }
.olc-hdr-check.on { background: #2b6cb0; border-color: #2b6cb0; }
.olc-hdr-check.some { background: #9bb8dd; border-color: #9bb8dd; }
.olc-hdr-cond { display: flex; flex-direction: column; gap: 6px; padding: 6px; border-bottom: 1px solid #eee; flex: 0 0 auto; }
.olc-hdr-cond-op, .olc-hdr-cond-val { box-sizing: border-box; width: 100%; border: 1px solid #c8c8c8; border-radius: 3px; font: inherit; padding: 4px 6px; outline: none; }
.olc-hdr-cond-op:focus, .olc-hdr-cond-val:focus { border-color: #7aa7ff; box-shadow: 0 0 0 2px rgba(122,167,255,0.2); }
.olc-hdr-cond-and { color: #888; font-size: 11px; }
.olc-hdr-menu-actions { display: flex; gap: 6px; justify-content: flex-end; padding: 6px; flex: 0 0 auto; }

/* ─── Slide-in panels (thread + people) ─── */
.olc-modal-backdrop { position: absolute; inset: 0; z-index: 20; background: rgba(255,255,255,0.55); display: flex; justify-content: flex-end; }
.olc-thread-panel { width: min(440px, 94%); height: 100%; background: #fff; border-left: 1px solid #c8c8c8; box-shadow: -8px 0 28px rgba(0,0,0,0.18); display: flex; flex-direction: column; animation: olc-slide-in 160ms ease-out; }
@keyframes olc-slide-in { from { transform: translateX(20px); opacity: 0.4; } to { transform: translateX(0); opacity: 1; } }
.olc-thread-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; padding: 10px 14px; border-bottom: 1px solid #ececec; }
.olc-thread-title { font-weight: 600; font-size: 13px; }
.olc-thread-subtitle { font-size: 11px; color: #666; margin-top: 2px; word-break: break-all; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
.olc-thread-sub2 { font-size: 11px; color: #888; margin-top: 2px; }
.olc-thread-headbtns { display: flex; gap: 4px; flex: 0 0 auto; }
.olc-thread-body { flex: 1; min-height: 0; display: flex; flex-direction: column; }
.olc-thread-empty { padding: 16px; color: #888; text-align: center; font-style: italic; }
.olc-thread-list { list-style: none; margin: 0; padding: 4px 0; }
.olc-comment { padding: 8px 14px; border-bottom: 1px solid #f3f3f3; }
.olc-comment:hover { background: #fafbff; }
.olc-comment-head { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; }
.olc-comment-author { font-weight: 600; font-size: 12px; color: #333; }
.olc-comment-when { font-size: 10px; color: #999; white-space: nowrap; }
.olc-comment-badge { font-size: 9px; color: #6b7280; padding: 1px 5px; background: #f3f4f6; border-radius: 8px; margin-left: 6px; }
.olc-comment-body { white-space: pre-wrap; font-size: 12px; color: #222; line-height: 1.4; margin-top: 3px; word-wrap: break-word; }
.olc-comment-actions { display: flex; gap: 2px; margin-top: 4px; opacity: 0; transition: opacity 100ms; }
.olc-comment:hover .olc-comment-actions { opacity: 1; }
.olc-thread-compose { display: flex; align-items: flex-end; gap: 6px; padding: 8px 10px; border-top: 1px solid #ececec; }
.olc-thread-compose textarea { flex: 1; font: inherit; font-size: 12px; padding: 5px 7px; border: 1px solid #c8c8c8; border-radius: 4px; resize: none; max-height: 120px; min-height: 34px; outline: none; box-sizing: border-box; }
.olc-thread-compose textarea:focus { border-color: #1d4ed8; }
.olc-thread-readonly { padding: 8px 14px; font-size: 11px; color: #888; border-top: 1px solid #ececec; }
.olc-inline-edit { display: flex; flex-direction: column; gap: 4px; }
.olc-inline-edit textarea { font: inherit; font-size: 12px; padding: 5px 7px; border: 1px solid #1d4ed8; border-radius: 3px; resize: vertical; min-height: 48px; outline: none; width: 100%; box-sizing: border-box; }
.olc-inline-edit-actions { display: flex; gap: 4px; justify-content: flex-end; }
.olc-inline-edit-actions button { font: inherit; font-size: 11px; padding: 2px 10px; border: 1px solid #ccc; background: #fff; border-radius: 3px; cursor: pointer; }
.olc-inline-edit-actions button.primary { background: #1d4ed8; color: #fff; border-color: #1d4ed8; }
.olc-inline-edit-actions button:disabled { opacity: 0.5; cursor: default; }

/* ─── People panel ─── */
.olc-people-panel { width: min(560px, 94%); height: 100%; background: #fff; border-left: 1px solid #c8c8c8; box-shadow: -8px 0 28px rgba(0,0,0,0.18); display: flex; flex-direction: column; }
.olc-people-head { display: flex; align-items: center; justify-content: space-between; padding: 8px 12px; border-bottom: 1px solid #e3e3e3; }
.olc-people-title { font-weight: 600; }
/* Flex rather than a fixed grid: this bar is reused by the audit panel (4 controls) and the
   people form (6, since Companies joined), and a hard-coded column count clipped the extra one. */
.olc-people-add { display: flex; flex-wrap: wrap; gap: 6px; padding: 8px 12px; border-bottom: 1px solid #e3e3e3; }
.olc-people-add .olc-input { flex: 1 1 110px; min-width: 0; }
.olc-people-add .olc-btn { flex: 0 0 auto; }
.olc-people-note { padding: 8px 12px; background: #fff8e1; border-bottom: 1px solid #e3e3e3; color: #5d4037; font-size: 11px; line-height: 1.45; }
.olc-people-note code { background: #f2e6c9; padding: 0 3px; border-radius: 2px; }
.olc-people-body { flex: 1; min-height: 0; display: flex; flex-direction: column; }
.olc-people-list { padding-bottom: 4px; }
.olc-person-row { display: grid; grid-template-columns: 1fr auto; gap: 8px; align-items: center; padding: 7px 12px; border-bottom: 1px solid #f0f0f0; }
.olc-person-row.inactive { color: #888; background: #fafafa; }
.olc-person-view { display: flex; align-items: center; gap: 6px; }
.olc-person-display { font-weight: 500; }
.olc-person-edit-btn { padding: 1px 8px; font-size: 11px; }
.olc-person-sub { color: #666; font-size: 10px; margin-top: 2px; }
.olc-person-edit { display: flex; flex-wrap: wrap; gap: 4px; align-items: center; }
.olc-person-edit .olc-input { width: 150px; }
.olc-person-edit-actions { display: flex; gap: 4px; }
.olc-person-edit-error { flex-basis: 100%; color: #b00020; font-size: 11px; margin-top: 2px; }
.olc-person-actions { display: flex; flex-direction: column; align-items: flex-end; gap: 3px; }
.olc-person-actions-row { display: flex; align-items: center; gap: 6px; }
.olc-person-action-note { color: #555; font-size: 10px; text-align: right; max-width: 260px; }
.olc-person-action-error { color: #b00020; font-size: 11px; text-align: right; max-width: 260px; }
.olc-btn-danger { color: #b00020; border-color: #d9a2ab; }

/* ─── Company picker (People panel) ─── */
.olc-company-btn { display: inline-flex; align-items: center; justify-content: space-between; gap: 6px; cursor: pointer; text-align: left; white-space: nowrap; }
.olc-company-btn:hover:not(:disabled) { border-color: #7aa7ff; }
.olc-company-btn:disabled { color: #999; background: #f7f7f7; cursor: default; }
.olc-company-btn.empty .olc-company-btn-label { color: #999; font-style: italic; }
.olc-company-btn-label { overflow: hidden; text-overflow: ellipsis; }
.olc-company-caret { flex: 0 0 auto; color: #888; font-size: 9px; }
.olc-company-menu { position: fixed; z-index: 60; width: 210px; background: #fff; border: 1px solid #c8c8c8; box-shadow: 0 4px 14px rgba(0,0,0,0.18); border-radius: 4px; font-size: 12px; display: flex; flex-direction: column; overflow: hidden; }
.olc-company-menu-head { display: flex; align-items: center; justify-content: space-between; padding: 5px 8px; border-bottom: 1px solid #eee; font-weight: 600; font-size: 11px; color: #444; }
.olc-company-menu-acts { display: flex; gap: 6px; }
.olc-linkbtn { border: none; background: none; color: #1d4ed8; font: inherit; font-size: 11px; padding: 0; cursor: pointer; }
.olc-linkbtn:hover:not(:disabled) { text-decoration: underline; }
.olc-linkbtn:disabled { color: #aaa; cursor: default; }
.olc-company-menu-list { max-height: 190px; overflow-y: auto; padding: 2px 0; }
.olc-company-opt { display: flex; align-items: center; gap: 7px; padding: 4px 8px; cursor: pointer; }
.olc-company-opt:hover { background: #f0f4ff; }
.olc-company-cb { position: absolute; opacity: 0; width: 0; height: 0; }
.olc-company-code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
.olc-company-none { padding: 8px; color: #999; font-style: italic; font-size: 11px; }
.olc-company-menu-add { display: flex; gap: 4px; padding: 5px 8px; border-top: 1px solid #eee; }
.olc-company-menu-add .olc-input { flex: 1 1 auto; min-width: 0; font-size: 11px; }
.olc-company-menu-foot { padding: 4px 8px; border-top: 1px solid #eee; background: #fafafa; color: #666; font-size: 10px; line-height: 1.35; }

/* ─── Row-count status bar ─── */
.olc-statusbar { flex: 0 0 auto; display: flex; align-items: center; gap: 10px; padding: 3px 8px; border-top: 1px solid #e3e3e3; background: #fafafa; color: #666; font-size: 11px; }
.olc-statusbar-warn { color: #a15c00; background: #fff4e0; border: 1px solid #f0d6a8; border-radius: 3px; padding: 0 5px; }
`;
