# Choosing a security

## Start with a working list

The security is the instrument to manage within a trade. Selecting it comes before choosing a scale and evaluating the amount to commit.

You can start with a personal watchlist, a market platform, an external screener or `tools profile`. In every case, the securities found form a list to examine. The user keeps the final choice.

To understand a result, record the population studied and the quotation date. An Euronext Growth list and a list spanning several markets compare different securities. The same security can change rank when the population changes.

## Four practical questions

| Main criterion | Question | Practical reading |
|---|---|---|
| Trend | Is the price broadly rising, falling or stable? | A persistent decline can lead to successive purchases and tie up capital. |
| Liquidity | What amounts are normally traded? | Compare this information with the proposed quantities and amounts. |
| Volatility | How large are daily price movements? | Small movements limit opportunities; large movements call for more attention. |
| Oscillation | Do movements regularly change direction? | Round trips depend on movements in both directions. |

A large daily movement and regular oscillation are different. A security falling sharply every day can be volatile while providing few upward reversals.

Three criteria complete this reading: **maximum drawdown**, the decline from a previous peak; **gaps**, differences between a close and the following open; and the **suggested step**, a movement size proposed as a starting point for examining a scale.

Chapter 04 explains the measures, thresholds and seven ranking criteria. Starting with the four main criteria helps read the report; additional cautions still need examination.

## Use an external selection

A screener filters a population according to conditions. The JEDI ProScreener in Appendix 03 uses daily bars and looks for a compatible trend, minimum liquidity and sufficient volatility. It also displays oscillation.

Explicitly choose the market or security list in the platform, then read the results for a completed session. Pick a few securities and examine their history, volumes and recent events.

External selection and `profile` should provide coherent lists on the main criteria. Differences can arise from the date, provider, price adjustments, trend calculation or available history. Perfect agreement between lists is not a selection objective.

The JEDI script and procedure are included in [Appendix 03](en_annex03_external_selection_scripts.md).

## Use a Jedi market database

To try commands before preparing your own data, follow [the start of chapter 10: the Demo database for the examples](en_10_market_database.md#the-demo-database-for-the-examples). It creates source `demo` and dataset `Demo`, then updates them. Chapter 04 uses them to explain `profile` results.

A market database organises histories into **datasets**, imported collections, and can bring securities together in **groups**, logical lists defined by the user.

~~~console
jedidemo tools profile --database=abcbourse --dataset=Euronext_A --rank-criteria=4
~~~

This command examines the securities in `Euronext_A` and sums their ranks on the first four criteria. Replace `abcbourse` and the dataset with those of the database actually prepared.

A group can combine securities from several datasets:

~~~console
jedidemo tools profile --database=abcbourse --group=PEA --rank-criteria=4
~~~

Combining `--dataset` and `--group` selects their intersection. `PEA` is a list stored in the database; its name does not automatically verify each security's eligibility.

Jedi's preparatory examples include French histories and the datasets `Euronext_A`, `Euronext_B`, `Euronext_C`, `Euronext_Access` and `Euronext_Growth`. These names do not prescribe which market the application must be used on.

## Work with an individual file

A market database is unnecessary when studying a security already chosen. A **prepared file** contains its quotations in a format Jedi can read, with its identity and checked OHLCV rows. Chapters 05 and 10 explain preparation.

The fictional [cotations_EXA.txt](../../examples/cotations_EXA.txt) file is in the **examples/** directory supplied with this documentation. Data are provided as usable companion files, separately from the chapter text. The [example guide](../../examples/README.md) explains terminal preparation and how to keep experiments separate.

After copying the files to `~/jedi-examples/` in chapter 02, the following commands use the file directly. `jedidemo` opens that directory; no market database import is needed:

~~~console
jedidemo tools profile cotations_EXA.txt
jedidemo tools score cotations_EXA.txt --sort=fitness --budget=40
~~~

The first report describes the security; the second searches for scales. A budget of 40 provides a short demonstration. The application's standard budget is 500.

`profile` calculates recent criteria on 252 sessions, with a quality check over the long history. `score` retains 750 sessions by default to simulate more situations. Chapter 05 explains the difference and how to examine another period.

## Move on to the trade proposal

After choosing a scale, evaluate the candidate with its ISIN, a scale definition and a checked current price:

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0" \
  --amount=1000 --capital=5000
~~~

This example uses a **fictional** security and price. It evaluates an initial purchase of 100 shares and the proposal's requirements. It does not read prices from the `EXA` file: the €10 price is supplied explicitly to illustrate the calculation.

Before retaining a security, read its cautions, examine the scale, check useful orders and funding. If a difficulty remains, choose another proposal or clarify the data rather than automatically retaining the first ranking row.
