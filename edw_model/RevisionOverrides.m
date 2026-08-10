// RevisionOverrides — user writeback from the Revision Log Editor custom visual.
// Reads the per-revision-event override record (reason overwrite / note / exclude)
// from the michelman-writeback Cloudflare Worker (D1 `revision_overrides` table).
//
// CONNECTION-ONLY helper (do not load as a model table): FactScheduleChange.m
// buffers and left-joins this on [RevisionKey] so the overrides fold into the
// fact at refresh. Live edits reach the visual directly via its ~20s poll; this
// query only matters for refresh-time fold-back into OTIF.
//
// RevisionKey format (must stay identical to the M expression in
// FactScheduleChange.m that builds it — the visual treats it as opaque):
//   <Order Line ID> & "|" & <ChangeDate yyyy-MM-dd> & "|" & <ChangeTime integer>
//   e.g. "00010,74,CM,4.000|2026-03-14|143502"
//
// The shared secret lives in this file (same threat model as DeliveryReliability:
// internal tenant-gated report; rotate the worker secret if it leaks).
let
    BaseUrl = "https://michelman-writeback.michelman-bi.workers.dev",
    Secret  = "2dd9c06c0d1c63e82ee7740c3ac61be1c5ec14c2455bbd45e97c67995a5ecf2c",

    Source = Json.Document(
        Web.Contents(
            BaseUrl,
            [
                RelativePath = "revision-overrides",
                Headers = [ #"x-secret" = Secret ]
            ]
        )
    ),

    // Source is { revisionKey: { revisionReason, note, excludeFlag, ... } }.
    AsTable = Record.ToTable(Source),
    Expanded = Table.ExpandRecordColumn(
        AsTable,
        "Value",
        {"revisionReason", "note", "excludeFlag"},
        {"RevisionReasonOverride", "OverrideNote", "Excluded"}
    ),
    Keyed = Table.RenameColumns(Expanded, {{"Name", "RevisionKey"}}),

    Typed = Table.TransformColumnTypes(
        Keyed,
        {
            {"RevisionKey", type text},
            {"RevisionReasonOverride", type text},
            {"OverrideNote", type text},
            {"Excluded", type logical}
        }
    ),

    Filtered = Table.SelectRows(Typed, each [RevisionKey] <> null and Text.Trim([RevisionKey]) <> "")
in
    Filtered
