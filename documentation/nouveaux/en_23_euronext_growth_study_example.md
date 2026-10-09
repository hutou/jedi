# Euronext Growth study example

## A path to reproduce, then adapt

This chapter shows how to organise a study of Euronext Growth securities: shortlisting at the end of 2024, searching earlier data, then checking 2025. Supplied files contain **three fictional securities**, EXA, EXB and EXC; they are not an Euronext Growth export. The dataset name demonstrates study organisation.

Outputs are calculated on these demonstration data. They show neither the Growth market's return nor that of actual securities. Written after 2025, this example is **retrospective**: command dates constrain calculations without turning the exercise into a decision actually made in 2024.

## Prepare a frozen historical database

After installing the launchers in [chapter 02](en_02_installing_and_preparing_jedi.md), copy TXT files from `examples/` to `~/jedi-examples/`. Use a main experiment database without committed trades and these settings in its configuration:

~~~yaml
fees:
  rate: 0.0035
  min: 0.0
simulation:
  capital: 20000
  risk_rate: 0.015
  distance: 0.2
~~~

`Growth_demo_2021_2025.txt` contains 3,909 quotation rows: 1,303 weekdays per security from 4 January 2021 to 31 December 2025. `labels_growth_demo.txt` supplies identities. Membership stays fixed; the simplified calendar includes public holidays.

Create a database separate from Demo, once:

~~~console
jedidemo market init growthdemo
jedidemo market import growthdemo Euronext_Growth \
  Growth_demo_2021_2025.txt labels_growth_demo.txt
jedidemo market info growthdemo --dataset=Euronext_Growth
jedidemo market list growthdemo --dataset=Euronext_Growth --last-quote
~~~

Check three securities, 3,909 quotations and a final quotation of 31 December 2025 for each. Do not extend this database through a 2026 update: it is this study's frozen input.

## Shortlist using end-2024 data

~~~console
jedidemo tools profile --database=growthdemo --dataset=Euronext_Growth \
  --date=le:2024-12-31 --rank-criteria=4 --include-rejected
~~~

The calculation has four years of historical depth and uses the last 252 sessions through that date for recent criteria. It gives:

| Security | Total | Trend/year | Median traded value | ATR20 | Sw5/year | Status |
|---|---:|---:|---:|---:|---:|---|
| EXA | 6 | 10.2% | €1.2M | 3.5% | 12.5 | retained |
| EXC | 6 | 1.8% | €737k | 3.5% | 20.8 | retained |
| EXB | — | −19.9% | €741k | 3.4% | 9.4 | rejected |

The first four ranks form the total; the other three remain informative. EXB is rejected for trend. EXA and EXC have the same total: EXA appears first through rank tie-breaking in importance order. EXB does not contribute to these ranks.

Current freshness is not assessed because history is filtered. Check that all three histories reach the end of 2024; the end-2025 freshness date shown by `market info` does not measure a lag here.

Choose EXA for the rest of this exercise. In an actual study, also record why it was selected over EXC.

## Search for a scale before 2025

~~~console
jedidemo tools score --database=growthdemo --security=EXA \
  --date=le:2024-12-31 --select=l750 --sort=fitness --budget=40
~~~

The selected period is **2022-02-16 → 2024-12-31**, or 750 sessions. Adaptive search evaluates 40 scales among 11,793 available candidates. The first compact result is:

~~~text
Fitness    Op/mo   Max.inv  Typed builder
  0.437    0.924    1.000  I: kc:1.5,1.38,1.23,1.14,0.52,0.4,
                             ki:0%, kb:1, kd:0.2
~~~

The definition is split over two lines here for readability; pass it as a single value in the command. Gross fitness of 0.437 covers the search period without deducting fees. It does not predict 2025 fitness. The limited budget means the first row is best under the selected sort among scales actually evaluated.

For this exercise, fix that definition, fees of 0.35%, €1,500 requested per opening and default execution conventions. An actual choice also requires understanding the mechanics and checking operability at the contemplated opening price.

## Check the choice on 2025

~~~console
jedidemo tools backtest --database=growthdemo --security=EXA \
  --date=ge:2025-01-01 \
  --scale="kc:1.5,1.38,1.23,1.14,0.52,0.4,ki:0%,kb:1,kd:0.2"
~~~

The database ends on 31 December 2025, so the lower date bound isolates that year. The test starts with a new trade; it does not carry positions from the search path.

~~~text
History: 2025-01-01 → 2025-12-31 (261 sessions)
First purchase: 2025-01-01, 108 shares for 1498.56 €
Operations including openings: 7
Cumulative gross gain: -13.11 €
Total fees: 7.10 €
Cumulative net gain: -20.21 €
Maximum investment excluding fees: 1498.56 €
Net gain / maximum investment: -1.35%
Shares held at the end: 108; value 1450.47 €
~~~

The favourable search path is followed by a slightly negative net result. Sales and repurchases produce round trips, but final holdings also contribute to the result. Adding `-c rfo` displays the seven operations.

The 1 January start reflects the fictional calendar, not an actual market session. The result describes this file, scale and conventions. Keep it unchanged before trying other settings.

## Keep commands and results

~~~bash
study_dir="$HOME/jedi-study-growth-2025"
mkdir -p "$study_dir"
jedidemo version > "$study_dir/version.txt"
jedidemo config > "$study_dir/config.txt"
jedidemo tools score --database=growthdemo --security=EXA \
  --date=le:2024-12-31 --select=l750 --sort=fitness --budget=40 \
  > "$study_dir/score-before-2025.txt"
jedidemo tools backtest --database=growthdemo --security=EXA \
  --date=ge:2025-01-01 \
  --scale="kc:1.5,1.38,1.23,1.14,0.52,0.4,ki:0%,kb:1,kd:0.2" \
  > "$study_dir/backtest-2025.txt"
~~~

These redirections keep standard reports; `score` progress may remain visible in the terminal. Attach both source files, the security list, question and selected definition. [Chapter 24](en_24_interpreting_comparing_and_monitoring.md) explains the dated journal; a note written today must use its actual date.

## Move to actual data

Prepare securities actually present on Euronext Growth at the selected date, with their histories and relevant corporate actions. Describe exclusions and data availability for companies that left the market. Check currency and volume units.

Import these files into **another study database**, with a distinct name and explicit final boundary. Adapt source and security names in the commands. Keep shortlisting, search and verification separately.

If several securities are simulated separately, their maximum investments and gains do not automatically describe a fundable portfolio: purchases may coincide. Then examine opening projects and reserves with `candidate` at the price and date of the actual decision.
