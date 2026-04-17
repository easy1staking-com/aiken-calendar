//// Golden vectors and property-based tests for `calendar`.
////
//// Golden vectors anchor the implementation against known-good values
//// computed off-chain (Python `datetime`, Java `java.time`). Property
//// tests cover the round-trip and inverse-arithmetic invariants.

use aiken/fuzz
use calendar.{
  Civil, add_days, add_hours, add_minutes, add_months, add_seconds, add_years,
  diff_days, diff_ms, eq, from_civil, from_ms, ge, gt, iso_day_of_week, le, lt,
  to_civil, to_ms,
}

// =============================================================================
// Golden vectors — landmark UTC instants
// =============================================================================
//
//   ms (POSIX)            | UTC datetime
//   ----------------------|--------------------------------
//                       0 | 1970-01-01T00:00:00.000Z
//             946_684_800 | 2000-01-01T00:00:00.000Z
//             951_782_400 | 2000-02-29T00:00:00.000Z (leap)
//           1_704_067_200 | 2024-01-01T00:00:00.000Z
//           1_709_164_800 | 2024-02-29T00:00:00.000Z (leap)
//           1_735_689_599 | 2024-12-31T23:59:59 (.999 in ms)
//          13_569_465_600 | 2400-01-01T00:00:00.000Z (÷400 leap)
//
// (multiplied by 1000 below to convert s → ms)

test golden_y2k() {
  let t = from_ms(946_684_800_000)
  to_civil(t) == Civil {
    year: 2000,
    month: 1,
    day: 1,
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
  }
}

test golden_2000_leap_day() {
  let t = from_ms(951_782_400_000)
  to_civil(t) == Civil {
    year: 2000,
    month: 2,
    day: 29,
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
  }
}

test golden_2024_new_year() {
  let t = from_ms(1_704_067_200_000)
  to_civil(t) == Civil {
    year: 2024,
    month: 1,
    day: 1,
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
  }
}

test golden_2024_leap_day() {
  let t = from_ms(1_709_164_800_000)
  to_civil(t) == Civil {
    year: 2024,
    month: 2,
    day: 29,
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
  }
}

test golden_2024_eoy() {
  let t = from_ms(1_735_689_599_999)
  to_civil(t) == Civil {
    year: 2024,
    month: 12,
    day: 31,
    hour: 23,
    minute: 59,
    second: 59,
    millisecond: 999,
  }
}

test golden_pre_epoch_one_ms() {
  // -1 ms = the millisecond just before the Unix epoch.
  let t = from_ms(-1)
  to_civil(t) == Civil {
    year: 1969,
    month: 12,
    day: 31,
    hour: 23,
    minute: 59,
    second: 59,
    millisecond: 999,
  }
}

test golden_pre_epoch_one_day() {
  let t = from_ms(-86_400_000)
  to_civil(t) == Civil {
    year: 1969,
    month: 12,
    day: 31,
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
  }
}

test golden_2400_centurial_leap() {
  // Year 2400 is divisible by 400 — so leap.
  let t = from_ms(13_569_465_600_000)
  to_civil(t) == Civil {
    year: 2400,
    month: 1,
    day: 1,
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
  }
}

// =============================================================================
// Calendar-aware arithmetic — clamping and rollover
// =============================================================================

test add_months_clamps_jan31_to_feb29_leap() {
  let jan31_2024 =
    from_civil(
      Civil {
        year: 2024,
        month: 1,
        day: 31,
        hour: 12,
        minute: 30,
        second: 45,
        millisecond: 678,
      },
    )
  let feb_2024 = add_months(jan31_2024, 1)
  to_civil(feb_2024) == Civil {
    year: 2024,
    month: 2,
    day: 29,
    hour: 12,
    minute: 30,
    second: 45,
    millisecond: 678,
  }
}

test add_months_clamps_jan31_to_feb28_non_leap() {
  let jan31_2023 =
    from_civil(
      Civil {
        year: 2023,
        month: 1,
        day: 31,
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
      },
    )
  let result = add_months(jan31_2023, 1)
  to_civil(result).day == 28
}

