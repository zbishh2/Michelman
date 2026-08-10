// The visual's full stylesheet, injected into the sandbox via a <style> element
// in the Visual constructor. Prefixed "rle-" (Revision Log Editor). Adapted from
// the DeliveryReliability visual's inline CSS.

export const CSS = `
.rle-container { height: 100%; overflow: hidden; font: 12px -apple-system, Segoe UI, Roboto, sans-serif; color: #222; }
.rle-root { display: flex; flex-direction: column; height: 100%; }
.rle-header { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 4px 6px; }
.rle-title { font-weight: 600; }
.rle-actions { display: flex; align-items: center; gap: 6px; }
.rle-legend-item { display: inline-flex; align-items: center; gap: 5px; border: 1px solid transparent; background: transparent; color: #555; font: inherit; font-size: 11px; padding: 2px 6px; border-radius: 3px; cursor: pointer; }
.rle-legend-item:hover { border-color: #c8c8c8; background: #f7f7f7; }
.rle-legend-item.on { border-color: #7aa7ff; background: #eef3ff; }
.rle-legend-swatch { display: inline-flex; align-items: center; justify-content: center; width: 12px; height: 12px; border: 1px solid #c8c8c8; border-radius: 2px; line-height: 1; }
.rle-legend-check { font-size: 10px; color: #1f6f1f; font-weight: 700; }
.rle-legend-edited { background: #fff; box-shadow: inset 3px 0 0 #1f6fdf; }
.rle-ctx-menu { position: fixed; z-index: 50; background: #fff; border: 1px solid #c8c8c8; box-shadow: 0 2px 8px rgba(0,0,0,0.15); border-radius: 3px; padding: 3px 0; min-width: 130px; display: flex; flex-direction: column; }
.rle-ctx-item { border: 0; background: transparent; color: #222; font: inherit; font-size: 12px; text-align: left; padding: 5px 12px; cursor: pointer; }
.rle-ctx-item:hover, .rle-ctx-item:focus { background: #f0f4ff; outline: none; }
.rle-ctx-item:disabled { color: #aaa; cursor: default; background: transparent; }
.rle-btn { border: 1px solid #c8c8c8; background: #fff; color: #222; font: inherit; font-size: 11px; padding: 2px 8px; border-radius: 3px; cursor: pointer; }
.rle-btn:hover { background: #f0f4ff; border-color: #7aa7ff; }
.rle-btn:active { background: #e2eaff; }
.rle-btn:disabled { color: #999; cursor: default; background: #f7f7f7; }
.rle-icon-btn { border: 0; background: transparent; color: #444; font: inherit; font-size: 18px; line-height: 1; padding: 2px 6px; cursor: pointer; }
.rle-icon-btn:hover { background: #f0f4ff; }
.rle-icon-btn:disabled { color: #bbb; cursor: default; }
.rle-error { padding: 4px 8px; background: #fdecea; color: #b71c1c; font-size: 11px; }
.rle-readonly-note { padding: 3px 8px; background: #f4f6fb; color: #555; font-size: 11px; border-bottom: 1px solid #e3e3e3; }
.rle-empty { padding: 12px; color: #666; }
.rle-modal-backdrop { position: absolute; inset: 0; z-index: 20; background: rgba(255,255,255,0.72); display: flex; justify-content: flex-end; }
.rle-people-panel { width: min(760px, 94%); height: 100%; background: #fff; border-left: 1px solid #c8c8c8; box-shadow: -3px 0 12px rgba(0,0,0,0.12); display: flex; flex-direction: column; }
.rle-people-head { display: flex; align-items: center; justify-content: space-between; padding: 8px 10px; border-bottom: 1px solid #e3e3e3; }
.rle-people-title { font-weight: 600; }
.rle-people-add { display: grid; gap: 6px; padding: 8px 10px; border-bottom: 1px solid #e3e3e3; }
.rle-people-input, .rle-people-select { min-width: 0; border: 1px solid #c8c8c8; background: #fff; color: #222; font: inherit; padding: 3px 5px; border-radius: 3px; }
.rle-people-list { padding-bottom: 4px; }
.rle-person-row { display: grid; grid-template-columns: minmax(150px, 1fr) auto; gap: 6px; align-items: center; padding: 6px 10px; border-bottom: 1px solid #f0f0f0; }
.rle-person-row.inactive { color: #777; background: #fafafa; }
.rle-person-name { overflow-wrap: anywhere; }
.rle-person-name-input { border: 1px solid #c8c8c8; background: #fff; color: inherit; font: inherit; padding: 2px 4px; border-radius: 3px; box-sizing: border-box; width: 170px; }
.rle-person-name-input:focus { border-color: #7aa7ff; outline: none; }
.rle-person-sub { color: #666; font-size: 10px; margin-top: 1px; }
.rle-person-active { display: flex; align-items: center; gap: 4px; }
.rle-person-view { display: flex; align-items: center; gap: 6px; }
.rle-person-display { font-weight: 500; flex: 1; min-width: 0; overflow-wrap: anywhere; }
.rle-person-edit-btn { padding: 1px 8px; font-size: 11px; }
.rle-person-admin-view { color: #555; font-size: 10px; margin-top: 2px; display: flex; gap: 8px; flex-wrap: wrap; }
.rle-person-role-view { text-transform: capitalize; }
.rle-person-edit { display: flex; flex-wrap: wrap; gap: 4px; align-items: center; }
.rle-person-edit-actions { display: flex; gap: 4px; }
.rle-person-edit-error { flex-basis: 100%; color: #b00020; font-size: 11px; margin-top: 2px; }
.rle-person-actions { display: flex; flex-direction: column; align-items: flex-end; gap: 3px; }
.rle-person-actions-row { display: flex; align-items: center; gap: 6px; }
.rle-person-action-note { color: #555; font-size: 10px; text-align: right; max-width: 260px; }
.rle-person-action-error { color: #b00020; font-size: 11px; text-align: right; max-width: 260px; }
.rle-btn-danger { color: #b00020; border-color: #d9a2ab; }
.rle-reason-row { display: grid; grid-template-columns: 110px minmax(120px, 1fr) 28px 28px 72px auto; gap: 6px; align-items: center; padding: 5px 10px; border-bottom: 1px solid #f0f0f0; }
.rle-reason-row.inactive { color: #888; background: #fafafa; }
.rle-scroll-pane { position: relative; flex: 1 1 auto; min-width: 0; min-height: 0; overflow: hidden; }
.rle-scroll-inner { width: 100%; height: 100%; min-width: 0; overflow: auto; scrollbar-width: none; -ms-overflow-style: none; }
.rle-scroll-inner.has-h { height: calc(100% - 10px); }
.rle-scroll-inner.has-v { width: calc(100% - 10px); }
.rle-scroll-inner::-webkit-scrollbar { display: none; width: 0; height: 0; }
.rle-htrack { position: absolute; bottom: 0; left: 0; right: 0; height: 10px; z-index: 10; }
.rle-hthumb { position: absolute; bottom: 2px; height: 6px; background: rgba(0,0,0,0.30); border-radius: 3px; cursor: pointer; }
.rle-hthumb:hover, .rle-hthumb.dragging { background: rgba(0,0,0,0.55); }
.rle-vtrack { position: absolute; top: 0; right: 0; bottom: 0; width: 10px; z-index: 10; }
.rle-vthumb { position: absolute; right: 2px; width: 6px; background: rgba(0,0,0,0.30); border-radius: 3px; cursor: pointer; }
.rle-vthumb:hover, .rle-vthumb.dragging { background: rgba(0,0,0,0.55); }
.rle-table { border-collapse: collapse; width: max-content; min-width: 100%; }
.rle-table th, .rle-table td { border-bottom: 1px solid #e3e3e3; border-right: 1px solid #f0f0f0; padding: 4px 2px; text-align: left; vertical-align: top; max-width: 250px; white-space: pre-wrap; word-break: break-word; overflow-wrap: anywhere; }
.rle-table th { position: sticky; top: -1px; background: #f7f7f7; font-weight: 600; z-index: 5; user-select: none; }
.rle-table th.rle-frozen-col { z-index: 6; }
.rle-table td.rle-frozen-col { position: sticky; z-index: 2; background: #fff; }
.rle-table tr:hover td { background: #f9fbff; }
.rle-table tr:hover td.rle-frozen-col { background: #f9fbff; }
.rle-table tr.rle-row-edited td:first-child { box-shadow: inset 3px 0 0 #1f6fdf; }
.rle-table .rle-frozen-boundary { box-shadow: 2px 0 3px rgba(0,0,0,0.12); }
.rle-table td.num, .rle-table th.num { text-align: right; }
.rle-draggable-th { cursor: grab; }
.rle-draggable-th:active { cursor: grabbing; }
.rle-sort-indicator { color: #555; font-size: 10px; }
.rle-resizer { position: absolute; top: 0; right: 0; width: 6px; height: 100%; cursor: col-resize; user-select: none; }
.rle-resizer:hover, .rle-resizer.active { background: #b8d4ff; }
.rle-th-inner { position: relative; display: flex; align-items: flex-start; gap: 2px; padding-right: 6px; }
.rle-th-label { flex: 1 1 auto; min-width: 0; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; word-break: break-word; line-height: 1.15; }
.rle-table th.num .rle-th-label { text-align: right; }
.rle-th-inner > .rle-sort-indicator, .rle-th-inner > .rle-th-filter-icon, .rle-th-inner > .rle-th-menu-caret { flex: 0 0 auto; }
.rle-th-menu-caret { color: #b0b0b0; font-size: 9px; margin-left: 3px; }
.rle-th-filter-icon { color: #2b6cb0; font-size: 10px; margin-left: 3px; }
.rle-cell-select { position: relative; width: 100%; }
.rle-cell-select-btn { border: 1px solid transparent; background: transparent; font: inherit; color: inherit; padding: 2px 4px; width: 100%; text-align: left; cursor: pointer; display: flex; align-items: flex-start; gap: 4px; min-height: 22px; }
.rle-cell-select-btn:hover, .rle-cell-select-btn:focus { border-color: #c8c8c8; background: #fff; outline: none; }
.rle-cell-select-btn[disabled] { cursor: default; color: #999; }
.rle-cell-select-val { flex: 1; white-space: pre-wrap; word-break: break-word; overflow-wrap: anywhere; }
.rle-cell-select-caret { flex: 0 0 auto; color: #888; font-size: 10px; line-height: 1.2; }
.rle-cell-select-menu { position: absolute; top: 100%; left: 0; z-index: 10; min-width: 100%; max-width: 280px; background: #fff; border: 1px solid #c8c8c8; box-shadow: 0 2px 6px rgba(0,0,0,0.12); }
.rle-cell-select-search { display: block; box-sizing: border-box; width: 100%; border: 0; border-bottom: 1px solid #e2e2e2; font: inherit; padding: 5px 8px; outline: none; }
.rle-cell-select-search:focus { background: #f7faff; }
.rle-cell-select-list { margin: 0; padding: 2px 0; list-style: none; max-height: 240px; overflow-y: auto; }
/* Custom-drawn scrollbars for inner scroll areas: native composited scrollbars
   blur the layer under the sandbox iframe transform (same Chromium issue the
   ScrollPane overlay bars work around for the grid).
   NOTE: never set scrollbar-width/scrollbar-color here — in modern Chromium they
   disable the ::-webkit-scrollbar rules and force a thin NATIVE scrollbar. */
.rle-cell-select-list::-webkit-scrollbar, .rle-hdr-filter-list::-webkit-scrollbar { width: 8px; height: 8px; }
.rle-cell-select-list::-webkit-scrollbar-track, .rle-hdr-filter-list::-webkit-scrollbar-track { background: transparent; }
.rle-cell-select-list::-webkit-scrollbar-thumb, .rle-hdr-filter-list::-webkit-scrollbar-thumb { background: #c4c4c4; border-radius: 4px; border: 2px solid transparent; background-clip: content-box; }
.rle-cell-select-list::-webkit-scrollbar-thumb:hover, .rle-hdr-filter-list::-webkit-scrollbar-thumb:hover { background: #9e9e9e; border: 2px solid transparent; background-clip: content-box; }
.rle-cell-select-opt { padding: 4px 8px; cursor: pointer; white-space: pre-wrap; word-break: break-word; }
.rle-cell-select-opt:hover { background: #f0f4ff; }
.rle-cell-select-opt.selected { background: #e2eaff; }
.rle-cell-select-empty { color: #999; font-style: italic; }
.rle-cell-notes { border: 1px solid transparent; background: transparent; font: inherit; color: inherit; padding: 2px 4px; width: 100%; max-width: 100%; min-width: 0; box-sizing: border-box; display: block; min-height: 28px; resize: none; overflow: hidden; white-space: pre-wrap; word-wrap: break-word; overflow-wrap: break-word; }
.rle-cell-notes:hover, .rle-cell-notes:focus { border-color: #c8c8c8; background: #fff; outline: none; }
.rle-cell-notes:disabled { color: #999; background: transparent; }
.rle-cell-exclude { display: inline-flex; align-items: center; justify-content: center; cursor: pointer; }
.rle-cell-exclude input { cursor: pointer; }
.rle-cell-exclude input:disabled { cursor: default; }
.rle-table tfoot .rle-totals-cell { position: sticky; bottom: -2px; padding-bottom: 6px; background: #f7f7f7; font-weight: 600; border-top: 2px solid #c8c8c8; border-right: 0; border-bottom: 0; z-index: 5; }
.rle-table tfoot .rle-totals-cell.rle-frozen-col { z-index: 6; }
.rle-history-panel { width: min(440px, 92%); background: #fff; border-left: 1px solid #c8c8c8; box-shadow: -8px 0 28px rgba(0,0,0,0.18); display: flex; flex-direction: column; height: 100%; }
.rle-history-header { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; padding: 12px 14px; border-bottom: 1px solid #ececec; }
.rle-history-title { font-weight: 600; font-size: 13px; }
.rle-history-subtitle { font-size: 11px; color: #666; margin-top: 2px; word-break: break-all; }
.rle-history-body { flex: 1; min-height: 0; display: flex; flex-direction: column; padding: 6px 0; }
.rle-history-empty { padding: 16px; color: #888; text-align: center; font-style: italic; }
.rle-history-error { color: #b00020; font-style: normal; }
.rle-history-list { list-style: none; margin: 0; padding: 0; }
.rle-history-item { padding: 8px 14px; border-bottom: 1px solid #f3f3f3; display: flex; flex-direction: column; gap: 2px; }
.rle-history-when { font-size: 11px; color: #555; }
.rle-history-who { font-size: 11px; color: #777; }
.rle-history-what { display: flex; flex-wrap: wrap; align-items: baseline; gap: 6px; margin-top: 2px; font-size: 12px; }
.rle-history-field { font-weight: 600; color: #333; }
.rle-history-old { color: #999; text-decoration: line-through; max-width: 160px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.rle-history-arrow { color: #888; }
.rle-history-new { color: #1f6f1f; font-weight: 500; max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.rle-audit-head-actions { display: flex; align-items: center; gap: 6px; }
.rle-audit-filters { display: grid; grid-template-columns: minmax(140px, 1fr) 150px auto; gap: 6px; align-items: center; padding: 8px 10px; border-bottom: 1px solid #e3e3e3; }
.rle-audit-search { min-width: 0; }
.rle-audit-since { display: inline-flex; align-items: center; gap: 5px; color: #555; font-size: 11px; white-space: nowrap; }
.rle-audit-notice { padding: 4px 10px; background: #fff8e1; color: #7a5b00; font-size: 11px; border-bottom: 1px solid #f0e4b8; }
.rle-audit-body { flex: 1; min-height: 0; display: flex; flex-direction: column; }
.rle-audit-table { border-collapse: collapse; width: 100%; }
.rle-audit-table th, .rle-audit-table td { text-align: left; vertical-align: top; padding: 6px 10px; border-bottom: 1px solid #f0f0f0; }
.rle-audit-table th { position: sticky; top: 0; background: #f7f7f7; font-weight: 600; font-size: 11px; color: #444; z-index: 1; }
.rle-audit-when { color: #555; white-space: nowrap; }
.rle-audit-who { color: #333; max-width: 160px; overflow: hidden; text-overflow: ellipsis; }
.rle-audit-key { font-family: Consolas, "SF Mono", Menlo, monospace; font-size: 11px; color: #444; }
.rle-audit-field { font-weight: 600; color: #333; white-space: nowrap; }
.rle-audit-change { display: flex; flex-wrap: wrap; align-items: baseline; gap: 6px; }
.rle-audit-empty { padding: 16px 10px; color: #888; text-align: center; font-style: italic; }
.rle-audit-more { display: flex; justify-content: center; padding: 10px; }
.rle-hdr-menu { position: fixed; z-index: 50; width: 248px; background: #fff; border: 1px solid #c8c8c8; box-shadow: 0 4px 14px rgba(0,0,0,0.18); border-radius: 4px; font-size: 12px; display: flex; flex-direction: column; overflow: hidden; }
.rle-hdr-menu-section { padding: 2px 0; border-bottom: 1px solid #eee; display: flex; flex-direction: column; flex: 0 0 auto; }
.rle-hdr-menu-item { border: 0; background: transparent; color: #222; font: inherit; text-align: left; padding: 4px 12px; cursor: pointer; display: flex; align-items: center; gap: 4px; }
.rle-hdr-menu-item:hover:not(:disabled) { background: #f0f4ff; }
.rle-hdr-menu-item:disabled { color: #bbb; cursor: default; }
.rle-hdr-menu-item.active { background: #e2eaff; }
.rle-hdr-chevron { margin-left: auto; color: #888; }
.rle-hdr-filter { display: flex; flex-direction: column; padding: 5px 6px; gap: 4px; border-bottom: 1px solid #eee; flex: 1 1 auto; min-height: 0; overflow: hidden; }
.rle-hdr-filter-search { box-sizing: border-box; width: 100%; border: 1px solid #c8c8c8; border-radius: 3px; font: inherit; padding: 4px 6px; outline: none; flex: 0 0 auto; }
.rle-hdr-filter-search:focus { border-color: #7aa7ff; box-shadow: 0 0 0 2px rgba(122,167,255,0.2); }
.rle-hdr-filter-scroll { flex: 1 1 auto; min-height: 120px; display: flex; }
.rle-hdr-filter-list { list-style: none; margin: 0; padding: 0; }
.rle-hdr-filter-opt { display: flex; align-items: center; gap: 6px; padding: 2px 4px; cursor: pointer; white-space: nowrap; overflow: hidden; }
.rle-hdr-filter-opt:hover { background: #f0f4ff; }
.rle-hdr-filter-empty { color: #999; font-style: italic; cursor: default; }
.rle-hdr-filter-label { overflow: hidden; text-overflow: ellipsis; }
.rle-hdr-check { flex: 0 0 auto; width: 14px; height: 14px; border: 1px solid #b0b0b0; border-radius: 2px; display: inline-flex; align-items: center; justify-content: center; font-size: 10px; line-height: 1; color: #fff; background: #fff; }
.rle-hdr-check.on { background: #2b6cb0; border-color: #2b6cb0; }
.rle-hdr-check.some { background: #9bb8dd; border-color: #9bb8dd; }
.rle-hdr-cond { display: flex; flex-direction: column; gap: 6px; padding: 6px; border-bottom: 1px solid #eee; flex: 0 0 auto; }
.rle-hdr-cond-op, .rle-hdr-cond-val { box-sizing: border-box; width: 100%; border: 1px solid #c8c8c8; border-radius: 3px; font: inherit; padding: 4px 6px; outline: none; }
.rle-hdr-cond-op:focus, .rle-hdr-cond-val:focus { border-color: #7aa7ff; box-shadow: 0 0 0 2px rgba(122,167,255,0.2); }
.rle-hdr-cond-and { color: #888; font-size: 11px; }
.rle-hdr-menu-actions { display: flex; gap: 6px; justify-content: flex-end; padding: 6px; flex: 0 0 auto; }

/* ─── Row-count status bar ─── */
.rle-statusbar { flex: 0 0 auto; display: flex; align-items: center; gap: 10px; padding: 3px 8px; border-top: 1px solid #e3e3e3; background: #fafafa; color: #666; font-size: 11px; }
.rle-statusbar-warn { color: #a15c00; background: #fff4e0; border: 1px solid #f0d6a8; border-radius: 3px; padding: 0 5px; }
`;
