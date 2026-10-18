# Release notes

Notable changes are listed by version, newest first, using the categories from [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 1.1.0 - 2026-10-18

### Added

- Combining a split or consolidation with `reset` or `merge` reinitialisation in `settings create`.
- The `operation fees ID AMOUNT` command to correct fees on any recorded operation, including an earlier operation or one belonging to a closed trade.
- A Status column immediately after the name in `trade list`, with five calculated statuses: created, configured, opened, in progress and closed, without a new database field.
- A `status` field in the existing `trade list` regex filter, for example `"status=^(opened|running)$"`. English codes and active-language labels are recognised; the filter combines with existing fields and operators.
- Appendix 05 documenting built-in configuration entries and their actual uses, in French and English.

### Changed

- Automatic `B_kc_NN` or `B_vr_NN` scale names according to their operational type. Equivalent operational definitions are rejected on creation and update, regardless of the supplied name or builder.
- Nonempty `money` values can only be set on configured, opened or in-progress trades, using `trade update`. Clearing with `--money=""` remains allowed at every status.
- Trade CSV exports include `status` after `name`; table column indexes also shift to accommodate the status.
- Financial results from `tools backtest` are displayed in trade creation order.
- Documentation of the recommended `T_<ticker>_<number>` trade naming convention; glossary entries for `kcpc`, `kspc`, `emax`, `emin` and average acquisition cost (PRU).
- Documentation of security selection through technical analysis and visual reading of trends, channels, support and resistance, with several Web platforms as examples.

### Removed

- The `--money` option from `trade create`. Create the trade and its initial settings first, then set `money` with `trade update`.

### Fixed

- Overall peak investment in backtests now equals the largest individual trade peak, since simulated trades do not overlap. Calculations and presentations using this measure are consistent.
- Clearing `money` and `stop` to `nil` when a sale reduces holdings to zero, including in simulations.
- Presentation of Web-provider regexes in the documentation to prevent overflow into adjacent columns in PDF tables.

## 1.0.0

Prepared first public release of Jedi, a command-line application for mechanical trade management.

### Available features

- Securities, scales, trades, settings, executed operations and notes.
- Proposed-order calculations from the current trade state and chosen rules.
- Optional capital management and protections using `r`, `o` and `n`.
- Separate market databases for quotation histories, imports, updates, datasets and groups.
- `tools profile` to examine securities, `tools score` to search for a scale and `tools candidate` to assess an opening.
- `tools calc` and `tools play` to examine the mechanics; `tools backtest` to simulate a fixed scale on historical quotations.
- French and English interface and documentation; charts with gnuplot.

### Installation and documentation

The initial distribution targets Linux x86_64, including Ubuntu under WSL2. The static binary includes SQLite; gnuplot remains external.

The `jedi`, `jedidemo` and `jedidev` launchers separate production, demonstrations and development, including market databases. The shared binary is at `~/.local/libexec/jedi`. Launcher comments and messages are in English.

Each language's manual contains a foreword, Jedi's philosophy, three parts, 24 chapters and four appendices. Supplied PDFs have 99 pages in French and 96 in English. PDF headings, contents and bookmarks show chapter numbers; Markdown headings remain unnumbered. Example quotations are fictional.

The `C.UTF-8` locale is supported. Help for `candidate` and `backtest` displays the effective number of steps used for the operability check.

### Scope

Jedi calculates and records information; the investor chooses rules and manages execution with their broker. Historical results do not guarantee future results. The manual explains simulation assumptions and limits.

Jedi's code, documentation and scripts are distributed under the MIT license. The first distribution does not include native Windows, macOS or ARM64 binaries.
