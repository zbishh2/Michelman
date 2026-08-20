// ============================================================================
// Report 22 - "CM - Information 2020 - Future" - LAST REFRESHED (utility)
// COMMENTED MASTER. The shipped file is "Last Refreshed.m" (comment-free).
//
// One-row table stamped at refresh time in US Eastern, feeding the
// [Last Refreshed Label] card on every page. Power Query has no time-zone
// database, so DST is computed by rule: US DST starts the second Sunday of March
// at 07:00 UTC and ends the first Sunday of November at 06:00 UTC.
// Same shape as report 19.
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
    // Second Sunday of March, 02:00 local = 07:00 UTC.
    DstStartUtc = #datetime(Yr, 3,  Date.Day(NthSunday(Yr, 3,  2)), 7, 0, 0),
    // First Sunday of November, 02:00 local = 06:00 UTC.
    DstEndUtc   = #datetime(Yr, 11, Date.Day(NthSunday(Yr, 11, 1)), 6, 0, 0),
    OffsetHours = if UtcNow >= DstStartUtc and UtcNow < DstEndUtc then -4 else -5,
    EasternNow  = DateTime.From(DateTimeZone.RemoveZone(DateTimeZone.SwitchZone(UtcNowZ, OffsetHours))),
    Output = #table(
        type table [ #"Last Refreshed" = datetime, #"Time Zone" = text ],
        { { EasternNow, if OffsetHours = -4 then "EDT" else "EST" } }
    )
in
    Output