test add_months_negative_rolls_year_back() {
  let jan15_2024 =
    from_civil(
      Civil {
        year: 2024,
        month: 1,
        day: 15,
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
      },
    )
  let dec15_2023 = add_months(jan15_2024, -1)
  to_civil(dec15_2023) == Civil {
    year: 2023,
    month: 12,
    day: 15,
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
  }
}

test add_months_thirteen_crosses_year() {
  let jan31_2024 =
    from_civil(
      Civil {
        year: 2024,
        month: 1,
        day: 31,
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
      },
    )
  let feb_2025 = add_months(jan31_2024, 13)
  to_civil(feb_2025) == Civil {
    year: 2025,
    month: 2,
    day: 28,
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
  }
}

test add_months_dec_to_jan_no_clamp() {
  let dec31_2024 =
    from_civil(
      Civil {
        year: 2024,
        month: 12,
        day: 31,
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
      },
    )
  let jan31_2025 = add_months(dec31_2024, 1)
  to_civil(jan31_2025).day == 31
}

test add_years_leap_day_clamps() {
  let leap = from_ms(1_709_164_800_000)
  // 2024-02-29 + 1 year → 2025-02-28
  let next_year = add_years(leap, 1)
  to_civil(next_year).day == 28
}

test add_years_leap_day_returns_to_leap_after_4() {
  let leap = from_ms(1_709_164_800_000)
  // 2024-02-29 + 4 years → 2028-02-29
  let four = add_years(leap, 4)
  to_civil(four).day == 29
}

test add_days_crosses_year() {
  let dec31_2024 =
    from_civil(
      Civil {
        year: 2024,
        month: 12,
        day: 31,
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
      },
    )
  let jan1_2025 = add_days(dec31_2024, 1)
  to_civil(jan1_2025) == Civil {
    year: 2025,
    month: 1,
    day: 1,
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
  }
}

// =============================================================================
// Comparison / diff
// =============================================================================

test compare_predicates_consistent() {
  let earlier = from_ms(100)
  let later = from_ms(200)
  lt(earlier, later) && le(earlier, later) && !gt(earlier, later) && !ge(
    earlier,
    later,
  ) && !eq(earlier, later)
}

test diff_ms_signed() {
  diff_ms(from_ms(500), from_ms(300)) == 200 && diff_ms(
    from_ms(300),
    from_ms(500),
  ) == -200
}

test diff_days_one_year_leap() {
  // 2024 is a leap year — 366 days.
  let jan1_2024 = from_ms(1_704_067_200_000)
  let jan1_2025 =
    from_civil(
      Civil {
        year: 2025,
        month: 1,
        day: 1,
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
      },
    )
  diff_days(jan1_2025, jan1_2024) == 366
}

// =============================================================================
// Day-of-week against a known anchor
// =============================================================================

test iso_day_of_week_2024_01_01_monday() {
  // 2024-01-01 was a Monday → ISO 1.
  iso_day_of_week(from_ms(1_704_067_200_000)) == 1
}

test iso_day_of_week_pre_epoch_wednesday() {
  // 1969-12-31 was a Wednesday → ISO 3.
  iso_day_of_week(from_ms(-1)) == 3
}

test iso_day_of_week_pre_epoch_sunday() {
  // 1969-12-28 was a Sunday → ISO 7.
  let t =
    from_civil(
      Civil {
        year: 1969,
        month: 12,
        day: 28,
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
      },
    )
  iso_day_of_week(t) == 7
}

// =============================================================================
// Documented public claim: 2025-03-31 - 1 month → 2025-02-28
// =============================================================================

test add_months_mar31_minus_1_to_feb28() {
  let mar31 =
    from_civil(
      Civil {
        year: 2025,
        month: 3,
        day: 31,
        hour: 9,
        minute: 15,
        second: 0,
        millisecond: 0,
      },
    )
  let feb = add_months(mar31, -1)
  to_civil(feb) == Civil {
    year: 2025,
    month: 2,
    day: 28,
    hour: 9,
    minute: 15,
    second: 0,
    millisecond: 0,
  }
}

// =============================================================================
// from_civil rejects every kind of out-of-range field (`expect`-bombs).
// =============================================================================

