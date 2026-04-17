//// Benchmarks for the hot paths in `calendar`.
////
//// Run with `aiken bench`. The samplers grow input size linearly via the
//// `size` parameter (0..30 by default), so the resulting chart shows how
//// each operation scales with magnitude — useful for spotting any
//// surprising super-linear behaviour in the underlying integer ops.

use aiken/fuzz
use calendar.{
  add_days, add_hours, add_months, add_years, compare, diff_days, from_civil,
  from_ms, iso_day_of_week, to_civil,
}

// =============================================================================
// Samplers
// =============================================================================

// POSIX ms in roughly ±5e15 — symmetric around the epoch so pre-1970
// timestamps share the cost picture with post-1970 ones.
fn sample_ms(size: Int) -> Fuzzer<Int> {
  fuzz.int_between(-(size * 5_000_000_000_000), size * 5_000_000_000_000)
}

// Number of months to add — grows up to ±3000 (~250 years).
fn sample_months(size: Int) -> Fuzzer<Int> {
  fuzz.int_between(-(size * 100), size * 100)
}

// Number of days to add — grows up to ~9000 (~25 years).
fn sample_days(size: Int) -> Fuzzer<Int> {
  fuzz.int_between(-(size * 300), size * 300)
}

// =============================================================================
// Construction / projection
// =============================================================================

bench bench_to_civil(ms: Int via sample_ms) {
  to_civil(from_ms(ms))
}

bench bench_from_civil(ms: Int via sample_ms) {
  let c = to_civil(from_ms(ms))
  from_civil(c)
}

// =============================================================================
// Calendar-aware arithmetic
// =============================================================================

bench bench_add_months(n: Int via sample_months) {
  add_months(from_ms(1_704_067_200_000), n)
}

bench bench_add_years(n: Int via sample_months) {
  add_years(from_ms(1_704_067_200_000), n)
}

// =============================================================================
// Fixed-unit arithmetic (should be near-constant cost)
// =============================================================================

bench bench_add_days(n: Int via sample_days) {
  add_days(from_ms(1_704_067_200_000), n)
}

bench bench_add_hours(n: Int via sample_days) {
  add_hours(from_ms(1_704_067_200_000), n)
}

// =============================================================================
// Comparison and derived helpers
// =============================================================================

bench bench_compare(ms: Int via sample_ms) {
  compare(from_ms(ms), from_ms(1_704_067_200_000))
}

bench bench_diff_days(ms: Int via sample_ms) {
  diff_days(from_ms(ms), from_ms(0))
}

bench bench_iso_day_of_week(ms: Int via sample_ms) {
  iso_day_of_week(from_ms(ms))
}

// Round-trip is the key composite cost: `to_civil` is what most
// callers actually pay for since `from_civil` is rarely used in
// hot paths on-chain.
bench bench_civil_roundtrip(ms: Int via sample_ms) {
  let c = to_civil(from_ms(ms))
  from_civil(c)
}
