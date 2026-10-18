# Evaluating an opening with tools candidate

## Two questions before opening

`candidate` evaluates a trade proposal at a supplied or recorded price. It checks:

- **operability**: can the quantities produce the useful orders being checked?
- **funding**: do free funds cover the opening and projected additional purchases?

These results remain separate. The command does not find the security or select its scale. It requires no OHLCV history, creates no trade and sends no order.

## Identify the security, price and scale

The candidate argument is an **ISIN**, not a ticker. A price explicitly supplied with `--price` overrides the main database price. It even allows evaluation of a security not yet recorded there.

Without `--price`, the security must have a recorded price in the main database. The report states its origin and, for a recorded price, its known date. A market database's last close is not used automatically.

A supplied price does not inherit the date of an old stored quotation. The user checks the date and suitability of the supplied price.

`--scale` accepts an existing scale name or a literal definition. After `score`, copy the builder without the `I:` or `II:` display prefix.

## Choose the opening amount

Here is a **fictional** example, with no other committed trade in the main database:

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0" \
  --amount=1000 --capital=5000
~~~

`--amount=1000` sets the desired first-purchase amount. At €10, it corresponds to 100 shares. When the amount is not exactly divisible by price, Jedi uses a whole quantity; the actual committed amount can be smaller than requested.

`--capital=5000` supplies portfolio capital for the funding check. This capital and the opening amount serve different purposes.

Actual output:

~~~text
Opening quantity :               100
Actual opening amount :          1000.00 €

Operability :                    YES
Funding :                        YES
Capital free after reserve :     5000.00 €
Candidate maximum requirement :  1187.83 €
Margin after candidate :         3812.17 €
Candidate reserve calculated over 3 steps; funding excludes fees.
~~~

The proposal requires more than its initial purchase: an additional €187.83 is reserved for the projected path. The scale is also displayed through its complete operational definition.

## Size using capital management

The second form uses `--money` instead of `--amount`:

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0" \
  --money="r:1%,o:1,n:2" --capital=10000 --extended
~~~

The selected values explain the calculation here.

| Parameter | Meaning |
|---|---|
| `r` | Capital proportion used to calculate monetary risk. |
| `n` | Number of downward steps used to calculate the StopLoss distance. |
| `o` | Multiplier of the monetary target used for gain protection. |

With €10,000 and `r:1%`, calculated risk is €100. The scale gives a theoretical price of €8.10 two steps below €10, a distance of 19%. This gives a theoretical amount of €526.32 and 52 shares for €520.

Selected values from the extended output:

~~~text
Risk amount R :                  100.00 €
Opening quantity :               52
Actual opening amount :          520.00 €
Minimum operable quantity :      32
Operability :                    YES
Candidate maximum requirement :  617.56 €
Margin after candidate :         9382.44 €
~~~

The calculation also considers the capital limit along the risk path and useful minimum quantities. It can refuse an opening when no whole quantity meets all constraints.

Without `--capital`, Jedi uses the capital configured for trades. If no positive capital is available, funding can be shown as “not evaluated”; that does not mean it has passed.

## Choose r, o and n in practice

Start by expressing risk in euros, then relating it to the selected capital. With €10,000, 1% is €100 and 2% is €200. Increasing `r` increases accepted risk and can increase quantity; it is not a neutral way to remove a refusal.

Choose `n` after reading the scale: two steps do not represent the same percentage for different movement sizes. More steps generally place the StopLoss farther away and, for identical monetary risk, produce a smaller opening quantity.

This comparison uses three commands executed on our example, changing one parameter at a time:

| Capital | r | n | Calculated distance | Quantity | Initial purchase | Maximum requirement excluding fees |
|---:|---:|---:|---:|---:|---:|---:|
| €10,000 | 1% | 2 | 19.00% | 52 | €520 | €617.56 |
| €10,000 | 2% | 2 | 19.00% | 105 | €1,050 | €1,253.22 |
| €10,000 | 1% | 3 | 27.10% | 36 | €360 | €425.88 |

Here are the three complete commands, in the same order as the table rows:

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0" \
  --money="r:1%,o:1,n:2" --capital=10000 --extended

jedidemo tools candidate FR4487601001 --price=10 \
  --scale="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0" \
  --money="r:2%,o:1,n:2" --capital=10000 --extended

