# Searching for a scale with tools score

## A search for an already chosen security

`score` simulates several scales on one security's history and ranks those it has evaluated. The security comes from the user's choice, `profile` or an external selection.

Standard use combines an **adaptive** search, **raw** ranking and **compact** display. “Raw” means results directly sorted using the three displayed measures. Adaptive search explores configurations, then examines promising areas more closely according to the selected sorting criterion.

## Choose the quotations

From an individual file:

~~~console
jedidemo tools score cotations_EXA.txt --sort=fitness --budget=40
~~~

From an existing market database:

~~~console
jedidemo tools score --database=demo --security=EXA --sort=fitness --budget=40
~~~

The filename is a positional argument. For database use, `--database` identifies the source and `--security` the ticker or ISIN. `--universe` selects a universe other than the configured default.

## What “prepared file” means

A prepared file is a history acquired from an identified source, converted into the format Jedi reads and checked before use. For one security, the recommended first row contains **ISIN; ticker; name**. Subsequent rows contain **ISIN; date; open; high; low; close; volume**.

Valid extract from the supplied fictional file `cotations_EXA.txt`:

~~~text
FR4487601001;EXA;Exemple A
FR4487601001;20230630;10.0000;10.1800;9.8200;10.0000;60000
FR4487601001;20230703;10.1075;10.2895;9.9173;10.0990;61000
~~~

These two quotations illustrate the format; they are insufficient for a representative study. The supplied file contains 851 fictional sessions, from 30 June 2023 to 2 October 2026.

Every row must concern the same ISIN. Prices use a decimal point; the dates above are year, month, day. Chronological ordering makes checks easier. Avoid duplicates, check missing sessions and identify any price corrections.

Provider exports can require conversion before reading: keep the required columns, add the ISIN and adapt dates. `market` commands do not download these files. Chapter 10 distinguishes individual files from multi-security import files.

## Why 750 sessions after a profile over 252?

`profile` examines recent security behaviour, mainly over 252 sessions, roughly one year. `score` evaluates scale paths over **750 sessions by default**, roughly three years. This longer period exposes the mechanics to more movements and historical conditions.

These settings answer different questions: “how has the security behaved recently?” and “how did these scales operate over the selected history?” They do not demonstrate that these durations are always best.

With the demonstration file, the earlier command reports:

~~~text
History: 2023-11-20 → 2026-10-02 (750 sessions)
Requested opening amount: 1500.00 €
Search adaptive: 40 backtests, 11793 available candidates (budget: 40)
Partial search: the ranking covers the evaluated scales.
Ranking: transparent raw results (raw)
~~~

If the file contains fewer than 750 sessions, the report states the period actually available. The three-year check specific to `profile` is not an additional `score` rule.

## Budget and search

Without `--budget`, adaptive search has a budget of **500 search backtests**. In this chapter, 40 gives a short demonstration. The budget counts scales actually simulated, not displayed rows.

The search does not necessarily test every available candidate. Its conclusion concerns evaluated configurations; the first row does not prove a global optimum.

A progress percentage is displayed during calculation. Time depends on the budget, history length and scales. Exhaustive `--search=grid` remains available for detailed use and can take much longer.

## Read the three compact columns

Compact `raw` results are limited to the **first 20 scales**, or fewer when fewer were evaluated. The following three rows are a reference extract from the 1.0 edition’s fictional study, with a budget of 40. After the maximum-investment correction in v1.1, rerun the command to obtain values and ranking for your version:

~~~text
 Fitness   Op/mo   Max.inv  Typed builder
   0.433    0.644    1.000  I: kc:1.23,1.14,0.88,0.76, ki:0%, kb:1, kd:0.2
   0.416    0.532    1.000  I: kc:2.01,1.75,1.52,1.32,1.15,0.85,0.72,0.61,0.52,0.44, ki:0%, kb:1, kd:0.0
   0.414    1.960    1.050  I: kc:1.22,1.16,1.1,0.95,0.9,0.86, ki:0%, kb:1, kd:0.0
~~~

| Column | Meaning |
|---|---|
| Fitness | Final gross gain divided by the first purchase amount. `0.433` means roughly 43.3% of that first purchase over the whole period. |
| Op/mo | All operations, including openings, expressed per 21 sessions from the first operation. |
| Max.inv | Maximum investment divided by the first purchase, excluding fees. `1.050` means a peak of 1.05 times that purchase. |
| Typed builder | Type I or II followed by a definition that recreates the scale. |

