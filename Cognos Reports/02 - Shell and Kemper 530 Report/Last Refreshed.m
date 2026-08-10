// ============================================================================
// Refresh stamp shown on every page, mirroring the Cognos page-footer timestamp.
//
// DateTime.LocalNow() is deliberately NOT used: it returns UTC in the Power BI
// Service and machine-local time on Desktop, so the card would disagree between
// the two. Instead take UTC explicitly and shift to US Eastern, deriving the DST
// window from the 2nd Sunday of March / 1st Sunday of November (US rule).
// ============================================================================
let
    UtcNowZ = DateTimeZone.FixedUtcNow(),
    UtcNow  = DateTime.From(DateTimeZone.RemoveZone(UtcNowZ)),
    Yr      = Date.Year(UtcNow),
    NthSunday = (yr as number, mth as number, n as number) as date =>
        let
            first      = #date(yr, mth, 1),
            offsetDays = Number.Mod(7 - Date.DayOfWeek(first, Day.Sunday), 7)
        in
            Date.AddDays(first, offsetDays + 7 * (n - 1)),
    DstStartUtc = #datetime(Yr, 3,  Date.Day(NthSunday(Yr, 3,  2)), 7, 0, 0),
    DstEndUtc   = #datetime(Yr, 11, Date.Day(NthSunday(Yr, 11, 1)), 6, 0, 0),
    OffsetHours = if UtcNow >= DstStartUtc and UtcNow < DstEndUtc then -4 else -5,
    EasternNow  = DateTime.From(DateTimeZone.RemoveZone(DateTimeZone.SwitchZone(UtcNowZ, OffsetHours))),
    Output = #table(
        type table [ #"Last Refreshed" = datetime, #"Time Zone" = text ],
        { { EasternNow, if OffsetHours = -4 then "EDT" else "EST" } }
    )
in
    Output