// Helper: a valid baseline we mutate one field at a time.
fn baseline_civil() -> Civil {
  Civil {
    year: 2024,
    month: 6,
    day: 15,
    hour: 12,
    minute: 30,
    second: 45,
    millisecond: 500,
  }
}

test from_civil_baseline_is_valid() {
  // Sanity: confirm the baseline itself round-trips. If this ever fails
  // the negative tests below would silently start passing for the wrong
  // reason.
  to_civil(from_civil(baseline_civil())) == baseline_civil()
}

// `fail` tests must consume the result, otherwise Aiken eliminates
// the call as dead code and the `expect` never fires.

test from_civil_rejects_month_13() fail {
  to_ms(from_civil(Civil { ..baseline_civil(), month: 13 })) == 0
}

test from_civil_rejects_month_zero() fail {
  to_ms(from_civil(Civil { ..baseline_civil(), month: 0 })) == 0
}

test from_civil_rejects_month_negative() fail {
  to_ms(from_civil(Civil { ..baseline_civil(), month: -1 })) == 0
}

test from_civil_rejects_day_zero() fail {
  to_ms(from_civil(Civil { ..baseline_civil(), day: 0 })) == 0
}

test from_civil_rejects_day_too_large_for_month() fail {
  // June only has 30 days.
  to_ms(from_civil(Civil { ..baseline_civil(), day: 31 })) == 0
}

test from_civil_rejects_feb_29_in_non_leap_year() fail {
  to_ms(
    from_civil(
      Civil {
        year: 2023,
        month: 2,
        day: 29,
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
      },
    ),
  ) == 0
}

test from_civil_accepts_feb_29_in_leap_year() {
  let t =
    from_civil(
      Civil {
        year: 2024,
        month: 2,
        day: 29,
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
      },
    )
  to_civil(t).day == 29
}

test from_civil_rejects_hour_24() fail {
  to_ms(from_civil(Civil { ..baseline_civil(), hour: 24 })) == 0
}

test from_civil_rejects_hour_negative() fail {
  to_ms(from_civil(Civil { ..baseline_civil(), hour: -1 })) == 0
}

test from_civil_rejects_minute_60() fail {
  to_ms(from_civil(Civil { ..baseline_civil(), minute: 60 })) == 0
}

test from_civil_rejects_second_60() fail {
  to_ms(from_civil(Civil { ..baseline_civil(), second: 60 })) == 0
}

test from_civil_rejects_millisecond_1000() fail {
  to_ms(from_civil(Civil { ..baseline_civil(), millisecond: 1000 })) == 0
}

test from_civil_rejects_millisecond_negative() fail {
  to_ms(from_civil(Civil { ..baseline_civil(), millisecond: -1 })) == 0
}

// =============================================================================
// Pre-epoch month arithmetic
// =============================================================================

test add_months_pre_epoch_jan31_to_feb28() {
  // 1969 is NOT a leap year, so 1969-01-31 + 1 month → 1969-02-28.
  let jan31_1969 =
    from_civil(
      Civil {
        year: 1969,
        month: 1,
        day: 31,
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
      },
    )
  let feb_1969 = add_months(jan31_1969, 1)
  to_civil(feb_1969) == Civil {
    year: 1969,
    month: 2,
    day: 28,
    hour: 0,
    minute: 0,
    second: 0,
    millisecond: 0,
  }
}

test add_months_pre_epoch_crosses_epoch_boundary() {
  // 1969-12-15 + 1 month → 1970-01-15  (negative ms → positive ms)
  let dec_1969 =
    from_civil(
      Civil {
        year: 1969,
        month: 12,
        day: 15,
        hour: 6,
        minute: 0,
        second: 0,
        millisecond: 0,
      },
    )
  let jan_1970 = add_months(dec_1969, 1)
  to_civil(jan_1970) == Civil {
    year: 1970,
    month: 1,
    day: 15,
    hour: 6,
    minute: 0,
    second: 0,
    millisecond: 0,
  }
}

// =============================================================================
// Property-based tests
// =============================================================================
//
// Bound the random ms to roughly ±300 years around epoch — enough variety
// to exercise the algorithm without producing absurd years that obscure
// shrinking output when a property fails.

