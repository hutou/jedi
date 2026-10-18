# Managing the market database

## The Demo database for the examples

This procedure prepares the data used from chapters 03 and 04 onwards. Files are supplied in [examples/](../../examples/README.md) at the root of the documentation archive. First follow chapter 02 to install `jedidemo` and copy the files to `~/jedi-examples/`. The launcher opens that directory for commands regardless of the terminal directory. The commands below assume the default universe `france` and a `demo_france.db` database that does not yet exist.

Run the steps in order, through the update of all three securities to 2 October. Chapter 04's `profile` examples will then use this `Demo` dataset. Individual files `cotations_EXA.txt`, `cotations_EXB.txt` and `cotations_EXC.txt` can also be studied directly without creating this database.

### Import the dataset

This batch's `examples/` directory contains **entirely fictional** data with a simplified weekday calendar. With files copied to the demonstration directory, the following commands create a `demo_france` database that must not exist initially:

~~~console
jedidemo market init demo
jedidemo market import demo Demo Demo_initial.txt labels_demo.txt
jedidemo market info demo --dataset=Demo
jedidemo market list demo --dataset=Demo --last-quote
~~~

`init` creates the database. `import` creates the dataset; an existing dataset must be updated or replaced with the appropriate command.

The initial demonstration import contains three securities and 2,550 quotations through 1 October 2026. The report states counts and anomalies. Some invalid quotations or quotations without labels can be reported and skipped: read the report and log.

To consult two sessions for one security:

~~~console
jedidemo market quote demo FR4487601001 --select=l2
~~~

`market quote` displays this ISIN's history. It differs from `quote get`, which queries current-price providers.

### Update the quotations

An update supplies a file containing new sessions with the required labels. It merges data into an existing dataset.

In the demonstration, first add only EXA's quotation for 2 October:

~~~console
jedidemo market update demo Demo Demo_partiel.txt labels_demo.txt
jedidemo market info demo --dataset=Demo
~~~

EXA is recent; the other two securities remain at 1 October. The observed values distinguish:

| Information | Value after the partial update |
|---|---|
| Last full import period | 2023-06-30 → 2026-10-01 |
| Currently available period | 2023-06-30 → 2026-10-02 |
| Global freshness date, 95% | 2026-10-01 |

Then update all three securities:

~~~console
jedidemo market update demo Demo Demo_update.txt labels_demo.txt
jedidemo market info demo --dataset=Demo
~~~

EXA's equivalent duplicate is skipped; the other two sessions are added. The global reference advances to **2 October 2026**, while the last full import period stays unchanged.

This illustrates normal dataset maintenance. Reimporting the whole history is unnecessary for advancing freshness.

## Two databases with separate uses

| Database | Contents | Use |
|---|---|---|
| Main Jedi database | Securities, trades, settings, operations, notes and recorded prices | Trade management |
| Market database | OHLCV histories, datasets and groups | Comparison, scale search and simulations |

**OHLCV** means open, high, low, close and volume per session. These data describe a history; a current price describes one point in time.

The market database is optional. An individual file can supply `profile`, `score` or `backtest`. A database simplifies work on many securities and their updates.

`market` commands import files supplied by the user. They do not download them. Importing these histories updates neither the main database price nor trade operations.

## Source, universe, dataset and group

| Concept | Example | Purpose |
|---|---|---|
| Source | `abcbourse`, or `demo` in our examples | Logical name for the files' origin |
| Universe | `france` | Scope completing the database name |
| Dataset | `Euronext_A`, or `Demo` | Imported collection of securities and quotations |
| Group | `PEA`, or `EXEMPLES` | Logical list of securities |

A source and universe identify a SQLite file, such as `abcbourse_france.db` or `demo_france.db`. The source name does not trigger data collection.

One security can belong to several datasets and groups. Quotations can be shared between datasets: per-dataset counts do not necessarily add up.

`Euronext_A`, `Euronext_B`, `Euronext_C`, `Euronext_Access` and `Euronext_Growth` belong to the French context used to prepare Jedi. Commands remain usable with other scopes, taking account of their data and monetary unit.

## Check locations

~~~console
jedidemo config --paths
~~~

With `jedidemo`, market databases normally live in `~/jedi-examples/jedi/env_test/market/`. `JEDI_DEMO_MARKET_DIR` selects another directory. With `jedi`, the production market normally lives in `~/.local/share/jedi/market/`, taking `XDG_DATA_HOME` into account. Chapter 02 explains these choices.

