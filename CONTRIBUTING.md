# Contributing

Thanks for your interest in improving `aiken-calendar`.

## Prerequisites

- [Aiken](https://aiken-lang.org) `v1.1.21` or newer (use
  [`aikup`](https://aiken-lang.org) to install).

## Development loop

Clone and verify everything passes before making changes:

```sh
git clone git@github.com:easy1staking-com/aiken-calendar.git
cd aiken-calendar
aiken check -D      # type-check + run every test, warnings as errors
```

Useful commands while iterating:

```sh
aiken check -m <name_fragment>   # run only matching tests
aiken fmt                        # auto-format (must be clean before PR)
aiken bench                      # exercise the benchmark samplers
aiken docs                       # regenerate HTML API docs under ./docs
```

## Pull requests

- Every change must keep `aiken check -D` and `aiken fmt --check` green —
  CI enforces both.
- For algorithm changes, add or update a **property test** in
  `lib/calendar/spec.ak`, not just a unit test. Properties are what
  catch the subtle integer-edge bugs this library is most exposed to.
- For perf-sensitive changes, include before/after numbers from
  `aiken bench` in the PR description. Refer to the Aiken
  [optimizing-programs guide](https://aiken-lang.org/optimizing-programs)
  for idiomatic moves.
- Public API additions must come with doc comments (`///`) on every
  exported function and type.

## Commit style

- Conventional prefixes are welcome (`feat:`, `fix:`, `chore:`,
  `docs:`, `test:`, `perf:`) but not required.
- One focused change per commit. Rebase-merge, no merge commits on
  `main`.
- Include a short *why* in the body — the *what* is visible in the diff.

## Reporting issues

Please include: your Aiken version (`aiken --version`), the minimum
reproducing snippet, and the actual vs. expected output.
