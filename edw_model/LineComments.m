// LineComments — user writeback from the Order Line Comments custom visual.
// Pulls the LATEST non-deleted comment per sales order line plus the exact
// comment count from the michelman-writeback Cloudflare Worker (D1
// `line_comments` table), so comments are visible to export/DAX/tooltips.
// The full thread lives only in the visual (GET /comments/thread).
//
// LOAD as a model table. Relationship (add via MCP):
//   LineComments[Order Line ID]  * -> 1  Orders[Order Line ID]
// (in practice 1:1 — one row per line that has at least one comment).
//
// The shared secret lives in this file (same threat model as DeliveryReliability:
// internal tenant-gated report; rotate the worker secret if it leaks).
let
    BaseUrl = "https://michelman-writeback.michelman-bi.workers.dev",
    Secret  = "2dd9c06c0d1c63e82ee7740c3ac61be1c5ec14c2455bbd45e97c67995a5ecf2c",
    Headers = [ #"x-secret" = Secret ],

    // { orderLineId: { id, body, actorEmail, createdAt, updatedAt } }
    LatestRaw = Json.Document(Web.Contents(BaseUrl, [RelativePath = "comments/latest", Headers = Headers])),
    Latest = Table.ExpandRecordColumn(
        Record.ToTable(LatestRaw),
        "Value",
        {"body", "actorEmail", "createdAt"},
        {"Latest Comment", "Latest Comment By", "Latest Comment At"}
    ),

    // { orderLineId: count } — non-deleted comments per line.
    CountsRaw = Json.Document(Web.Contents(BaseUrl, [RelativePath = "comments/counts", Headers = Headers])),
    Counts = Table.RenameColumns(Record.ToTable(CountsRaw), {{"Name", "Order Line ID"}, {"Value", "Comment Count"}}),

    Joined = Table.NestedJoin(Counts, {"Order Line ID"}, Latest, {"Name"}, "latest", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "latest", {"Latest Comment", "Latest Comment By", "Latest Comment At"}),

    Typed = Table.TransformColumnTypes(
        Expanded,
        {
            {"Order Line ID", type text},
            {"Comment Count", Int64.Type},
            {"Latest Comment", type text},
            {"Latest Comment By", type text},
            {"Latest Comment At", type datetime}
        }
    ),

    Filtered = Table.SelectRows(Typed, each [Order Line ID] <> null and Text.Trim([Order Line ID]) <> "")
in
    Filtered
