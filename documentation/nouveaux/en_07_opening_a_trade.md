# Opening a trade

## Move from the proposal to actual operations

[Chapter 06](en_06_tools_candidate.md) evaluated a proposal. `candidate` creates no security, scale, trade or purchase in the main database. It sends no order to the broker.

Opening has three stages: prepare the trade in Jedi, execute the purchase through the broker, then record the actual execution. An operation merely contemplated must not be recorded.

This chapter uses **EXA, an entirely fictional security**: an initial purchase of 100 shares at €10, a scale with 10% movements and €5,000 reference capital. Use an empty experiment database prepared in [chapter 02](en_02_installing_and_preparing_jedi.md#prepare-a-separate-experiment-environment). Historical EXA files can exist in a market database; they do not create this security in the main database.

## Prepare an entry on a rebound near support

[Chapter 03](en_03_choosing_a_security.md#read-the-chart-trend-support-and-resistance) describes chart-based security selection. A retained security can remain on watch until the chosen entry signal appears. Within a sideways or rising channel with oscillations, one scenario is to seek the first observable rebound after a return near support.

Before that return, record the support area, time frame and recovery criterion. One possible rule to test is to wait for a daily close above the high of the session that tested support. Touching the line followed by a small intraday movement does not meet this closing criterion.

These two sessions are entirely invented, within a channel from an area near €9.50 to resistance near €12:

| Session | Low | High | Close |
|---|---:|---:|---:|
| A: support test | €9.50 | €9.85 | €9.65 |
| B: start of recovery | €9.65 | €10.10 | €10.00 |

At B's close, the price exceeds A's high: the proposed criterion is met. The recovery can still fail. Waiting for this signal leads here to examining an entry around €10, above the €9.50 low. These observations are not taken from the EXA historical file.

Then check the proposal at a price at which the purchase can be executed. A later execution may differ from the signal's closing price. The teaching example below assumes actual execution at €10: the first scale sale will be at €11, below the observed resistance. Check this remaining room against the scale's levels; the following level may already exceed the channel.

Also examine a continued decline below support: proposed purchases, required reserve and the proposal's protection. A drawn channel does not cap losses or fund subsequent purchases. `candidate` evaluates rules and funding; it detects neither the channel nor the rebound.

Retain the reference areas and opening criterion with the proposal's records. Once the first purchase is recorded, its actual price becomes `c0` and its quantity becomes `q0`. Operating orders then follow the scale and capital rules. Jedi does not record the chart's support and resistance lines as orders or protection.

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

This example fixes an amount with `--amount` and leaves `money` disabled. If your proposal was sized with `--money`, use the same `r`, `o` and `n` after creating the trade's initial settings, before the purchase. Capital used during management comes from `trading.capital`: the `--capital` supplied to `candidate` is not automatically stored for the trade.

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

## Choose readable names

For a trade, use **`T_<ticker>_<number>`**: `T_exa_01`, then `T_exa_02` if a separate new trade is created on fictional security EXA. With ticker ERF, the label would be `T_erf_01`. The `T_` prefix identifies a trade; scales use `B_`. The ticker provides a short reference, while the full name and ISIN remain associated with the security.

At creation, supply this name through `--name` and choose an available number, displayed with at least two digits. This is a suggested naming convention; Jedi does not automatically derive the trade's name or number. The number identifies the trade, not its settings. A split, scale change or reinitialisation retains the name.

For a scale, let Jedi assign **`B_kc_NN` for type I or `B_vr_NN` for type II** by omitting `--name`. The type comes from the builder and the number is computed within that family. In our empty database, the first type II scale will be `B_vr_01`. [Chapter 13](en_13_reading_the_structure_of_a_scale.md#name-and-number-a-scale) explains naming and refusal of equivalent definitions.

Use unaccented letters, digits and underscores `_`, starting with a letter and using at least two characters. Names must be unique within their category and are case-insensitive. Jedi normalises their spelling: `T_EXA_01` becomes `T_exa_01`.

If the ticker contains a dot, hyphen or another character not accepted in the name, adapt this label using allowed characters. Adapting the trade's name does not change the ticker stored in the security's record.

This edition's examples adopt these names. A trade created under an older name remains usable; use its actual name in commands or correct it with `trade update --name`, as in chapter 09.

## Retain the selected scale

Trade settings require a permanent scale in the main database. Store the candidate's definition under a name:

~~~console
jedidemo scale create \
  --comment="Exemple avec mouvements de 10 %" \
  --builder="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0"
jedidemo scale show B_vr_01
~~~

If the scale already exists, inspect and reuse it. When it comes from `score`, copy the builder without its display prefix `I:` or `II:`. The temporary name of a literal evaluation scale does not retain it permanently.

## Create the trade and its initial settings

~~~console
jedidemo trade create --name=T_exa_01 --security=FR4487601001
jedidemo trade show T_exa_01
~~~

The name identifies this management history and must be unique. `--security` accepts the security's ISIN or internal ID, not its ticker. `trade create` creates the trade without `money`; this command no longer accepts `--money`.

Then associate the trade with the scale:

~~~console
jedidemo settings create T_exa_01 --scale=B_vr_01 \
  --date=2026-09-21 --time=09:00:00
~~~

The trade is now **configured**. If the proposal uses capital management, enable the evaluated definition at this stage with `trade update`, for example `jedidemo trade update T_exa_01 --money="r:1%,o:1,n:2"`. This chapter's numerical example keeps `money` disabled.

Before the purchase, these initial settings have position `0:0:0`, with `q0` and `c0` at zero. The first operation fills the reference quantity and price. Adaptation options `--split`, `--sync` and `--reinit` apply to a trade already having settings.

**Respect chronology across the whole main database.** New settings must be strictly later than the latest operation and settings, even for another trade. An operation must follow the latest global settings and cannot precede the latest global operation. Entered dates and times are interpreted in the terminal's time zone.

At this point Jedi knows the proposal, but no purchase is recorded yet.

## Buy through the broker and record execution

Place the purchase yourself, monitor execution and use the broker's confirmed values. Our example assumes 100 shares executed at €10, with €3.50 fees:

~~~console
jedidemo operation create T_exa_01 \
  --date=2026-09-21 --time=09:01:00 \
  --type=Buy --mode=Limit --quantity=100 --price=10 --fees=3.50
~~~

The first operation is a `Limit` or `Market` purchase according to the order actually executed. Its timestamp differs from the settings timestamp. Quantity and price are execution values; they can differ from the prior evaluation.

`--fees` supplies the operation's total fees, including any tax. If omitted, Jedi applies configured fees and the security's purchase tax. Enter definitive fees explicitly when provided by the execution statement. After recording, `operation fees ID AMOUNT` can correct this total on any operation; [chapter 08](en_08_monitoring_a_trade.md#correct-fees-on-a-recorded-operation) explains how to find its identifier and check the correction.

An unexecuted purchase creates no operation. If executed in several fragments, wait until you can record consolidated execution; [chapter 08](en_08_monitoring_a_trade.md#handle-partial-execution) explains how.

## Check the opening and initial orders

~~~console
jedidemo settings list T_exa_01
jedidemo operation list T_exa_01 -c 0,6-14,17
jedidemo trade status T_exa_01
jedidemo trade orders T_exa_01
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

## Recognise a trade's status

The following command lists all trades. The **Status** column, directly after
the name, identifies the recorded stage:

~~~console
jedidemo trade list
~~~

| Status | Situation recorded in Jedi |
|---|---|
| created | The trade is associated with a security, with no settings or operation. |
| configured | Initial settings with a scale exist, with no recorded purchase. |
| opened | Only the initial purchase is recorded and shares are held. |
| in progress | At least one operation follows the initial purchase and shares are still held. |
| closed | Operations exist and the last operation's holding is zero. |

Status is calculated from the complete history. A scale change does not return
a trade to configured. A personally decided operation also counts towards the
transition from opened to in progress. Deleting an operation can return the
trade to its previous stage.

To show only trades holding shares, covering both **opened** and **in progress**:

~~~console
jedidemo trade list -r
~~~

To select statuses, use the `status` field in the existing regex filter:

~~~console
jedidemo trade list "status=^configured$"
jedidemo trade list "status=^(opened|running)$"
jedidemo trade list "status=^closed$ && name=^T_exa"
~~~

The codes `created`, `configured`, `opened`, `running` and `closed` work in both languages. The displayed label in the active language is also recognised, such as `status=^in progress$` in English. Matching is case-insensitive; `&&` and `||` combine it with other fields. With `-r`, both filters apply. `--select` then selects from the retained rows.

The basic table uses indexes `0=id`, `1=name`, `2=status`, `3=money` and `4=stop`.
With `--extended`, it adds `5=security id`, `6=ISIN` and `7=security name`.
To show just the name and status:

~~~console
jedidemo trade list -c 1,2
~~~

These indexes apply to `trade list`; `operation list` keeps its own column
indexes. CSV also places `status` after `name`, using the stable codes `created`,
`configured`, `opened`, `running` and `closed`, regardless of display language.

Retain the scale definition and opening report. [Chapter 08](en_08_monitoring_a_trade.md) continues this trade with monitoring and recording of an actual sale.
