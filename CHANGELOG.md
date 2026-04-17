# Changelog

All notable changes to this library are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — 2026-04-17

Initial release.

### Added

- Opaque `PosixTime` wrapper around POSIX-millisecond `Int`
- Transparent `Civil` record (`year`, `month`, `day`, `hour`, `minute`, `second`, `millisecond`)
- `from_ms` / `to_ms` for ledger interop
- `from_civil` / `to_civil` round-trip via Howard Hinnant's branchless
  proleptic-Gregorian algorithm
- Fixed-unit arithmetic: `add_milliseconds`, `add_seconds`, `add_minutes`,
  `add_hours`, `add_days`, `add_weeks`
- Calendar-aware arithmetic with day-clamping: `add_months`, `add_years`
  (matches Java `java.time.LocalDate.plusMonths` semantics)
- Total ordering: `compare`, `eq`, `lt`, `le`, `gt`, `ge`
- Signed differences: `diff_ms`, `diff_seconds`, `diff_days`
- Calendar utilities: `is_leap_year`, `days_in_month_of`, `iso_day_of_week`
- Validation: `from_civil` and `days_in_month_of` `expect`-fail on
  out-of-range fields
- Test suite: 78 unit / golden tests + 11 property tests (1167 checks total)
- Benchmarks for every public hot path via `aiken bench`
