# Hold codes and the 525→540 metric (ticket #2131554, Nathalie Vanhecke)

Nathalie's request: score the report **without the orders that carry a CX or C1 hold
code during the order process**, because hold time inflates the 525→540 interval
through no fault of Customer Service.

## Where hold history lives

**`PRODDTA.F4209` (Held Orders) is the source.** It is replicated to ODS and it is a
full audit, not a current-state snapshot: releasing a hold stamps the release date and
time onto the row rather than deleting it. C1 history reaches back to 1999.

| Column | Content |
|---|---|
| `HOKCOO` / `HODOCO` / `HODCTO` | Order key. `HOLNID` is 0 on every row — the grain is the order **header**, never the line. |
| `HOHCOD` | Hold code (UDC 42/HC). |
| `HORDJ` / `HORDT` | Release date (Julian) and time. Zero on a hold that is still active. |
| `HORDB` / `HORDC` | Released by, and the release code. |
| `HOTRDJ` / `HODRQJ` / `HOPDDJ` | Order, requested and promised-delivery dates copied from the order. |

An order can carry several rows — a repeated hold, or two codes at once. C1 alone holds
45,655 rows over 35,410 orders, of which 45,571 are released and 84 are live; CX holds
7,709 rows over 3,660 orders.

There is **no hold-applied date**. Only the release stamp is recorded, so the window
rule below is expressed in terms of when a hold was *released*.

Everywhere else in JDE carries current state only, or nothing at all:

| Location | Content |
|---|---|
| `F4201.SHHOLD` | The active hold on an open order header. Cleared on release. |
| `F4211.SDHOLD` / `F42119.SDHOLD` | Line-level hold — unused (blank everywhere). |
| `F42199.SLHOLD` | Ledger copy of the line hold — blank on all 19,570,334 ledger records. The sales ledger keeps **status** history, not hold history, and a hold does not change status: held lines sit at ordinary statuses, and the ledger's 900-series codes are backorder/add/cancel markers (UDC 40/AT). |
| `F42019.SHHOLD` | Purged-header copy, frozen at purge: 171,060 blank against 61 non-blank. |
| `F4201_ARCH` | Purge archive spanning 1999–2015, zero key overlap with `F4201`. |

Decode is UDC **42/HC** (`PRODCTL.F0005`): `C1` = Credit Hold, `C2` = Credit Hold – Aging,
`CX` = Held for Cash Advance, `FM` = Order Entry Hold Code for AUBA. (`PEN`, which the
ticket also mentions, is not a 42/HC code.)

## The exclusion rule

**A line is excluded when its order carries a C1 or CX hold anywhere in its history** —
`Ever Held C1/CX` = Y. That is the rule the business asked for and ratified: ever held,
full stop.

It is worth knowing what that includes. A hold released *after* the first 540 is a
post-ship collections hold: it did not delay the shipment, but the order is excluded
anyway. A hold released *before* the first 525 delayed order entry, which this metric
does not measure, and is likewise excluded. Scoping the rule to holds released inside the
525→540 window would exclude roughly half as many lines; the counts below size both.

There is no hold-applied date in F4209, so any window-scoped variant has to be expressed
against the release stamp.

## What it does to the metric

Against the rolling year (14,054 scored lines):

| | Lines |
|---|---|
| **Ever held C1/CX — what the flag excludes** | **3,091** |
| &nbsp;&nbsp;of which released inside the 525→540 window | 1,799 |
| &nbsp;&nbsp;of which released after the first 540 (post-ship) | 1,551 |
| &nbsp;&nbsp;of which released before the first 525 | 65 |
| &nbsp;&nbsp;of which never released | 29 |

The buckets overlap, because one order can carry several hold rows.

These counts come from a direct ODS probe that approximates the interval in **calendar**
days. The report scores in **business** days via the DAX flag columns, so the exact effect
on Goal / Stretch / >48h / <72h / >72h is whatever the refreshed model reports. On the
probe's calendar-day basis, 919 of 4,449 breaching lines had a hold released inside the
measured window — indicative of the scale, not a substitute for the model's own numbers.

## Where this lives now

- **`Orders within Goal and Stretch - No On-Hold`**: carries the page filter that drops
  `Ever Held C1/CX` = Y. This is the copy that answers the ticket.
- **`Orders within Goal and Stretch`**: the same model with the filter left open, so the
  held lines stay visible.
- Both models fetch `Ever Held C1/CX` from the `#held` step (F4209, GROUP BY-deduped to
  one row per order key under a unique index, so the join cannot fan the display grain),
  alongside `Current Hold Code` / `Current Hold Description` (F4201 header join), which
  remain current-state.
- **Orders GS - Line Explorer (DAX)**: same hold columns on `Order Lines`, a Current
  Hold Code slicer, and the code in the line grid. Line grain includes OPEN orders, so
  the held population at 525/530/535 is visible there. No exclusion filter.
- `Hold history probe (ODS).sql` — the SSMS script demonstrating that the sales ledger
  carries no hold codes.