const ms_range_bound: Int = 9_460_800_000_000

fn arb_ms() -> Fuzzer<Int> {
  fuzz.int_between(-ms_range_bound, ms_range_bound)
}

// `add_months` may clamp, so for the round-trip-by-months property we
// need a day safely <= 28.
fn arb_day_safe() -> Fuzzer<Int> {
  fuzz.int_between(1, 28)
}

fn arb_year() -> Fuzzer<Int> {
  fuzz.int_between(1900, 2200)
}

fn arb_month() -> Fuzzer<Int> {
  fuzz.int_between(1, 12)
}

test prop_civil_roundtrip(ms via arb_ms()) {
  let t = from_ms(ms)
  to_ms(from_civil(to_civil(t))) == ms
}

test prop_add_days_inverse(ms via arb_ms()) {
  let t = from_ms(ms)
  let n = 365
  to_ms(add_days(add_days(t, n), -n)) == ms
}

test prop_add_seconds_inverse(ms via arb_ms()) {
  let t = from_ms(ms)
  let n = 12_345
  to_ms(add_seconds(add_seconds(t, n), -n)) == ms
}

test prop_add_hours_minutes_consistency(ms via arb_ms()) {
  let t = from_ms(ms)
  // 1 hour == 60 minutes.
  to_ms(add_hours(t, 1)) == to_ms(add_minutes(t, 60))
}

test prop_add_days_equals_24_hours(ms via arb_ms()) {
  let t = from_ms(ms)
  to_ms(add_days(t, 1)) == to_ms(add_hours(t, 24))
}

// `test` definitions accept at most one argument, so multi-fuzzer
// properties combine their inputs into a single tuple via `fuzz.map3`
// / `fuzz.both`.
fn arb_safe_ymd() -> Fuzzer<(Int, Int, Int)> {
  fuzz.map3(arb_year(), arb_month(), arb_day_safe(), fn(y, m, d) { (y, m, d) })
}

test prop_add_months_inverse_safe_day(ymd via arb_safe_ymd()) {
  // For days ≤ 28 the month cycle is bijective: no clamping ever fires,
  // so add_months(t, n) followed by add_months(_, -n) is identity.
  let (year, month, day) = ymd
  let t =
    from_civil(
      Civil { year, month, day, hour: 0, minute: 0, second: 0, millisecond: 0 },
    )
  let n = 17
  to_ms(add_months(add_months(t, n), -n)) == to_ms(t)
}

fn arb_ms_pair() -> Fuzzer<(Int, Int)> {
  fuzz.both(arb_ms(), arb_ms())
}

test prop_compare_total_order(ab via arb_ms_pair()) {
  let (a, b) = ab
  let ta = from_ms(a)
  let tb = from_ms(b)
  if a < b {
    lt(ta, tb)
  } else if a > b {
    gt(ta, tb)
  } else {
    eq(ta, tb)
  }
}

test prop_iso_day_in_range(ms via arb_ms()) {
  let d = iso_day_of_week(from_ms(ms))
  d >= 1 && d <= 7
}

test prop_iso_day_increments_by_1_per_day(ms via arb_ms()) {
  let t1 = from_ms(ms)
  let t2 = add_days(t1, 1)
  let d1 = iso_day_of_week(t1)
  let d2 = iso_day_of_week(t2)
  // Wraps 7 → 1, otherwise +1.
  if d1 == 7 {
    d2 == 1
  } else {
    d2 == d1 + 1
  }
}

test prop_diff_days_matches_construction(ms via arb_ms()) {
  let t = from_ms(ms)
  let n = 42
  diff_days(add_days(t, n), t) == n
}

test prop_to_civil_normalised(ms via arb_ms()) {
  let c = to_civil(from_ms(ms))
  c.month >= 1 && c.month <= 12 && c.day >= 1 && c.day <= 31 && c.hour >= 0 && c.hour <= 23 && c.minute >= 0 && c.minute <= 59 && c.second >= 0 && c.second <= 59 && c.millisecond >= 0 && c.millisecond <= 999
}
