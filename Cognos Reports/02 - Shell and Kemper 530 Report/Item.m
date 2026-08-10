// ============================================================================
// Report 03 - CM Sales Orders < 560 (Not Enough Inventory to Ship)
// TABLE: Item  ->  the master-detail BRIDGE (the "one" side of the 1->* rels to
//        SO_Not_Shipping / Inventory_Availability / WorkOrder_Detail on [Item]).
//
// WAS a DAX calculated table (DISTINCT(SO_Not_Shipping[Item])). That failed to
// load in a never-refreshed PBIP: a calculated table's columns only materialize
// AFTER a data refresh, so at load time Item[Item] had no compiled column and the
// relationships to it were invalid ("Relationship ... uses an invalid column ID").
// Rebuilt as an IMPORT (Power Query) table so the [Item] column exists at load
// time with no DAX evaluation required.
//
// SEMANTICS PRESERVED: the dimension is still exactly DISTINCT(SO_Not_Shipping
// items) -- this native query replicates SO_Not_Shipping's FROM/JOIN/WHERE and
// SELECTs DISTINCT the item. Inventory/WO rows for items with no short open SO
// map to no dimension row and are filtered out (the master-detail intent).
//
// SELF-CONTAINED: own Sql.Database source (does NOT reference the other queries)
// so it stays firewall-safe. Native T-SQL, folds. No WITH/CTE, no ORDER BY.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT DISTINCT
            LTRIM(RTRIM(so.SDLITM))                                  AS [Item]
        FROM PRODDTA.F4211 so
        INNER JOIN PRODDTA.F0101 shipto ON so.SDSHAN = shipto.ABAN8
        INNER JOIN PRODDTA.F0101 soldto ON so.SDAN8  = soldto.ABAN8
        INNER JOIN PRODDTA.F0010 comp   ON so.SDKCOO = comp.CCCO
        WHERE so.SDNXTR IN ('525','530','535','536','537','540','545','550')
          AND so.SDLNTY = 'S'
          AND LTRIM(RTRIM(so.SDLITM)) IN (
                '161017CX-FD','161017CX-OP','161190PX-T2','161190PX-T3','171143PX-T2',
                '191245PX-T2','APT10','APT10-T2','APT11','APT11-T2','BPADA','BTDA','BYK3565',
                'C2','CAN','CORNERB','CRTNCLEAR','CRTNDARK','CRTNWHITE','DMAEMA','DMEA',
                'DPE3500-T2','EMA3065','FERSUL7W','GEN926','HP1432AT-OP','HP1632','HP1632-T2',
                'HP1632-T2*OP10','IND139','KOH50','MD4020-C1','MD4020-C2','MD4020C-C2','MD4021',
                'MD4021-C1','MD4021-C2','MD4021C-C2','MD4022','MD4022C-C2','MD4023','MD4023-C2',
                'MD4023C-C2','MDU20-T2','MPD','MW40504','MW40504-C2','MW40514','MW40514-C2',
                'NS41-PL','PEG1450','PEG1450.S','PERSD','PTMG','STODSO','TC275','THERMOT','THF',
                'U1001-OP','U101-OP','U201-T2','U2022-OP','U2023-OP','U204-OP','U204-T2','U470-OP',
                'U501B','U501B-OP','U501-OP','U502.E','U502-OP','U601-OP','U701-OP','UNYTE201',
                'UNYTEC201-FD','WAH12MDI','WAV501','WD40','WD40-SP','WD40-UN','JS037-OP','HP401-OP',
                'HSCF410-PL','UNYTEC201-FD'
              )
          AND (so.SDLOTN IS NULL OR LTRIM(RTRIM(so.SDLOTN)) = '')
          AND (CASE WHEN so.SDPDDJ > 0
                    THEN DATEADD(DAY, (so.SDPDDJ % 1000) - 1, DATEFROMPARTS(1900 + (so.SDPDDJ / 1000), 1, 1))
               END) <= DATEADD(DAY, 21, CAST(GETDATE() AS date))
          AND LTRIM(RTRIM(so.SDMCU)) IN ('CINC','CIN2','CIN4')
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Item", type text}
        }
    )
in
    Typed
