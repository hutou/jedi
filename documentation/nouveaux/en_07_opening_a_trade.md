# Opening a trade

## Move from the proposal to actual operations

[Chapter 06](en_06_tools_candidate.md) evaluated a proposal. `candidate` creates no security, scale, trade or purchase in the main database. It sends no order to the broker.

Opening has three stages: prepare the trade in Jedi, execute the purchase through the broker, then record the actual execution. An operation merely contemplated must not be recorded.

This chapter uses **EXA, an entirely fictional security**: an initial purchase of 100 shares at €10, a scale with 10% movements and €5,000 reference capital. Use an empty experiment database prepared in [chapter 02](en_02_installing_and_preparing_jedi.md#prepare-a-separate-experiment-environment). Historical EXA files can exist in a market database; they do not create this security in the main database.

## Check the proposal at the chosen price

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0" \
  --amount=1000 --capital=5000
~~~

In a database without other committed trades, the result gives:

| Information | Value |
|---|---:|
| Opening quantity | 100 |
| Initial purchase | €1,000.00 |
| Maximum requirement, opening and reserve excluding fees | €1,187.83 |
| Margin after candidate | €3,812.17 |

Operability and funding pass for this example. Recheck if price, amount, settings or portfolio commitments change before execution.

This example fixes an amount with `--amount` and leaves `money` disabled. If your proposal was sized with `--money`, use the same `r`, `o` and `n` when creating the trade. Capital used during management comes from `trading.capital`: the `--capital` supplied to `candidate` is not automatically stored for the trade.

## Record the security and a current price

First check whether the security exists:

~~~console
jedidemo security list EXA
~~~

Create it in our empty database:

~~~console
jedidemo security create --isin=FR4487601001 --name="Exemple A" --ticker=EXA \
  --tick-buy=0.01 --tick-sell=0.01 --tax-rate=0
jedidemo quote set FR4487601001 --price=10
~~~

For an actual security, check its ISIN, name, ticker, quotation ticks and any tax. The €0.01 ticks and zero tax are fictional choices in this example.

`quote set` records the price with the entry date and time. This price supports monitoring; it does not replace the purchase's actual execution price. The price supplied to `candidate` had not been written to the database.

## Retain the selected scale

Trade settings require a permanent scale in the main database. Store the candidate's definition under a name:

~~~console
jedidemo scale create --name=EXA-10 \
  --comment="Exemple avec mouvements de 10 %" \
  --builder="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0"
jedidemo scale show EXA-10
~~~

If the scale already exists, inspect and reuse it. When it comes from `score`, copy the builder without its display prefix `I:` or `II:`. The temporary name of a literal evaluation scale does not retain it permanently.

## Create the trade and its initial settings

~~~console
jedidemo trade create --name=EXA01 --security=FR4487601001
jedidemo trade show EXA01
~~~

The name identifies this management history and must be unique. `--security` accepts the security's ISIN or internal ID, not its ticker. If the proposal uses capital management, add the evaluated definition, such as `--money="r:1%,o:1,n:2"`, to the creation command.

Then associate the trade with the scale:

~~~console
jedidemo settings create EXA01 --scale=EXA-10 \
  --date=2026-09-21 --time=09:00:00
~~~

Before the purchase, these initial settings have position `0:0:0`, with `q0` and `c0` at zero. The first operation fills the reference quantity and price. Adaptation options `--split`, `--sync` and `--reinit` apply to a trade already having settings.

**Respect chronology across the whole main database.** New settings must be strictly later than the latest operation and settings, even for another trade. An operation must follow the latest global settings and cannot precede the latest global operation. Entered dates and times are interpreted in the terminal's time zone.

At this point Jedi knows the proposal, but no purchase is recorded yet.

## Buy through the broker and record execution

Place the purchase yourself, monitor execution and use the broker's confirmed values. Our example assumes 100 shares executed at €10, with €3.50 fees:

~~~console
jedidemo operation create EXA01 \
  --date=2026-09-21 --time=09:01:00 \
  --type=Buy --mode=Limit --quantity=100 --price=10 --fees=3.50
~~~

The first operation is a `Limit` or `Market` purchase according to the order actually executed. Its timestamp differs from the settings timestamp. Quantity and price are execution values; they can differ from the prior evaluation.

`--fees` supplies the operation's total fees, including any tax. If omitted, Jedi applies configured fees and the security's purchase tax. Enter definitive fees explicitly when provided by the execution statement.

An unexecuted purchase creates no operation. If executed in several fragments, wait until you can record consolidated execution; [chapter 08](en_08_monitoring_a_trade.md#handle-partial-execution) explains how.

## Check the opening and initial orders

~~~console
jedidemo settings list EXA01
jedidemo operation list EXA01 -c 0,6-14,17
jedidemo trade status EXA01
jedidemo trade orders EXA01
~~~

Stock must be **100 shares**, `q0` 100, `c0` €10 and position `0:0:0`. Net investment excluding fees is €1,000. Compare stock and the operation with the broker's statement.

The two operating orders obtained are:

| Type | Mode | Quantity | Price | Amount excluding fees |
|---|---|---:|---:|---:|
| Buy | Limit | 8 | €9.00 | €72.00 |
| Sell | Limit | 6 | €11.00 | €66.00 |

These rows are calculated proposals. You still have to place orders through the broker and monitor their execution. Do not record them as operations before they occur.

To examine an upward movement followed by a downward movement without changing database operations:

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  scale=vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0,q0=100,c0=10,tick=0.01 1 -1
~~~

The calculated path sells 6 shares at €11, then buys 6 at €9.90: stock returns to 100. `play` helps understand the scale here; it describes no actual execution and does not guarantee that path.

Retain the scale definition and opening report. [Chapter 08](en_08_monitoring_a_trade.md) continues this trade with monitoring and recording of an actual sale.
