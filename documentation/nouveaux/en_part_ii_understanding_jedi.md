# Understand Jedi's mechanics

Part I showed how to prepare and monitor a trade. This part explains how a scale connects price movements with share quantities, orders and committed capital.

The prerequisite is familiarity with the practical path: chosen security, scale, settings, order and executed operation. More precise concepts are defined when first used. Formulas follow explanations in ordinary language.

Chapters 11 and 12 explain flows, positions, steps and levels. Chapters 13–15 present scale structure and its two types. Chapter 16 covers continuity across settings changes. Chapters 17 and 18 connect this state with orders, risk and sizing. Chapters 19 and 20 check calculations and follow a complete example.

## Prepare the mechanics examples

Most examples start with **100 fictional shares at €10**, a type I scale and a €0.01 tick. This scale differs from EXA01's type II in part I. Chapter 15 compares a type II at 20%. Chapters 18 and 20 also use 125 shares to illustrate sizing.

Paths are calculated with `tools play` and, for type I, `tools calc`. They require neither downloads nor quotation file imports. Movements are chosen to show the calculation, without claiming to represent a real market.

Use [chapter 02's experiment environment](en_02_installing_and_preparing_jedi.md#prepare-a-separate-experiment-environment). Fees are **0.35%, without a minimum**. For chapter 18's protections, add this to that environment's configuration:

~~~yaml
simulation:
  capital: 20000
~~~

This capital applies to `play`. `candidate` capital is explicitly supplied by `--capital=20000`. Its evaluations assume a database with no open trades. Teaching scale creations and notes write to the experiment database; paths defined directly in `play` remain in memory.

The [example guide](../../examples/README.md#english) recalls these conventions. Start with [chapter 11's flows](en_11_round_trips_and_trade_flows.md), then follow chapters in order.

By the end of this part, readers can explain a holding change, understand a Limit or Stop order, distinguish protective StopLoss and read the effects of `r`, `o` and `n`. Understanding these calculations helps check the process; its historical results will be studied in part III.
