# calendar

POSIX-millisecond time arithmetic for [Aiken](https://aiken-lang.org)
smart contracts on Cardano.

Cardano's on-chain world represents every instant as a single `Int` — POSIX
milliseconds since `1970-01-01T00:00:00Z`. The standard library has no
answers for the questions validators actually want to ask:

- *"Is this datum still valid 30 days after the lock time?"*
- *"Add one calendar month to this deadline."*
- *"What weekday does this slot fall on?"*

`calendar` fills that gap with a pure, allocation-light, recursion-free
library built on Howard Hinnant's branchless proleptic-Gregorian
algorithm.

## Highlights

- **Opaque `PosixTime`** — a single-`Int` wrapper so a stray slot number
  or token amount can't be mistaken for a timestamp.
- **Calendar-aware arithmetic** — `add_months` / `add_years` clamp the
  day to the last valid day of the target month, matching the semantics
  of Java `java.time` and Python `dateutil`. So `2024-01-31 + 1 month`
  becomes `2024-02-29` (or `Feb 28` in a non-leap year), and
  `2024-02-29 + 1 year` becomes `2025-02-28`.
- **Pre-epoch dates work** — floored integer division is exploited to
  drop the negative-input branches of Hinnant's original C++, so
  pre-1970 timestamps round-trip correctly without special-casing.
- **No `String`, no recursion** — every operation is straight-line `Int`
  math. Most public functions cost a constant handful of UPLC steps.
- **Battle-tested invariants** — 8 golden vectors (Y2K, leap days,
  centurial leap year 2400, EOY 2024, pre-epoch), 13 calendar-arithmetic
  edge cases, and 11 property-based tests (1100 fuzz cases) all pass
  under `aiken check -D`.

## Add to your project

```toml
# aiken.toml
[[dependencies]]
name = "easy1staking-com/aiken-calendar"
version = "0.1.0"
source = "github"
```

## Quick tour

```aiken
use calendar.{
  Civil, add_months, add_years, from_civil, from_ms, iso_day_of_week,
  lt, to_civil, to_ms,
}

// Wrap a raw POSIX-ms field from a datum.
let lock_time = from_ms(datum.locked_at)

// "Has the 30-day vesting cliff passed?"
let cliff = add_months(lock_time, 1)
let now = from_ms(tx_now_ms)
expect lt(cliff, now)

// "Build the timestamp for 2025-04-15T12:00:00Z."
let deadline =
  from_civil(
    Civil { year: 2025, month: 4, day: 15, hour: 12, minute: 0, second: 0, millisecond: 0 },
  )

// "What day of the week was the lock time?" (1 = Mon … 7 = Sun)
let weekday = iso_day_of_week(lock_time)
```

## API surface

### Construction / projection

| Function | Purpose |
|---|---|
| `from_ms(Int) -> PosixTime` | Wrap a raw POSIX-ms `Int` |
| `to_ms(PosixTime) -> Int` | Unwrap to the underlying `Int` (for ledger interop) |
| `from_civil(Civil) -> PosixTime` | Compose a timestamp from year/month/day/hour/min/sec/ms |
| `to_civil(PosixTime) -> Civil` | Decompose into a fully-populated `Civil` record |

### Fixed-unit arithmetic (calendar-independent)

`add_milliseconds`, `add_seconds`, `add_minutes`, `add_hours`,
`add_days`, `add_weeks` — all `(PosixTime, Int) -> PosixTime`. Negative
deltas subtract.

### Calendar-aware arithmetic (with day-clamping)

`add_months`, `add_years` — `(PosixTime, Int) -> PosixTime`. Negative
deltas roll backward. The day-of-month is clamped to the last valid day
of the target month.

### Comparison

`compare` returns the prelude's `Ordering`. Convenience predicates:
`eq`, `lt`, `le`, `gt`, `ge`. Differences: `diff_ms`, `diff_seconds`,
`diff_days` — all signed and reflect direction (`a - b`).

### Calendar utilities

- `is_leap_year(year: Int) -> Bool`
- `days_in_month_of(year: Int, month: Int) -> Int`
- `iso_day_of_week(PosixTime) -> Int` — 1 = Monday … 7 = Sunday

### Constants

`ms_per_second`, `ms_per_minute`, `ms_per_hour`, `ms_per_day`,
`ms_per_week`. Use these instead of magic numbers.

## What this library does *not* do

- **Time zones / DST.** Everything is UTC. Convert before the timestamp
  reaches the validator.
- **Leap seconds.** POSIX time pretends they don't exist, so we do too.
- **Formatting / parsing.** `to_civil` gives you the integer fields;
  build display strings off-chain.
- **Field-range validation in `from_civil`.** Out-of-range fields
  silently normalise (e.g. `month = 13` rolls into the next year).
  Validate user input at the boundary.

## Tested invariants

Property tests (each at 100 random cases) prove:

- `from_civil(to_civil(t)) == t` for all `t`
- `add_days(t, n) -> add_days(_, -n) == t`
- `add_seconds(t, n) -> add_seconds(_, -n) == t`
- `add_hours(t, 1) == add_minutes(t, 60)`
- `add_days(t, 1) == add_hours(t, 24)`
- `add_months(t, n) -> add_months(_, -n) == t` for days ≤ 28
  (clamping makes it lossy beyond)
- `compare` is a total order matching the underlying `Int`
- `iso_day_of_week` is in `[1, 7]` and increments by 1 per day (with
  `7 → 1` wrap)
- `diff_days(add_days(t, n), t) == n`
- `to_civil` produces fields in canonical ranges

## Building, testing, benchmarking

```sh
# Type-check + run all tests (52 cases + 1100 fuzz checks).
aiken check

# Stricter: warnings as errors.
aiken check -D

# Run only tests matching a name fragment.
aiken check -m clamps

# Benchmark every operation on the public API.
aiken bench

# Generate HTML docs from `////` doc-comments.
aiken docs
```

## Layout

```
lib/
├── calendar.ak              — public API
└── calendar/
    ├── internal.ak          — Hinnant algorithm + helpers
    ├── spec.ak              — golden + property tests
    └── benchmarks.ak        — `aiken bench` samplers
```

## License

Apache-2.0
