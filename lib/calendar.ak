//// Calendar — POSIX-millisecond time arithmetic for Cardano on-chain code.
////
//// On Cardano, `PosixTime` shows up everywhere (validity intervals, vesting
//// schedules, oracle freshness checks…) but it is just a raw `Int` count of
//// milliseconds since the Unix epoch — there is no stdlib for asking
//// questions like *"is this datum still valid 30 days from the lock time?"*
//// or *"add one calendar month to this deadline."* This library fills that
//// gap.
////
//// ## Design notes
////
//// - All time is **UTC**. There is no time-zone, leap-second, or DST
////   handling — those concerns belong off-chain.
//// - The wire representation is a single `Int`, so on-chain comparison
////   stays a one-builtin operation and ledger interop is trivial via
////   [`from_ms`](#from_ms) / [`to_ms`](#to_ms).
//// - `PosixTime` is `opaque` so callers cannot accidentally pass a raw
////   `Int` (e.g. a slot number, a Lovelace amount) where a timestamp is
////   expected.
//// - Calendar arithmetic (`add_months`, `add_years`) **clamps** the
////   day-of-month to the last valid day of the target month, matching
////   Java's `java.time` and Python's `dateutil`. So `Jan 31 + 1 month`
////   becomes `Feb 28` (or `Feb 29` in a leap year), and `Mar 31 - 1 month`
////   becomes `Feb 28/29`.

use calendar/internal

// =============================================================================
// Constants
// =============================================================================

pub const ms_per_second: Int = 1000

pub const ms_per_minute: Int = 60_000

pub const ms_per_hour: Int = 3_600_000

pub const ms_per_day: Int = 86_400_000

pub const ms_per_week: Int = 604_800_000

// =============================================================================
// Types
// =============================================================================

/// A point in time, stored as POSIX milliseconds since 1970-01-01T00:00:00Z.
///
/// Opaque so a stray `Int` from elsewhere in the script (a slot, an asset
/// amount, an index) cannot be silently mistaken for a timestamp.
pub opaque type PosixTime {
  ms: Int,
}

/// Calendar (civil) representation, fully decomposed.
///
/// All fields are zero-padded ranges:
///
/// - `year` — proleptic Gregorian, may be negative for BCE dates
/// - `month` — `1..=12` (1 = January)
/// - `day` — `1..=31`, never exceeding `days_in_month_of(year, month)`
/// - `hour` — `0..=23`
/// - `minute`, `second` — `0..=59`
/// - `millisecond` — `0..=999`
pub type Civil {
  year: Int,
  month: Int,
  day: Int,
  hour: Int,
  minute: Int,
  second: Int,
  millisecond: Int,
}

// =============================================================================
// Construction / projection
// =============================================================================

/// Wrap a raw POSIX-ms `Int` (typically read from a datum or validity
/// interval) into a `PosixTime`.
pub fn from_ms(ms: Int) -> PosixTime {
  PosixTime { ms }
}

/// Unwrap to the raw POSIX-ms `Int`.
pub fn to_ms(t: PosixTime) -> Int {
  t.ms
}

/// Compose a `PosixTime` from a fully-specified `Civil` value.
///
/// **Validates** every field and `expect`-fails the script on any
/// out-of-range component. Valid ranges:
///
/// - `month ∈ 1..=12`
/// - `day ∈ 1..=days_in_month_of(year, month)` (so `Feb 29` requires a leap year)
/// - `hour ∈ 0..=23`
/// - `minute, second ∈ 0..=59`
/// - `millisecond ∈ 0..=999`
///
/// `year` may be any `Int` (proleptic Gregorian, BCE allowed).
pub fn from_civil(c: Civil) -> PosixTime {
  // Order: cheapest checks first (constant comparisons), then the one
  // call into `days_in_month` which itself dispatches on `month`.
  expect c.month >= 1 && c.month <= 12
  expect c.hour >= 0 && c.hour <= 23
  expect c.minute >= 0 && c.minute <= 59
  expect c.second >= 0 && c.second <= 59
  expect c.millisecond >= 0 && c.millisecond <= 999
  expect c.day >= 1 && c.day <= internal.days_in_month(c.year, c.month)
  let day_index = internal.days_from_civil(c.year, c.month, c.day)
  let ms =
    day_index * ms_per_day + c.hour * ms_per_hour + c.minute * ms_per_minute + c.second * ms_per_second + c.millisecond
  PosixTime { ms }
}

