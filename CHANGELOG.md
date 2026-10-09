# Release notes

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
