# Interpreting, comparing and monitoring results

## Explain the euros before ranking

A result belongs with its dates, scale, first purchase and conventions. Compact measures answer different questions:

| Measure | Question |
|---|---|
| Gross gain | What is sales − purchases + final holdings value? |
| Fees | What brokerage cost was charged to operations? |
| Net gain | What remains after those fees? |
| Maximum investment | What is the largest peak of purchases minus sales within any successive trade, excluding fees? |
| Net gain / maximum investment | How does the net result compare with the largest amount committed within a trade? |
| Activity | How many operations and interventions does the path entail? |
| Final holdings | How much of the result still depends on shares held? |

Sales are not all profit, and a share still held is not cash received. The report values remaining holdings at the last close without adding a fictional final sale.

`score` fitness divides **gross** gain by the first purchase. `backtest` compact return divides **net** gain by maximum investment. Comparing the percentages without checking numerators, denominators and periods gives a misleading reading. [Appendix 04](en_annex04_glossary_and_notation.md) collects these definitions.

## Compare on a common basis

Keep securities, quotations, dates, fees, sizing and execution rules identical. Fix scales before viewing the comparison period. Record net result, fees, peak investment, operations and final holdings for each.

A more active simulation may earn more gross and less net. Another may appear to use little capital because sales reduced investment while still holding a substantial stock. A large gain during a continuous rise does not by itself demonstrate the benefit of round trips.

A simple two-scale comparison is often enough. `score --sort=activity` and `--sort=investment` help explore trade-offs; with adaptive search, they also change refinement. To compare the same scales, reuse their definitions in `backtest`.

## Read the path's limits

Daily data do not reveal each movement's chronology. One proposed order is retained per session. Gaps, actual execution costs, partial fills, trading interruptions and corporate actions can produce a different real path.

[Chapter 22](en_22_simulating_with_tools_backtest.md) shows how a gap exceeds nominal risk. A StopLoss triggers action subject to market possibilities; it guarantees neither a price nor a loss ceiling. Several individual backtests do not replace a check of common funding across trades.

Annualisation available in some expert outputs transforms a ratio according to duration. It adds no observations and does not establish that a return is repeatable. For a short period, euros, operations and final holdings remain the first information to read.

## Check other dates

Keep the selected scale and examine another period, including a different market phase. State whether each test starts with a new purchase or follows an existing actual trade. Different start dates give different reference prices and integer quantities.

For a new period, prepare the final boundary as in chapter 21 and keep the choice before reading the result. If you subsequently adjust the scale, retain the first report and create a new study entry. Trial count matters: searching many settings makes a favourable best result less surprising.

## Keep a dated journal

The journal preserves what was decided, why, with what data, then what was observed. `note` suits study choices and exceptional trade events: gaps, suspensions, broker incidents, partial fills, parameter changes or corporate actions.

An editor makes a complete note easier:

~~~console
jedidemo note create --edit
~~~

Or enter multiline text:

~~~console
jedidemo note create 2026-10-07 "Growth 2025 study: protocol" "Retrospective study using fictional data.
Choice calculated through 2024-12-31; verification on 2025.
Fixed scale: kc:1.5,1.38,1.23,1.14,0.52,0.4,ki:0%,kb:1,kd:0.2.
2025 net: -20.21 EUR; maximum investment: 1498.56 EUR."
~~~

The date is when this note is written; it does not claim a decision was made in 2024. Use the actual date for your own journal. Do not mix positional fields with `--date`, `--summary` or `--contents`.

A note describes an event; it changes neither operations nor orders. Record each actual execution separately through `operation`, then check the trade state. Keep study files outside the note and mention their location.

## Reproduction record

| Field | What to keep |
|---|---|
| Question and date | Objective, actual choice date, prospective or retrospective character |
| Software | `version` output, language and relevant configuration |
| Data | Provider, retrieval, files, conversions, adjustments and usage rights |
| Population | Dated security list, exclusions and reasons |
| Periods | Choice boundary, search window, verification start and end |
| Settings | Exact scale definition, amount or capital and `money`, fees |
| Execution | `conservative` or `legacy`, `next` or `same` |
| Commands | Complete commands and saved reports |
| Results | Gross, fees, net, maximum investment, operations and final holdings |
| Follow-up | Practical decision, later changes and exceptional events |

This record lets you reread a study, explain differences between reports and distinguish the initial choice from later modifications. For an actual project, return to `candidate` with the current price, then to the monitoring of executed operations described in part I.

For actual operations, check fees against execution statements. Correct an error with `operation fees ID AMOUNT`, as described in [chapter 08](en_08_monitoring_a_trade.md#correct-fees-on-a-recorded-operation), then check `trade results`. This changes the recorded portfolio's net results; `backtest` and `score` recreate their operations and fees from their own settings.