/// Decompose a `PosixTime` into its `Civil` parts.
pub fn to_civil(t: PosixTime) -> Civil {
  let day_index = t.ms / ms_per_day
  let time_ms = t.ms - day_index * ms_per_day
  let (year, month, day) = internal.civil_from_days(day_index)
  let hour = time_ms / ms_per_hour
  let r1 = time_ms - hour * ms_per_hour
  let minute = r1 / ms_per_minute
  let r2 = r1 - minute * ms_per_minute
  let second = r2 / ms_per_second
  let millisecond = r2 - second * ms_per_second
  Civil { year, month, day, hour, minute, second, millisecond }
}

// =============================================================================
// Fixed-unit arithmetic (calendar-independent, pure linear scaling)
// =============================================================================

pub fn add_milliseconds(t: PosixTime, n: Int) -> PosixTime {
  PosixTime { ms: t.ms + n }
}

pub fn add_seconds(t: PosixTime, n: Int) -> PosixTime {
  PosixTime { ms: t.ms + n * ms_per_second }
}

pub fn add_minutes(t: PosixTime, n: Int) -> PosixTime {
  PosixTime { ms: t.ms + n * ms_per_minute }
}

pub fn add_hours(t: PosixTime, n: Int) -> PosixTime {
  PosixTime { ms: t.ms + n * ms_per_hour }
}

pub fn add_days(t: PosixTime, n: Int) -> PosixTime {
  PosixTime { ms: t.ms + n * ms_per_day }
}

pub fn add_weeks(t: PosixTime, n: Int) -> PosixTime {
  PosixTime { ms: t.ms + n * ms_per_week }
}

// =============================================================================
// Calendar-aware arithmetic
// =============================================================================

/// Add `n` calendar months to `t`. Negative `n` subtracts.
///
/// The day-of-month is **clamped** to the last valid day of the target
/// month, so e.g. `2024-01-31 + 1 month` → `2024-02-29`,
/// `2025-03-31 - 1 month` → `2025-02-28`. Time-of-day is preserved exactly.
pub fn add_months(t: PosixTime, n: Int) -> PosixTime {
  let c = to_civil(t)
  // Convert to a 0-indexed total month count, shift, split back.
  let total = c.month - 1 + n
  let year_delta = total / 12
  let new_month = total - year_delta * 12 + 1
  let new_year = c.year + year_delta
  let max_day = internal.days_in_month(new_year, new_month)
  let new_day =
    if c.day < max_day {
      c.day
    } else {
      max_day
    }
  from_civil(
    Civil {
      year: new_year,
      month: new_month,
      day: new_day,
      hour: c.hour,
      minute: c.minute,
      second: c.second,
      millisecond: c.millisecond,
    },
  )
}

/// Add `n` calendar years to `t`. Negative `n` subtracts.
///
/// Equivalent to `add_months(t, n * 12)`, so leap-day handling falls out
/// naturally: `2024-02-29 + 1 year` → `2025-02-28`.
pub fn add_years(t: PosixTime, n: Int) -> PosixTime {
  add_months(t, n * 12)
}

// =============================================================================
// Comparison & differences
// =============================================================================

/// Total ordering on the underlying ms — a single builtin comparison.
pub fn compare(a: PosixTime, b: PosixTime) -> Ordering {
  if a.ms < b.ms {
    Less
  } else if a.ms > b.ms {
    Greater
  } else {
    Equal
  }
}

pub fn eq(a: PosixTime, b: PosixTime) -> Bool {
  a.ms == b.ms
}

pub fn lt(a: PosixTime, b: PosixTime) -> Bool {
  a.ms < b.ms
}

