//// Pure date helpers used by the public `calendar` API.
////
//// The two non-trivial functions, `days_from_civil` and `civil_from_days`,
//// are direct ports of Howard Hinnant's branchless proleptic-Gregorian
//// algorithms (http://howardhinnant.github.io/date_algorithms.html).
////
//// Hinnant's original C++ branches around `year < 0` to compensate for
//// C++'s truncated integer division. Aiken's `/` is floored (it lowers
//// to Plutus `divideInteger`), so when the divisor is positive — which
//// it always is here — the branches collapse and we get a near-pure
//// straight-line computation.

// Floored modulo expressed via the existing `/` (no `%` needed,
// keeping us portable across any future operator change).
fn imod(a: Int, b: Int) -> Int {
  a - a / b * b
}

/// Days from 1970-01-01 to (year, month, day) in the proleptic
/// Gregorian calendar. Negative results for pre-epoch dates.
pub fn days_from_civil(year: Int, month: Int, day: Int) -> Int {
  let y =
    if month <= 2 {
      year - 1
    } else {
      year
    }
  let era = y / 400
  let yoe = y - era * 400
  let m_offset =
    if month > 2 {
      month - 3
    } else {
      month + 9
    }
  let doy = ( 153 * m_offset + 2 ) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

/// Inverse of `days_from_civil`: returns `(year, month, day)`.
pub fn civil_from_days(z: Int) -> (Int, Int, Int) {
  let zp = z + 719468
  let era = zp / 146097
  let doe = zp - era * 146097
  let yoe = ( doe - doe / 1460 + doe / 36524 - doe / 146096 ) / 365
  let y_adj = yoe + era * 400
  let doy = doe - ( 365 * yoe + yoe / 4 - yoe / 100 )
  let mp = ( 5 * doy + 2 ) / 153
  let d = doy - ( 153 * mp + 2 ) / 5 + 1
  let m =
    if mp < 10 {
      mp + 3
    } else {
      mp - 9
    }
  let y =
    if m <= 2 {
      y_adj + 1
    } else {
      y_adj
    }
  (y, m, d)
}

/// Proleptic-Gregorian leap-year predicate.
pub fn is_leap_year(year: Int) -> Bool {
  let by4 = imod(year, 4) == 0
  let by100 = imod(year, 100) == 0
  let by400 = imod(year, 400) == 0
  by4 && !by100 || by400
}

/// Last day of `month` in `year` (1..31). `month` MUST be in 1..12.
pub fn days_in_month(year: Int, month: Int) -> Int {
  if month == 2 {
    if is_leap_year(year) {
      29
    } else {
      28
    }
  } else if month == 4 || month == 6 || month == 9 || month == 11 {
    30
  } else {
    31
  }
}

// ---- Internal sanity tests --------------------------------------------------

test imod_negative() {
  imod(-1, 12) == 11
}

test imod_positive() {
  imod(25, 12) == 1
}

test roundtrip_epoch() {
  days_from_civil(1970, 1, 1) == 0
}

test roundtrip_epoch_inverse() {
  civil_from_days(0) == (1970, 1, 1)
}

test leap_2000() {
  is_leap_year(2000)
}

test leap_2024() {
  is_leap_year(2024)
}

test not_leap_1900() {
  !is_leap_year(1900)
}

test not_leap_2023() {
  !is_leap_year(2023)
}

test feb_leap() {
  days_in_month(2024, 2) == 29
}

test feb_non_leap() {
  days_in_month(2023, 2) == 28
}

test sept_30() {
  days_in_month(2024, 9) == 30
}

test jan_31() {
  days_in_month(2024, 1) == 31
}

// BCE coverage — proleptic Gregorian is defined for all integers.

test bce_year_zero_roundtrip() {
  // Year 0 in proleptic Gregorian = 1 BCE astronomically.
  civil_from_days(days_from_civil(0, 3, 1)) == (0, 3, 1)
}

test bce_year_neg_400_is_leap() {
  // -400 is divisible by 400 — must be leap.
  is_leap_year(-400)
}

test bce_year_neg_400_feb_has_29_days() {
  days_in_month(-400, 2) == 29
}

test bce_year_neg_100_not_leap() {
  // -100 fails the /400 rule, so it's NOT leap (matches +100, +1900).
  !is_leap_year(-100)
}
