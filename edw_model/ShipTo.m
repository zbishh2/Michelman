// Ship-To — ship-to address dimension. Provides the ship-to customer name and
// the TRUE geography (City / State / Country) for mapping, independent of the
// JDE order-company region rollup.
//
// Source: EDWPROD / EDW / dbo.DimAddress. Joined to Orders on the surrogate key.
// Relationship: Orders[ShipToAddressSKey] * -> 1 Ship-To[AddressSKey] (active).
//
// Customer Segmentation rides the EXISTING DimAddress join — no new relationship.
// This is the SHIP-TO-level segmentation (per address).
// ⚠ Segmentation does NOT exist on dbo.DimAddress — it lives only on the BIQL view
// BIQL.DimAddress, hence the LEFT JOIN on AddressSKey (same EDW database,
// cross-schema; folds server-side). It assumes BIQL.DimAddress is 1 row per
// AddressSKey and shares the dbo key space; if the row count jumps, dedupe the
// BIQL side.
// ⚠ Open: if the old Cognos report keyed segmentation off SOLD-TO or PARENT
// customer, those can differ — that reading joins BIQL.DimCustomer on
// Orders[SoldToCustomerSKey] / [ParentCustomerSKey] -> CustomerSKey instead (the
// same two columns live there). Confirm the grain with Jessica before locking.
let
    Source = Sql.Database(
        "EDWPROD",
        "EDW",
        [Query = "
SELECT
    a.AddressSKey,
    a.MailingName              AS [Ship-To Name],
    a.MailAddressCity          AS [City],
    a.MailAddressState         AS [State],
    a.MailAddressStateDesc     AS [State Desc],
    a.MailAddressCountry       AS [Country],
    a.MailAddressCountryDesc   AS [Country Desc],
    b.CustomerSegmentation     AS [Customer Segmentation Code],
    b.CustomerSegmentationDesc AS [Customer Segmentation]
FROM dbo.DimAddress a
LEFT JOIN BIQL.DimAddress b ON b.AddressSKey = a.AddressSKey
"]
    )
in
    Source
