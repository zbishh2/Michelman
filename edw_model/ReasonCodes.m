// Reason Codes (live model table name: 'Reason Codes') — the promised-date
// REVISION REASON dimension and the source of truth for which reason codes count
// as an OTIF miss.
//
// SOURCE: the editable D1 reason-code dimension via the michelman-writeback
// Cloudflare Worker (GET /reason-dim, table reason_dim). It is maintained entirely
// in the Reason Code Editor custom visual (writeback/visual-otif-hits — the folder
// name is legacy).
//
// The authoritative flag is [OTIF] = "X" iff the code's `otif` bit is set in D1.
// It drives FactScheduleChange[Is OTIF Relevant] (= UPPER(TRIM(RELATED(
// 'Reason Codes'[OTIF]))) = "X"), so editing a code's OTIF flag in the visual
// reflows the metric on the next refresh with no DAX change.
//
// Columns produced (mapped to the live 'Reason Codes' column objects):
//   Code, Description, Description_1 (long desc), OTIF ("X"/""), Category,
//   Exemption Criteria, Active (logical; 0 = retired / "do not use").
// Relationship: FactScheduleChange[RevisionReason] * -> 1 [Code] (active).
//
// CACHE-BUSTER: a per-refresh Query value (_cb) forces Power Query to re-fetch
// the worker rather than serve a stale cached body — otherwise edits may not
// appear on refresh within a warm mashup session. The worker ignores extra
// query params. The shared secret lives in this file (internal tenant-gated
// report threat model; rotate the worker secret if it leaks).
let
    BaseUrl = "https://michelman-writeback.michelman-bi.workers.dev",
    Secret  = "2dd9c06c0d1c63e82ee7740c3ac61be1c5ec14c2455bbd45e97c67995a5ecf2c",
    Stamp = Text.From(Int64.From(Duration.TotalSeconds(DateTimeZone.UtcNow() - #datetimezone(2020,1,1,0,0,0,0,0)))),

    Raw = Json.Document(
        Web.Contents(
            BaseUrl,
            [
                RelativePath = "reason-dim",
                Query = [ _cb = Stamp ],
                Headers = [ #"x-secret" = Secret ]
            ]
        )
    ),
    AsTable = Table.FromRecords(Raw),

    // Effective OTIF flag: "X" iff otif=true. Keep [Code] as the dimension key.
    Renamed = Table.RenameColumns(
        AsTable,
        {
            {"code", "Code"},
            {"description", "Description"},
            {"longDescription", "Description_1"},
            {"exemptionCriteria", "Exemption Criteria"},
            {"category", "Category"},
            {"active", "Active"}
        }
    ),
    AddOtif = Table.AddColumn(Renamed, "OTIF", each if [otif] = true then "X" else "", type text),
    Selected = Table.SelectColumns(
        AddOtif,
        {"Code", "Description", "Description_1", "OTIF", "Category", "Exemption Criteria", "Active"}
    ),
    Typed = Table.TransformColumnTypes(
        Selected,
        {
            {"Code", type text},
            {"Description", type text},
            {"Description_1", type text},
            {"OTIF", type text},
            {"Category", type text},
            {"Exemption Criteria", type text},
            {"Active", type logical}
        }
    ),
    Filtered = Table.SelectRows(Typed, each [Code] <> null and Text.Trim([Code]) <> "")
in
    Filtered
