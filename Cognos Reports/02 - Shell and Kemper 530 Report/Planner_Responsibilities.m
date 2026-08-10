// ============================================================================
// Report 02 - Shell and Kemper 530 Report
// Cognos page "Planner Responsibilities" (title "Planner Segregation of Duties").
//
// The Cognos page is a STATIC <table> with no <query> behind it -- five hard-coded
// rows transcribed verbatim from the report spec. Held here as a literal #table so
// the page needs no database round-trip and cannot drift from the source report.
//
// Row order is authored, not alphabetical: Planner sorts by [Ord].
// ============================================================================
let
    Source = #table(
        type table [
            Ord                       = Int64.Type,
            Planner                   = text,
            #"Reactor (FRC / RRC)"    = text,
            #"EC (FEC / REC)"         = text,
            #"Cold Blend (FCB / RCB)" = text,
            #"Bluewave (FBW / RBW)"   = text,
            #"CM (TOL)"               = text,
            PKG                       = text
        ],
        {
            { 1, "Lance",       "",  "",  "CIN2 Only", "",  "ORTC and DANC Only", "CIN2 Only" },
            { 2, "Eric",        "X", "X", "CINC Only", "",  "X",                  "CINC Only" },
            { 3, "Travis",      "",  "",  "",          "X", "",                   "" },
            { 4, "Mark Tilley", "",  "",  "",          "",  "Coaters",            "" }
        }
    )
in
    Source
