# Command and option reference

Built-in values and the use of every configuration entry are detailed in [appendix 05](en_annex05_default_configuration.md).

## Find help for the installed version

Run `jedi` without arguments to see command families. A family alone, such as `jedi tools`, shows its subcommands. Detailed help belongs at subcommand level:

~~~console
jedidemo tools backtest --help
jedidemo market import --help
jedidemo note create --help
~~~

Read `version` and `config` directly: `jedi version`, `jedi config` and `jedi config --paths`. They have no help subcommand. The supplied [jedi-help-en.txt](../../reference/jedi-help-en.txt) collects reference-version help; your executable's help describes the version actually in use.

Names may be abbreviated to an unambiguous prefix. Examples keep full names. Named and positional fields are alternative forms: do not mix them for the same fields. Quote names containing spaces and expressions containing shell-interpreted characters.

Global `--border=PRESET` precedes the command family. Styles are `ascii`, `reducedascii`, `modern`, `reducedmodern`, `fancy`, `markdown`, `empty`, `blank`. `--` ends option parsing and is useful before negative arguments, particularly in `play`.

## Portfolio and journal

| Family | Subcommands | Use |
|---|---|---|
| `security` | `create`, `update`, `delete`, `show`, `list` | Identity, ticker, buy/sell ticks and purchase tax |
| `quote` | `get`, `set`, `update`, `refresh` | External query, manual entry or recording current quotations |
| `scale` | `create`, `update`, `delete`, `show`, `list` | Recorded type I or II scales |
| `trade` | `create`, `update`, `delete`, `show`, `list` | Trade identity and capital management |
| `trade` | `orders`, `status`, `results`, `plot` | Orders, state, results and chart |
| `settings` | `create`, `delete`, `show`, `list` | Scale applying at a date/time, split, synchronisation and reset |
| `operation` | `create`, `fees`, `delete`, `list` | Actual executions; fee correction by operation identifier |
| `note` | `create`, `update`, `delete`, `show`, `list` | Journal and exceptional events; `--edit` for an editor |
| `database` | `dump`, `load`, `schema` | Main database backup, restore and schema |

Each help page describes required fields. Deleting an entity in use may be refused; deleting an operation does not automatically replace it. Chapters 08 and 09 show corrections and adaptations.

`quote get ISIN` displays an external price without recording a security or quotation. `quote set` records a manual price. `quote update` updates one registered security; `quote refresh` handles a selection, defaulting to securities of running trades. `--mode=live|eod` applies to `update` and `refresh`, not `get`. `--force` belongs to `refresh` and forces updates according to its filtering.

## Correct operation fees

~~~console
jedidemo operation fees 42 3.50
jedidemo operation fees 42 0
jedidemo operation fees --help
~~~

