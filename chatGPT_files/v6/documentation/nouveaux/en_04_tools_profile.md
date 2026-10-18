# Shortlisting with tools profile

## What the command provides

`profile` describes a security's behaviour and compares a population to help establish a list of choices. It checks quotation quality, applies rejection and caution rules, then ranks the retained securities.

The ranking is transparent: it sums ranks without weighting. The reader can choose how many criteria contribute to the total and consult the values explaining those ranks.

## Prepare the examples

The calculated examples in this chapter use three fictional securities. Their files are in **examples/** at the root of the documentation archive; the [example guide](../../examples/README.md) explains settings and the working directory.

Before running `--database=demo --dataset=Demo`, complete [the Demo database preparation at the start of chapter 10](en_10_market_database.md#the-demo-database-for-the-examples), through the update of all three securities to 2 October 2026. That procedure creates the database; `profile` does not.

The command using [cotations_EXA.txt](../../examples/cotations_EXA.txt) reads this file directly from `examples/` and requires no import. The `abcbourse` and `Euronext_A` examples below assume that the user has prepared those data.

## Choose the population

~~~console
jedidemo tools profile --database=abcbourse --dataset=Euronext_A --rank-criteria=4
~~~

`--database` selects a market database source. `--dataset` selects an imported collection. The universe used in the database name comes from the configuration, or from `--universe` when specified.

Other possible selections:

| Requirement | Options |
|---|---|
| All members of a group | `--group=PEA` |
| Group members belonging to a dataset | `--dataset=Euronext_A --group=PEA` |
| One identified database security | `--security=RNO` or its ISIN |
| Several identified securities | Repeat `--security` |

An individual file can also be examined:

~~~console
jedidemo tools profile cotations_EXA.txt
~~~

With a file, the report describes one security; it establishes neither a population ranking nor a dataset freshness reference.

## A recent window and a checking history

Trend, liquidity, oscillation, maximum drawdown, gaps and the suggested step use the security's **last 252 sessions**. Volatility uses a **20-session ATR**. ATR averages daily true ranges, including differences from the previous close; it is expressed as a percentage of the last close.

252 sessions roughly correspond to one trading year. This window describes recent behaviour. Jedi nevertheless keeps the longer history to check data quality and continuity.

The main quality checks require at least **three years of history** and a **minimum density averaging 180 quotations per year**, over that entire history. Jedi calculates density by dividing the number of available quotations by the time between the first and last dates, expressed in years of 365.25 days.

**180 is a quality threshold set in Jedi**, intended to reject overly sparse histories. It does not describe the usual number of sessions in a trading year or replace the recent 252-session window. The average covers the whole period; it does not ensure that every year is complete.

Inconsistent OHLC prices, too many sessions without volume or too many unchanged closes can also reject the security. These requirements explain why a file limited to 252 rows can be insufficient.

The individual report states the dates actually examined. Available sessions in each history determine the window: a lagging security can have a shifted window.

## Read the statuses

| Status | Practical meaning |
|---|---|
| Retained | No rejection or caution condition detected by these checks. |
| Caution | The security remains in the ranked list, with points to examine. |
| Rejected | At least one rejection rule is triggered. |

The main rules are:

| Measure | Rejection | Caution |
|---|---|---|
| Annualised trend | At or below −12% per year | Also examine the path and other measures. |
| Median daily close × volume | Below €100,000 for euro-based examples | More than 30% of sessions fall below this amount. |
| ATR20 | Below 1.5% | Above 6%. |
| Oscillations of at least 5% | — | Fewer than four per year. |
| Maximum drawdown | — | Above 45%. |
| Gaps of at least 3% | — | Present in more than 3% of sessions. |
| Quotation lag | More than two sessions | One or two sessions. |

The median is the central daily traded value: it reduces the influence of a few exceptional days. Trend is calculated from the whole window, rather than simply from its first and last prices.

Liquidity is measured in the monetary unit of the imported prices. The numeric threshold of 100,000 performs no currency conversion. For non-euro data, account for their unit.

## The seven criteria, in ranking order

| Order | Criterion | What to examine |
|---|---|---|
| 1 | Trend | A less unfavourable or more favourable direction receives a better rank. |
| 2 | Liquidity | A higher median traded value receives a better rank. |
| 3 | Volatility, ATR% | Jedi first ranks volatility bands, then values within the same band. |
| 4 | Oscillation | Number of oscillations and range; classes consider both measures. |
| 5 | Maximum drawdown | A smaller decline receives a better rank. |
| 6 | Gaps | A lower frequency receives a better rank. |
| 7 | Suggested step | A smaller step receives a better rank. |

For volatility, the 2–5% band ranks ahead of the 1.5–below 2% and above 5–6% bands. Still higher volatility calls for caution. “More volatile” therefore does not systematically mean “better ranked”.

Oscillation favours sufficiently frequent movements of at least 5%, accompanied by a sufficient range. `Sw5/y` counts the first significant movement and subsequent reversals, annualised; it does not count complete round trips or Jedi operations. The individual report and help explain the bands used:

~~~console
jedidemo tools profile --help
~~~

The movements-per-year column estimates activity associated with the suggested step. It is additional information, not an eighth ranking criterion. The proposed step is a starting point for examining a scale.

## Start with the four main criteria

The `--rank-criteria=4` option sums the trend, liquidity, volatility and oscillation ranks. This provides a simple starting reading.

The application's default remains **seven criteria**:

~~~console
jedidemo tools profile --database=abcbourse --dataset=Euronext_A
~~~

`--rank-criteria=N` accepts 1 to 7. It uses the **first N criteria in the order above**. Subsequent criteria remain displayed and their cautions remain active.

In the ranks column, the vertical bar separates included ranks from informative ones. For example, `1/2/3/2 | 4/3/2` gives a total of 8 with four criteria. This sum is an illustration.

Identical values receive the same rank. The smallest total comes first; ties are resolved by comparing the included ranks in order, then by ticker. Changing the population can change ranks and totals.

## Read a calculated example

After [creating and updating the Demo database at the start of chapter 10](en_10_market_database.md#the-demo-database-for-the-examples), run from `examples/`:

~~~console
jedidemo tools profile --database=demo --dataset=Demo \
  --rank-criteria=4 --include-rejected
~~~

Here is a selection of columns from the actual output, shortened for readability:

| Ticker | Total | Trend/year | Median value | ATR20 | Oscillations/year | Status |
|---|---:|---:|---:|---:|---:|---|
| EXA | 4 | 3.7% | €774k | 3.4% | 8.3 | retained |
| EXB | — | −27.4% | €377k | 3.1% | 11.4 | rejected |
| EXC | — | −0.5% | €12k | 1.1% | 0.0 | rejected |

EXB has liquidity and oscillations, but its trend alone rejects it. EXC is rejected for insufficient liquidity and volatility. EXA is the only ranked security, so it receives rank 1 on each of the four criteria.

`--include-rejected` displays rejected securities with a dash for total and ranks. Their presence does not change the ranking of the others. Securities marked “caution” remain in the ranking.

To understand the reasons, consult the security individually:

~~~console
jedidemo tools profile --database=demo --security=EXA
~~~

## Understand freshness

Jedi uses the dataset's global freshness date: the latest date reached by **at least 95% of its securities**. This date is recalculated from stored quotations after import or update.

Lag is counted using the sessions present in the dataset database, up to this reference. It is zero when the security reaches or exceeds the reference, one or two sessions for caution, more than two for rejection.

This compares securities within the dataset. It does not measure distance from today's date: if the whole dataset has stopped receiving quotations, check the date shown by `market info`.

The freshness check is unavailable with a file or a historical `--date` or `--select` selection. It is also unavailable if the dataset reference is missing, or if a security belongs to several datasets without an explicit `--dataset` resolving the ambiguity. A dash in the lag column means “not assessed”, not “up to date”.

## Choose a few securities

Start with the four main criteria, then read cautions and the three additional criteria. Examine a large drawdown or frequent gaps before retaining a well-ranked row.

For a particular reading, use a named sort:

~~~console
jedidemo tools profile --database=demo --dataset=Demo --sort=liquidity
jedidemo tools profile --database=demo --dataset=Demo --sort=oscillation
~~~

Option values remain English in both languages. `--limit=20` limits displayed rows; it does not reduce the population analysed to calculate ranks.

Retain a few understandable securities, then examine their scales with `score` and their proposals with `candidate`. Ranking helps organise the choice; entry price, quantities and funding are examined separately.