jedidemo tools candidate FR4487601001 --price=10 \
  --scale="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0" \
  --money="r:1%,o:1,n:3" --capital=10000 --extended
~~~

`o` multiplies monetary risk to define the target used for gain protection. With €100 risk, `o:1` gives a €100 target and `o:2` gives €200. It does not directly set the opening quantity. Triggering depends on the result projected after `n` downward steps and the trade path; it is not simply “sell when current gain reaches €100”.

For initial learning exercises, keeping `o:1,n:2` and changing one parameter at a time makes comparisons readable. These example values do not by themselves determine suitable risk for every investor. Chapter 18 and `tools play` will show the effects on protective orders.

A StopLoss can execute beyond the calculated price, particularly during a gap. Calculated risk is therefore not a guaranteed loss limit. Also examine aggregate risk across committed trades.

## Understand operability

Operability checks whether useful orders retain a sufficient quantity. The default is at least two shares per order and three upward steps checked, according to `diagnostic_steps` in the configuration.

`--minimum-quantity` and `--operability-steps` change this check. Reducing requirements changes the question asked; it does not automatically solve fees or liquidity.

For our scale, the calculated initial minimum is 32 shares. With €5,000 capital, `r:1%,o:1,n:2` allows only 26 shares under the risk constraint. The proposal is refused for insufficient quantity. The display gives zero opening quantity and the reason, although free capital is available.

## Understand reserves and funding

Jedi takes portfolio capital, subtracts current net investment, then reserves projected additional purchases for trades still holding shares. The remainder is **capital free after reserve**.

For the candidate, maximum requirement is the initial purchase plus its own reserve. **Margin after candidate** is capital free after reserve minus this requirement.

Projection explores upward and downward paths over the chosen horizon. For reserves, this horizon is `diagnostic_steps`, increased to `n` when capital management uses a larger `n`. It is separate from the operability option.

Fees are excluded from this funding projection. Requirements beyond the horizon, new decisions and actual execution conditions can change the outcome. Leave room for these differences.

With the same €1,000 opening and only `--capital=1000`, the result is:

~~~text
Operability :                    YES
Funding :                        NO
Candidate maximum requirement :  1187.83 €
Margin after candidate :         -187.83 €
~~~

The initial purchase fits the amount, but funds do not cover the projected reserve. A favourable price or historical result does not change this calculation.

## When existing trades have exceeded R

A loss greater than calculated risk `R` can occur, for example after a gap or an interruption in monitoring. Capital management with `money` cannot retrospectively restore that limit. When calculating orders, Jedi can warn that a trade is out of control if its loss at the current price exceeds `R`.

**`candidate` does not automatically block a new opening for this reason.** It does not compare other trades' current losses with their `R`. It continues to include all trades still holding shares in reserves, including those that have exceeded this risk. Their reserve is projected from the last recorded state and scale over the chosen horizon; it does not assume that a StopLoss liquidated the trade.

Funding uses net investment: recorded purchases minus recorded sales in the main database. It does not replace this commitment with the shares' current market value. A recorded sale at a loss therefore affects calculated funds; an unrealised loss is not deducted as an additional risk budget. Capital used to calculate the candidate's `R` remains the value supplied by `--capital` or configuration. It is not automatically recalculated from other trades' losses.

With several trades in this situation, `candidate` can therefore display “funding: YES” when funds cover commitments and reserves. This result validates that funding calculation; it does not validate aggregate portfolio risk or continuation of troubled trades.

To examine existing trades' warnings, run:

~~~console
jedidemo trade orders
~~~

The extended `candidate` report, requested with `--extended` in the commands above, details net investment, total reserve and each trade's reserve. Record exceptional incidents and decisions with `note`, identifying the trade concerned; separately record operations actually executed.

## Read a refusal before changing the proposal

| Result | What to check |
|---|---|
| No price available | Supply a valid price or record a quotation for the security. |
| Zero opening quantity | Amount, price and whole quantity. |
| Insufficient quantity | Scale, useful quantities and risk settings. |
| Capital is limiting | Initial purchase and projected investment on the risk path. |
| Negative margin | Free funds and reserves for existing trades and the candidate. |

`--extended` supplies useful details. Prices, amounts and capital must be positive and finite; `--amount` and `--money` are incompatible.

Before opening, retain the ISIN, checked price, scale definition, settings and report. Chapter 07 then explains broker execution and actual recording in Jedi.
