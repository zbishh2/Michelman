// Sold-To — sold-to address dimension. Mirror of Ship-To (ShipTo.m): same
// dbo.DimAddress / BIQL.DimAddress source, role-played on the SOLD-TO key instead of
// the ship-to key. Provides the sold-to customer name and TRUE geography
// (City / State / Country) for the ordering party, independent of the JDE
// order-company region rollup.
//
// Source: EDWPROD / EDW / dbo.DimAddress. Joined to Orders on the surrogate key.
// Relationship: Orders[SoldToAddressSKey] * -> 1 Sold-To[AddressSKey] (active).
//   (Ship-To takes Orders[ShipToAddressSKey]; both are DimAddress, role-playing —
//   so Sold-To gets the SECOND, active relationship and Ship-To’s stays active too.)
//
// Customer Segmentation rides the EXISTING DimAddress join — no new relationship.
// This is the SOLD-TO-level segmentation (per ordering address). As in Ship-To,
// ⚠ segmentation does NOT exist on dbo.DimAddress — it lives only on the BIQL view
// BIQL.DimAddress, hence the LEFT JOIN on AddressSKey (same EDW database,
// cross-schema; folds server-side). It assumes BIQL.DimAddress is 1 row per
// AddressSKey and shares the dbo key space; if the row count jumps, dedupe the
// BIQL side.
let
    Source = Sql.Database(
        "EDWPROD",
        "EDW",
        [Query = "
SELECT
    a.AddressSKey,
    a.MailingName              AS [Sold-To Name],
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