pub fn le(a: PosixTime, b: PosixTime) -> Bool {
  a.ms <= b.ms
}

pub fn gt(a: PosixTime, b: PosixTime) -> Bool {
  a.ms > b.ms
}

pub fn ge(a: PosixTime, b: PosixTime) -> Bool {
  a.ms >= b.ms
}

/// `a - b` in milliseconds. Sign reflects direction.
pub fn diff_ms(a: PosixTime, b: PosixTime) -> Int {
  a.ms - b.ms
}

/// `a - b` in whole seconds (truncated toward negative infinity).
pub fn diff_seconds(a: PosixTime, b: PosixTime) -> Int {
  ( a.ms - b.ms ) / ms_per_second
}

/// `a - b` in whole days (truncated toward negative infinity).
pub fn diff_days(a: PosixTime, b: PosixTime) -> Int {
  ( a.ms - b.ms ) / ms_per_day
}

// =============================================================================
// Calendar utilities (re-exports + day-of-week)
// =============================================================================

/// Proleptic-Gregorian leap-year predicate. Works for negative years
/// (BCE) — the formula is `(year % 4 == 0 && year % 100 != 0) || year
/// % 400 == 0` evaluated under floored modulo, which agrees with the
/// usual rule for all years.
pub fn is_leap_year(year: Int) -> Bool {
  internal.is_leap_year(year)
}

/// Last calendar day of `month` in `year` (28..=31).
///
/// `expect`-fails the script if `month` is outside `1..=12`.
pub fn days_in_month_of(year: Int, month: Int) -> Int {
  expect month >= 1 && month <= 12
  internal.days_in_month(year, month)
}

/// ISO-8601 day of week: `1` = Monday … `7` = Sunday.
///
/// 1970-01-01 was a Thursday (ISO `4`). The arithmetic uses floored
/// division throughout, so pre-epoch dates work without branching.
pub fn iso_day_of_week(t: PosixTime) -> Int {
  let day_index = t.ms / ms_per_day
  let shifted = day_index + 3
  shifted - shifted / 7 * 7 + 1
}

// =============================================================================
// Inline unit tests
// =============================================================================

test epoch_roundtrip() {
  let t = from_ms(0)
  let c = to_civil(t)
  c == Civil {
    year: 1970,
    month: 1,
    day: 1,
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
  }
}

test epoch_from_civil() {
  let t =
    from_civil(
      Civil {
        year: 1970,
        month: 1,
        day: 1,
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
      },
    )
  to_ms(t) == 0
}

test compare_total_order() {
  compare(from_ms(1), from_ms(2)) == Less && compare(from_ms(2), from_ms(2)) == Equal && compare(
    from_ms(3),
    from_ms(2),
  ) == Greater
}

test add_seconds_basic() {
  to_ms(add_seconds(from_ms(0), 5)) == 5000
}

test add_days_basic() {
  to_ms(add_days(from_ms(0), 1)) == ms_per_day
}

test iso_day_of_week_thursday() {
  // 1970-01-01 was a Thursday (ISO 4).
  iso_day_of_week(from_ms(0)) == 4
}

test iso_day_of_week_sunday() {
  // 1970-01-04 was a Sunday (ISO 7).
  iso_day_of_week(from_ms(3 * ms_per_day)) == 7
}

test iso_day_of_week_monday() {
  // 1970-01-05 was a Monday (ISO 1).
  iso_day_of_week(from_ms(4 * ms_per_day)) == 1
}

// `days_in_month_of` rejects invalid `month`.

test days_in_month_of_accepts_valid_range() {
  days_in_month_of(2024, 1) == 31 && days_in_month_of(2024, 2) == 29 && days_in_month_of(
    2023,
    2,
  ) == 28 && days_in_month_of(2024, 12) == 31
}

test days_in_month_of_rejects_month_zero() fail {
  days_in_month_of(2024, 0) == 0
}

test days_in_month_of_rejects_month_13() fail {
  days_in_month_of(2024, 13) == 0
}

test days_in_month_of_rejects_month_negative() fail {
  days_in_month_of(2024, -1) == 0
}
