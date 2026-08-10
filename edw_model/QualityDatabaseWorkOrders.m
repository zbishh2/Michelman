// QualityDatabaseWorkOrders.m -- COMMENTED MASTER for the 'Quality Database WOs' table.
// The shipped copy lives in the PBIP partition and carries no comments.
//
// WHAT THIS IS
// The batch denominator the business currently measures to. It is NOT an EDW query: it is a
// frozen extract of the `work_order_Detail` table inside the client's own Quality Database
// PBIX, which sources a hand-maintained workbook on a file share:
//
//     \\Kaylee\shared\IT\Power BI Data\Power BI Data Drops\America's Production Dashboard\
//         Work Order Detail.xlsx
//
// Their Right Time First Batch is
//     1 - DIVIDE( COUNTA('Quality Control Database'[OOO/NCB]), COUNTA(work_order_Detail[WO Number]) )
// so that table IS their denominator, one row per counted batch.
//
// WHY IT IS IN OUR MODEL
// To prove the tie-out on the Tie-Out page rather than assert it, and to let the team click a
// month and see the specific work orders their process drops. It is evidence, not a data source
// for any KPI -- nothing outside the Tie-Out page reads this table.
//
// ⚠ A LOCAL FILE, NOT THE SHARE, AND IT MUST STAY THAT WAY. The share path above is reachable
// only from inside the Michelman network, and the workbook is overwritten in place every month.
// Pointing at it would fail to refresh here AND destroy the thing being demonstrated the next
// time somebody updates it. A frozen extract is what keeps the tie-out reproducible.
//
// SCOPE: 2024 onward, 18,434 rows. Their sheet reaches back to 2017, but WorkOrders only carries
// 2024 onward, so earlier rows tie to nothing and are left out.
//
// ⚠ TYPES ARE FIXED IN THE EXTRACT FILE, NOT HERE. Their `Completion Date` is text in M/D/YYYY,
// and parsing that in M would depend on the locale of whichever machine refreshes. The extract
// writes real dates, so this query only names the type, never guesses it.
//
// PATH RESOLUTION -- the one thing that can break a refresh.
// This laptop is user `Zack`; the jumpbox is `ZackB`; the OneDrive library is synced to both. Any
// hardcoded profile fails on one of them. So: try the two known paths, then every profile under
// C:\Users, and take the first that opens. If none does, return an EMPTY TABLE OF THE RIGHT SHAPE
// rather than raising -- a missing evidence file should leave the Tie-Out page blank, not fail the
// refresh of a production dashboard. Check the page after a refresh; blank means unresolved path.

let
    RelPath =
        "\Michelman Inc\PBI Dashboard - LeanGo - General\PowerBI Projects\_Tie Out\Quality Database Work Orders.xlsx",

    Known =
        {
            "C:\Users\Zack"  & RelPath,
            "C:\Users\ZackB" & RelPath
        },

    // Every other profile on the machine, so a third machine needs no edit here.
    Profiles =
        try
            List.Transform(
                Table.SelectRows( Folder.Contents( "C:\Users" ), each [Attributes]?[Directory]? = true )[Name],
                each "C:\Users\" & _ & RelPath
            )
        otherwise
            {},

    Candidates = List.Distinct( List.Combine( { Known, Profiles } ) ),

    Opened =
        List.Transform(
            Candidates,
            each
                try
                    Excel.Workbook( File.Contents( _ ), null, true ){[Item = "QualityDatabaseWO", Kind = "Sheet"]}[Data]
                otherwise
                    null
        ),

    Found = List.Select( Opened, each _ <> null ),

    // Declared once so the empty fallback and the real load are the same shape.
    Schema =
        type table
        [
            #"Sheet Row"                 = Int64.Type,
            #"WO Number"                 = Int64.Type,
            #"Sheet Year"                = Int64.Type,
            #"Sheet Month"               = Int64.Type,
            #"Sheet Month Start"         = date,
            #"Sheet Completion Date"     = date,
            Region                       = text,
            #"Branch Plant"              = text,
            Location                     = text,
            #"Item Number"               = text,
            #"Global Bulk Item"          = text,
            #"Product Family"            = text,
            #"Work Center"               = text,
            #"Standard Work Center"      = text,
            #"WO Completed KGs"          = number,
            #"WO Requested KGs"          = number,
            #"Duplicate Work Order Catch" = text,
            #"Within Date Range"         = text,
            #"Unique ID"                 = text
        ],

    Result =
        if List.IsEmpty( Found ) then
            #table( Schema, {} )
        else
            Table.TransformColumnTypes(
                Table.PromoteHeaders( List.First( Found ), [PromoteAllScalars = true] ),
                {
                    { "Sheet Row",                  Int64.Type },
                    { "WO Number",                  Int64.Type },
                    { "Sheet Year",                 Int64.Type },
                    { "Sheet Month",                Int64.Type },
                    { "Sheet Month Start",          type date },
                    { "Sheet Completion Date",      type date },
                    { "Region",                     type text },
                    { "Branch Plant",               type text },
                    { "Location",                   type text },
                    { "Item Number",                type text },
                    { "Global Bulk Item",           type text },
                    { "Product Family",             type text },
                    { "Work Center",                type text },
                    { "Standard Work Center",       type text },
                    { "WO Completed KGs",           type number },
                    { "WO Requested KGs",           type number },
                    { "Duplicate Work Order Catch", type text },
                    { "Within Date Range",          type text },
                    { "Unique ID",                  type text }
                }
            )
in
    Result