The default universe comes from `market_data.default_universe`, normally `france`. An explicit option overrides it:

~~~console
jedidemo market info demo --universe=france
~~~

Use the same universe throughout a command sequence. Changing it identifies another physical database.

## Prepare the files

“Prepare” means identify provenance, put data into the expected format and check consistency. An export obtained outside Jedi can need conversion. The software licence does not define usage rights for third-party quotations.

For a dataset import, prepare two files.

The quotation file contains **ISIN; date; open; high; low; close; volume**, without a three-field identity row:

~~~text
FR4487601001;20230630;10.0000;10.1800;9.8200;10.0000;60000
FR4487601019;20230630;30.0000;30.4800;29.5200;30.0000;30000
~~~

The labels file contains **ISIN; name; ticker**:

~~~text
FR4487601001;Exemple A;EXA
FR4487601019;Exemple B;EXB
FR4487601027;Exemple C;EXC
~~~

Watch the order: an individual file for the tools starts with **ISIN; ticker; name**, followed by its quotations:

~~~text
FR4487601001;EXA;Exemple A
FR4487601001;20230630;10.0000;10.1800;9.8200;10.0000;60000
~~~

Do not confuse these two first rows. An individual file concerns one ISIN; a dataset file can contain several. Avoid a column-header row in the quotation file. The labels file accepts an `ISIN;Name;Ticker` header.

The quotation reader accepts semicolon or comma separators and several date formats. When preparing a new file, `YYYYMMDD` dates and decimal points avoid ambiguity. For ambiguous dates, `--date-order=dmy` or `ymd` specifies order; consult command help.

Before import, check ISINs, dates, columns, positive prices, highs and lows, non-negative volumes and duplicates. Identify raw or adjusted prices and use them consistently. A successful import does not prove that missing sessions, suspensions or provider corrections have been handled correctly.

Keep original files, period coverage, transformations, the security list and acquisition date. Provide enough history for the tools: `profile` examines 252 recent sessions but requires longer history for checks; `score` uses 750 by default.

## Understand the three dates

| Information | What it describes |
|---|---|
| Last full import and its period | The import operation and the quotation period supplied by that import |
| Currently available period | Oldest and newest quotations stored for the dataset |
| Global freshness date | Date reached by at least 95% of securities |

The global reference is calculated from each dataset security's latest quotation. It can advance with some lagging securities when at least 95% have reached the new date. For 600 securities, at least 570 are required; 595 recent securities and five laggards satisfy that condition.

It does not depend simply on the time of the last `market update` call. It is also a relative reference: if all securities are old, check the date against the session you intend to examine.

`profile` uses this reference for individual lag: zero sessions, caution for one or two, rejection beyond two. Historical selection or an ambiguous dataset can make this check unavailable; chapter 04 explains these cases.

## Read anomalies and gaps

An existing quotation with identical values is an equivalent duplicate. A conflicting value during `update` is reported and skipped; the stored value remains. Updating is therefore not a correction procedure for conflicting older quotations.

If the first new session is more than seven calendar days after the dataset's current end, the extension is refused unless `--allow-gap` is used:

~~~console
jedidemo market update demo Demo Demo_update.txt labels_demo.txt --allow-gap
~~~

This option accepts the gap; it does not fill it. The check concerns the dataset's overall extension and does not detect every missing session in each security. Consult individual histories when a report or provider indicates a problem.

## Replace a dataset and manage groups

`market replace` rebuilds a dataset from a new complete corpus, for example after data corrections. Check files and keep a backup before using it; data shared with other datasets are preserved.

A group is created or synchronised from a list of ISINs or tickers, one per line:

~~~console
jedidemo market sync-group demo EXEMPLES groupe_exemples.txt \
  --as-of=2026-10-02 --reference-source=demonstration
jedidemo market list demo 'group=EXEMPLES' --last-quote
jedidemo tools profile --database=demo --dataset=Demo --group=EXEMPLES --rank-criteria=4
~~~

Synchronisation replaces current membership: a member missing from the file is removed. `--as-of` describes the list's reference date, not automatic reconstruction of past membership.

Maintain files, read `market info`, check latest quotations with `market list`, then run tools on the intended population. The main database and prices used for real monitoring continue to be managed separately.