Fitness is neither an annual rate nor a net return. Gross gain includes remaining holdings valued at the final close. A rise in the security can therefore contribute without coming from round trips.

Maximum investment is the largest of the successive trades’ peaks of purchases minus sales, excluding fees, as in backtest. It can exceed the first purchase when the mechanics call for additional purchases. Fees must be examined in the economic display or a backtest.

## Choose the sort

| Option | Primary criterion | Tie-breaking |
|---|---|---|
| `--sort=fitness`, default | Fitness descending | Activity descending, then maximum investment ascending |
| `--sort=activity` | Activity descending | Fitness descending, then maximum investment ascending |
| `--sort=investment` | Maximum investment ascending | Activity descending, then fitness descending |

Sorting compares measures rounded to three decimal places. The old numeric values `1`, `2`, `3` remain accepted; examples use explicit names.

In adaptive search, the criterion also guides refinement. Changing the sort can therefore change the scales evaluated as well as their order. To compare the paths of fixed scales, use their definitions in `backtest`.

High activity increases interventions and can lead to more fees. Low capital use and high fitness do not suffice to establish the real proposal's operability.

## Examine the economic display

~~~console
jedidemo tools score cotations_EXA.txt --sort=fitness --budget=40 --display=study
~~~

This display retains the ranking principle and adds net gain, the result relative to maximum investment, fees and operations. In the first row of our example, gross fitness of 0.433 becomes net fitness of 0.421; displayed fees are €19.

`Rnet%` and `Rann%` express net results relative to maximum investment. `Op/y` counts scale operations excluding openings on an annual basis; it does not exactly replace `Op/mo`. Rounded monetary amounts provide an overview.

`--ranking=jedi`, `--ranking=both` and `--display=technical` remain available for expert examination. Their details appear in [appendix 01](en_annex01.md#tools-score). Standard use starts with `raw`.

## Examine another period

~~~console
jedidemo tools score cotations_EXA.txt --sort=fitness --select=l252 --budget=40
~~~

This command uses the last 252 sessions. In our example, the first row over 750 sessions has fitness of 0.433; the first row over 252 sessions has fitness of 0.126 and a different builder.

These gains cover different durations and can concern different scales. Their simple comparison does not establish one window's superiority. Fixing a scale and simulating it over the intended periods allows its behaviour to be examined.

To end the search at a specific date:

~~~console
jedidemo tools score cotations_EXA.txt --date=le:2025-12-31 \
  --select=l750 --sort=fitness --budget=40
~~~

The date filter is applied before row selection. Codes are `ge` for “from”, `gt` for “after”, `le` for “up to and including”, and `lt` for “before”.

## Pass a scale to candidate

The `I:` or `II:` prefix identifies the type in the report; it is not part of the supplied value. Copy the text following the prefix:

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale="kc:1.23,1.14,0.88,0.76,ki:0%,kb:1,kd:0.2" \
  --amount=1000 --capital=5000
~~~

This definition comes from the first demonstration row. The €10 price and amounts are fictional. `candidate` checks the current proposal and displays the operational scale definition; it makes no purchase.

## Check a price with calc

For the type I scale copied above, Jedi can check the first upward step's price:

~~~console
jedidemo tools calc price \
  scale="kc:1.23,1.14,0.88,0.76,ki:0%,kb:1,kd:0.2" \
  position=0:0:1 c0=10 tick=0.01 dir=up
~~~

The resulting output starts with:

~~~text
price = round_up(cpe) = 11.4
  cpe = 11.4
~~~

The target position is the first upward step, the reference price is €10 and the tick size is €0.01. This checks one scale price rather than simulating the whole trade. For a type II scale or a sequence of operations, use `tools play`.

## Retain an understandable solution

First read dates, evaluated scale counts and measures. Then examine a few configurations, their activity, fees and capital requirements. Similar fitness can accompany very different trading rhythms.

Simulation uses the `backtest` engine, fixed-amount openings, `conservative` execution and orders active from the next session after opening. The requested amount comes from the simulation configuration and appears in the report. These examples use €1,500 per opening with Jedi's default configuration.

Keep the selected definition and study settings. Check its path over another period, then evaluate the candidate at the current price. Changing dates or settings after seeing the gains must be considered a new attempt.
