# Preparing a historical study

## Ask a question you can check

A study starts with a specific question: how does a given scale behave on a security and period? How much activity does it generate? What maximum investment does it require? How does it respond to a decline or gap?

Write the question before reading gains. Fix the securities, dates, fees and sizing mode. A `score` search chooses scales using its input data; a backtest with a fixed definition examines their path. Changing a setting after reading the result creates a new trial to keep.

## Distinguish the periods

[Chapter 23](en_23_euronext_growth_study_example.md) uses this timetable:

| Stage | Available data | Use |
|---|---|---|
| Preparation | History from early 2021 | Checks and historical depth |
| Shortlisting at 31 December 2024 | Quotations through that date | `profile` over the last 252 sessions, ATR over 20 |
| Search at 31 December 2024 | Quotations through that date | `score` over the last 750 sessions |
| Verification | 2025 quotations | `backtest` with the already fixed scale |

The 252-session window describes the security's recent behaviour. The 750-session window exposes scales to a longer path. Verification data must not help tune the choice they are intended to examine.

This separation does not erase what the author already knows. A study performed after 2025 remains retrospective even if its commands isolate dates correctly. For prospective monitoring, record the choice on its actual date before subsequent observations become available.

## Choose securities and keep their list

Specify the scope: market, dataset, group or explicit list. For a study stopping at the end of 2024, seek the list of securities present on that date. A current list may omit companies that left the market and add later listings.

Keep that list with the files. Identify exclusions, short histories and delisted securities. Do not quietly remove a security because its result is unfavourable. A dataset describes memberships in a database; its name certifies neither data provenance nor historical composition.

In an existing database, inspect the scope:

~~~console
jedidemo market info demo --dataset=Demo
jedidemo market list demo --dataset=Demo --last-quote
~~~

These commands require [chapter 10's Demo database](en_10_market_database.md#the-demo-database-for-the-examples). They read the database without downloading quotations.

## Check prepared files

Keep the provider, retrieval date, original format, conversions and conditions of use or redistribution. Individual files and dataset import files have different layouts, described in [chapter 10](en_10_market_database.md).

Check the security identity, currency, date order, duplicates, volumes and consistency of `Low ≤ Open, Close ≤ High`. Check missing sessions against the market calendar rather than simply counting weekdays.

Identify splits, consolidations and other price corrections. Adjusted and unadjusted quotations yield different paths. Do not combine adjusted closes with unadjusted openings and extremes. OHLCV quotations alone are not a dividend or corporate-action cash-flow history handled by the simulation.

To examine an individual file:

~~~console
jedidemo tools profile cotations_EXA.txt
jedidemo tools stats cotations_EXA.txt --date=le:2025-12-31
jedidemo tools plot cotations_EXA.txt --date=le:2025-12-31
~~~

The profile highlights the characteristics and checks it calculates; `stats` and `plot` supplement inspection. A smooth chart or successful import does not certify a provider's accuracy.

## Isolate a year correctly

Jedi accepts **one `--date=OP:YYYY-MM-DD` filter per command**:

| Code | Meaning |
|---|---|
| `ge` | Date greater than or equal to |
| `gt` | Date strictly greater than |
| `le` | Date less than or equal to |
| `lt` | Date strictly less than |

The date filter runs before `--select`. Repeating `--date` does not create a range: the last value replaces the previous one. To isolate 2025 using `--date=ge:2025-01-01`, use a file or database **frozen at 31 December 2025**, without later quotations. Chapter 23's supplied file has this boundary.

For a search ending in 2024, an upper bound suffices:

~~~console
jedidemo tools score cotations_EXA.txt --date=le:2024-12-31 \
  --select=l750 --sort=fitness --budget=40
~~~

This file does not contain 750 sessions before that date; the report states the period actually available. Chapter 23's Growth file supplies the necessary depth. Always read the reported dates and session count.

`--select=l252` keeps the last 252 rows after filtering; `f100` keeps the first 100; `1:100` selects an index range starting at 1. A discontinuous selection such as `f10,-12:-1` joins separate pieces of history and can create an artificial jump between two dates. Use it for inspection while recognising that effect.

`profile` does not assess current freshness with a historical `--date` or `--select` selection. This avoids comparing quotations ending in 2024 with a 2025 or 2026 dataset reference. Check yourself that each security reaches the intended historical boundary.

## Freeze a study copy

A database maintained through `market update` changes. Prepare a separate demonstration database for the study and keep the imported files. The `jedidemo` launcher and `JEDI_DEMO_DIR` directory override separate experiments; chapter 02 describes the steps.

Also keep the version and effective configuration:

~~~bash
study_dir="$HOME/jedi-study-2025"
mkdir -p "$study_dir"
jedidemo version > "$study_dir/version.txt"
jedidemo config > "$study_dir/config.txt"
jedidemo config --paths > "$study_dir/paths.txt"
~~~

The directory receives shell output independently of the directory where the launcher runs Jedi. Before sharing a configuration, remove any provider keys it contains.

The study record combines the question, security list, files, periods, scale, fees and commands. [Chapter 24](en_24_interpreting_comparing_and_monitoring.md) supplies a template.