Syntax is `jedi operation fees <operation_id> <amount>`. The numeric identifier belongs to the operation, found with `operation list`, rather than the trade. The amount replaces **total** fees, including any transaction tax; zero cancels them. Use a decimal point and a non-negative value, rounded to cents. An earlier operation or one in a closed trade can be corrected. Net results, lists and exports use the new value. Historical fees are also copied into a new `play` starting from an operation in the same trade. [Chapter 08](en_08_monitoring_a_trade.md#correct-fees-on-a-recorded-operation) gives the complete procedure.

## Adapt settings: split, reinit and sync

New settings require `--scale`, `--date` and `--time`. Their timestamp must follow the latest settings and operations across the whole database; the trade's previous settings must already have been used by an operation.

| Option or combination | Effect |
|---|---|
| `--split=NEW:OLD` | Convert units; `1:10` means one new share for ten old shares. |
| `--reinit=reset,PRICE` | Current stock as `q0`, chosen price as `c0`, position `0:0:0`. |
| `--reinit=merge,PRICE` | Pending reference; an actual manual transaction then defines `q0` and `c0`. |
| `--split` + `--reinit=reset,PRICE` | Accepted in next-version / v1.1; reset from converted whole stock. |
| `--split` + `--reinit=merge,PRICE` | Accepted in next-version / v1.1; merge from converted whole stock. |
| `--sync=POSITION` | Synchronisation restricted to type I scales. |
| `--sync` + `--split` or `--reinit` | Rejected. |

With split + reinit, `PRICE` and values of the following operation use **post-split units**. While merge waits for its operation, Jedi proposes no automatic order. Fractional rights are not accounted for. Chapter 09 gives practical cases and chapter 19 gives simulations.

## Market databases

| Subcommand | Main arguments | Use |
|---|---|---|
| `market init` | `SOURCE` | Create a market database |
| `market import` | `SOURCE DATASET QUOTES LABELS` | Import a complete dataset |
| `market replace` | `SOURCE DATASET QUOTES LABELS` | Replace dataset contents |
| `market update` | `SOURCE DATASET QUOTES LABELS` | Merge without deletion; ignore duplicates and report conflicts |
| `market sync-group` | `SOURCE GROUP FILE` | Create or synchronise group membership |
| `market group` | `SOURCE GROUP ISIN` | Add/remove a member using `--add` or `--remove` |
| `market info` | `SOURCE` | Metadata and checks; optional `--dataset=CODE` |
| `market list` | `SOURCE [REGEX]` | List; `--dataset=CODE`, `--last-quote` |
| `market quote` | `SOURCE ISIN` | History; `--date`, `--select` |

`--universe=NAME` chooses the universe, `france` in default configuration. QUOTES, LABELS and FILE are file paths. Chapter 10 explains formats and the effects of imports, replacements and updates.

`import`, `replace` and `update` accept `--date-order=auto|ymd|dmy|mdy`, `--year-pivot=NN` and `--from=DATE`. Updates refuse an extension more than seven calendar days beyond the current end unless `--allow-gap` is supplied. Update does not overwrite conflicting quotations; use `replace` with a corrected corpus. `sync-group` accepts `--as-of=DATE` and `--reference-source=NAME` to describe membership.

`market list` accepts field regex expressions, including `group` and `dataset`, with `&&` and `||`. This does not provide a multi-group option to `profile`. Jedi exposes one `--group=CODE` in `profile`; no dedicated command deletes a group. `market quote` displays an OHLCV table and offers no CSV export.

## Common listing options

Regex filters in lists supporting them are case-insensitive. `field=pattern` targets a field; `&&` means AND, `||` means OR, with AND precedence. Parentheses cannot group logical conditions, but remain valid within a regex pattern. Available fields vary by command: read its help.

For `trade list`, the `status` field recognises the codes `created`, `configured`, `opened`, `running`, `closed`, as well as labels in the active language. For example, `jedidemo trade list "status=^(opened|running)$"` retains opened and in-progress trades; `jedidemo trade list "status=^closed$ && name=^T_erf"` retains closed trades whose names start with `T_erf`. Status remains calculated from history.

`--running` limits some lists to trades holding shares; for `trade list`, it retains opened and in-progress trades and combines with the regex. `--select` chooses records after filtering; indices start at 1 and negative indices count from the end. `fN` and `lN` mean first and last rows, `I:J` is a range, and commas combine selections.

Lists offering `--csv` may add headings with `--headers`. `--extended` is not universal: for `operation list` CSV, it adds associated names. `--column-indexes` chooses display columns and cannot be combined with CSV.

For a readable operation list:

~~~console
jedidemo operation list -c 0,6-14,17
~~~

The `o` in `play -c o0,6-14,17` selects a section; it does not precede indices in `operation list`.

## Historical tools: source and selection

`profile`, `score`, `backtest`, `plot` and `stats` accept an individual file or `--database=SOURCE --security=IDENT`, with optional `--universe`. IDENT is an ISIN or ticker. `profile` adds collective `--dataset` and `--group` selections and repeated `--security` options.

One `--date=OP:YYYY-MM-DD` filter applies per command, using `ge`, `gt`, `le`, `lt`. Date filtering precedes `--select`. Repeating `--date` replaces its previous value. To isolate a year with a lower bound, freeze the source at its upper boundary as in chapter 21.

## tools profile

| Option | Purpose |
|---|---|
| `--dataset=CODE` | Select a dataset |
| `--group=CODE` | Filter by one group |
| `--include-rejected` | Display rejected securities without ranking them |
| `--rank-criteria=N` | Add the first N ranks, 1–7; default 7 |
| `--sort=KEY` | `global`, `ticker`, `trend`, `liquidity`, `volatility`, `oscillation`, `drawdown`, `gap`, `step` |
| `--limit=COUNT` | Limit displayed rows |

The seven criteria are trend, liquidity, volatility, oscillation, drawdown, gap and step, in that order. The first four guide shortlisting; chapter 04 explains practical choices and statuses. Recent criteria use 252 sessions and ATR uses 20; depth and freshness are separate checks.

## tools score

| Option | Values and default |
|---|---|
| `--sort` | `fitness` by default; `activity`, `investment`; aliases 1, 2, 3 |
| `--ranking` | `raw` by default; `jedi`, `both` |
| `--search` | `adaptive` by default; `grid` |
| `--budget` | 500 search backtests by default in adaptive mode |
| `--display` | `compact` by default; `study`, `technical` |

Without an explicit constructor, search explores three internal families. Positional constructors `P1`, `P2`, `P3` select one family for expert use. Default selection keeps the last 750 sessions after date filtering.

`raw` directly sorts fitness, activity and maximum investment. `compact` displays its top 20 with typed builders. `study` adds net economic interpretation and fees. `technical` exposes diagnostics and parameter influence in adaptive search.

Expert `jedi` ranking adds a preference based on engine checks, including operability, activity and robustness diagnostics; `both` displays both readings. Robustness diagnostics examine variants or subdivisions and do not guarantee future behaviour. Keep ranking, display mode and search strategy with results. Chapter 05 introduces normal use in `raw` mode.

## tools backtest

| Option | Purpose and default |
|---|---|
| `--scale=DEF` | Literal definition or recorded name, required |
| `--money=DEF` | Capital management; required with `--capital` |
| `--capital=AMOUNT` | Sizing through capital, risk and operability |
| `--distance=COEFFICIENT` | Fixed-amount calculation; incompatible with `--capital` |
| `--minimum-quantity=COUNT` | Minimum per checked order, default 2; capital mode |
| `--operability-steps=COUNT` | Checked steps, default 3; capital mode |
| `--execution=MODE` | `conservative` by default; `legacy` |
| `--opening-day-orders=WHEN` | `next` by default; `same` |
| `--display=MODE` | `compact` by default; `technical` |
| `-c`, `--command=COMMANDS` | Sections `r`, `f`, `o`, `t`, `d`, `p` |

Without `--capital`, the amount comes from simulation configuration; `backtest` has no `--amount` option. Compact output defaults to `r`, technical output to `rf`. `T`, `K`, `S` retain extended compatibility lists. See chapter 22 for gap prices, reopenings and final valuations.

## tools candidate

The ISIN is positional and `--scale` is required. `--price` replaces the recorded price and allows evaluation of an unregistered security. Choose either `--amount` or `--money`; they cannot be combined. `--capital` supplies K for funding and, with `money`, sizing; otherwise K comes from configured dedicated capital.

`--minimum-quantity` defaults to 2; `--operability-steps` defaults to `diagnostic_steps`, **3 in the initial configuration**. Help shows the effective value. `--extended` exposes sizing detail. Chapter 06 explains operability and funding separately.

## Scale definitions

Signatures recognised by `scale create --builder=...` and the tools are:

| Fields | Form |
|---|---|
| `kc,ks,ki,kb` | Type I with explicit price and stock lists |
| `kc,ki,kb,kd` | Type I with optimised construction of `ks` |
| `vr,ks,ki,kb` | Type II with an explicit stock list |
| `vr,np,nn,ki,kb,kd` | Type II with optimised construction of `ks` |
| `vr,np,sr,nn,mi,ki,kb` | Type II compatibility builder |

Without `--name`, `scale create --comment=... --builder=...` assigns `B_kc_NN` for type I or `B_vr_NN` for type II, including Legacy. The next number is computed separately within each family. An explicit name must match the type and use a positive number of at least two digits. Equivalent operational definitions are refused at creation and update, even with `--force`. [Chapter 13](en_13_reading_the_structure_of_a_scale.md#name-and-number-a-scale) details these rules and preservation of historical data.

`kc` and `ks` are decimal lists; `np`, `nn`, `kb` are integers. `vr`, `sr`, `mi` and `ki` accept a decimal coefficient or percentage; `kd` is decimal. Use a decimal point: `kc:1.4,1.2,0.8,0.6`. Commas separate values and fields.

In the compatibility builder, `sr` sets the target stock fraction at the final internal upward step; `mi` sets the budget for internal downward purchases relative to the initial amount. `np` and `nn` include boundaries, leaving `np-1` and `nn-1` internal steps. This form has its own rules: examine its operational definition and orders through `scale show` and `play` before comparing it with others.

## tools calc, play, plot and stats

`calc` accepts `kcb`, `kcp`, `ksp`, `cpe`, `spe`, `quantity`, `price` functions with the necessary `key=value` parameters. It calculates **type I** mechanics. `play` handles types I and II, using a created state or an existing operation identifier. Arguments describe movements, target prices, transactions or setting changes.

In `play`, `-c o0,6-14,17` selects operation columns; add `16` for fees. Sections are `t`, `k`, `s`, `c`, `o`, `r`, `f`, `d`; `--verbose` expands messages. Chapter 19 gives complete commands. Random arguments, such as movement `0`, need particular care for reproducibility.

`plot` draws prices and their regression; `--legend=tl|tr|bl|br` selects the legend corner, otherwise automatic. `stats` shows statistical indicators for selected history. Both supplement data inspection; their outputs do not choose an investment for you.
