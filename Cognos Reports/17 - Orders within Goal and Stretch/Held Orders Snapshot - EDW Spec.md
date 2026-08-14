# Held Orders Snapshot — EDW table request

Requested for Customer Service ticket #2131554 (Nathalie Vanhecke): the *Orders within
Goal and Stretch* report must exclude orders that carried a CX or C1 hold at any point
before shipping. JDE clears `F4201.SHHOLD` the moment a hold is released and keeps no
hold history, so the exclusion requires a daily capture of active holds. Forward-only:
exclusion works from the first capture date onward; history before that is unrecoverable.

## Table

One row per order on hold, captured once per night. Suggested name
`dbo.FactHeldOrderSnapshot` (final naming per EDW conventions).

| Column | Type | Source | Notes |
|---|---|---|---|
| CaptureDate | date | load date | the day this hold was observed |
| OrderCompany | nchar(5) | `F4201.SHKCOO` | JDE order numbers are only unique per (company, number, type) |
| OrderNumber | int | `F4201.SHDOCO` | |
| OrderType | nchar(2) | `F4201.SHDCTO` | |
| HoldCode | nchar(2) | `F4201.SHHOLD` | capture **all** hold codes, not just CX/C1 — consumers filter |

Primary key: (CaptureDate, OrderCompany, OrderNumber, OrderType). `SHHOLD` is a single
field, so an order carries at most one hold code per capture.

## Load

Nightly, after the regular JDE/ODS load, append-only:

```sql
DELETE FROM dbo.FactHeldOrderSnapshot WHERE CaptureDate = CAST(GETDATE() AS date);

INSERT INTO dbo.FactHeldOrderSnapshot (CaptureDate, OrderCompany, OrderNumber, OrderType, HoldCode)
SELECT CAST(GETDATE() AS date),
       LTRIM(RTRIM(SHKCOO)), SHDOCO, LTRIM(RTRIM(SHDCTO)), LTRIM(RTRIM(SHHOLD))
FROM PRODDTA.F4201
WHERE LTRIM(RTRIM(SHHOLD)) <> '';
```

The delete makes a re-run of the same night idempotent. Historical capture dates are
never updated or deleted; retention is indefinite.

**Size**: ~150–200 held orders exist at any moment (currently 76 C1, 12 CX, ~90 other
codes), so roughly 70k rows/year. Hold descriptions decode from UDC 42/HC
(`PRODCTL.F0005`, `DRSY='42'`, `DRRT='HC'`) at read time and are not stored.

## How the report consumes it (context, no EDW work)

Per order line, the report excludes the line from the Goal/Stretch metric when a
CX/C1 snapshot row exists for its order with `CaptureDate <=` the line's first 540
(ship) event — i.e. the order was observed on hold during the measured window. Holds
applied after shipment (e.g. collections) do not retro-exclude.

## Known limit

A nightly capture observes holds once a day: a hold applied and released between two
captures is not recorded. CX/C1 holds sit for days in practice, so the effect on the
metric is negligible, but it is a property of the design.
