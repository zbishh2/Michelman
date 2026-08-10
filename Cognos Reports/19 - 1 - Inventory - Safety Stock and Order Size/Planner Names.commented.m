// ============================================================================
// Report 19 - "1 - Inventory - Safety Stock and Order Size" - PLANNER NAMES
// COMMENTED MASTER. The shipped file is "Planner Names.m" (comment-free, repo
// rule CLAUDE.md §1). Maintain the two in parallel.
//
// A hidden lookup table. It exists for ONE column: the Safety Stock sheet's
// [Planner Name], which BUILD.md §3.4 trap 3 records as differing from EDW on
// ALL 177 rows.
//
//     Cognos                EDW [Planner Name]
//     Murphy, Lance  (72)   Lance Murphy    (72)
//     Howe, Dave     (55)   Dave Howe       (55)
//     Desjardin, Laurent (24) Laurent Desjardin (24)
//     Lee, Wen Wei   (11)   Wen Wei Lee     (11)
//     Bertrand, Joel  (9)   Joel Bertrand   (8)   <- EDW keeps the diaeresis
//     Hanlon, Tammy   (6)   Tammy Hanlon    (6)
//     -                     Lise Jacquet    (1)   <- the V18 drift row
//
// EDW's [Planner Name] matches F0101.ABALPH on only 117 of 93,054 rows - it is
// a normalised re-ordering, not the source string. Taking the name straight
// from ODS.PRODDTA.F0101.ABALPH reproduces BOTH the 'Last, First' ordering AND
// the ASCII spelling Cognos renders, in one step. Confirmed at build time
// against the mirror (BUILD.md V32): the seven names come back exactly as
// Cognos prints them, 'Bertrand, Joel' included.
//
// ##### WHY THIS IS A SEPARATE TABLE AND NOT A JOIN #####
// BUILD.md §3.4 trap 3 specifies "one LEFT JOIN on a 177-row table" against
// ODS.PRODDTA.F0101 - which reads as a cross-database join inside query 1.
// It cannot be: EDW and ODS are on DIFFERENT SERVERS (CLAUDE.md §2 -
// Sql.Database("EDWPROD","EDW") vs Sql.Database("ODSPROD","ODS")), so a
// three-part name in the query-1 native SQL would need a linked server we
// cannot verify and that no other .m in this repo relies on (66 files use
// ODSPROD, 16 use EDWPROD, ZERO use both).
//
// So the join moves into the model, which is where a cross-source join belongs
// here anyway:
//   * this .m is a plain projection - the house one-.m-per-table convention;
//   * a relationship Safety Stock[Planner Number] -> Planner Names[Planner
//     Number] carries it (ABAN8 is unique on all 37,337 F0101 rows, so no
//     fan-out);
//   * the displayed value is the DAX calculated column Safety Stock[Planner
//     Name], which is where BUILD.md §5 wants a rendering rule to live.
// It also avoids a Power Query cross-source MERGE, which would drag in the
// Formula.Firewall privacy-level problem for no benefit.
//
// The spec's stated alternative - a 7-row CASE in the SQL - was rejected for
// the reason the spec itself gives: it rots the first time a planner changes.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        SELECT
            ab.ABAN8                    AS [Planner Number],
            LTRIM(RTRIM(ab.ABALPH))     AS [Planner Name (JDE)]
        FROM PRODDTA.F0101 ab WITH (NOLOCK)

        -- Restricted to address-book records that actually act as a planner on
        -- an item-branch in the six branch plants. Entirely ODS-side, so it
        -- stays a single-server query; 57 rows against the mirror, versus
        -- 37,337 for an unrestricted F0101 pull.
        --
        -- Deliberately wider than the 177-row query-1 filter set (no
        -- SafetyStock / Stocking Type / MPF predicates): those live in EDW and
        -- cannot be referenced from here, and a planner set that tracked them
        -- would silently lose a name the moment an item's safety stock changed.
        -- All 177 query-1 planner numbers resolve inside this set (V32).
        WHERE ab.ABAN8 IN (
                  SELECT ibp.IBANPL
                  FROM PRODDTA.F4102 ibp WITH (NOLOCK)
                  WHERE LTRIM(RTRIM(ibp.IBMCU)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
              )
        ",
        null,
        [EnableFolding = false]
    )
in
    Data

// ----------------------------------------------------------------------------
// OPEN QUESTION (BUILD.md §11 Q7): confirm the recipient actually wants
// 'Last, First'. We reproduce Cognos because parity is the deliverable, but it
// is a one-line change either way - drop this table and the relationship, and
// point the DAX calculated column at [Planner Name (EDW)].
// ----------------------------------------------------------------------------
