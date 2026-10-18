# Round trips and trade flows

A rising price brings money into a trade only when a sale takes place. A falling price takes money out only when a purchase takes place. To read a trade, start with the unit price, the number of shares held and the purchases or sales actually executed.

This chapter uses **Example A, a fictional security**, with 100 shares bought at €10. It is a type I example, separate from Exa_01's scale in part I. The chosen prices explain the calculations; they describe no real market.

## Sell and buy back, or buy and sell back

A round trip consists of two opposite transactions for the same quantity. After both transactions, the holding returns to its previous size.

| Completed round trip | Money received | Money spent | Difference before fees |
|---|---:|---:|---:|
| Sell 20 at €12, then buy back 20 at €10 | €240 | €200 | +€40 |
| Buy 20 at €8, then sell back 20 at €10 | €200 | €160 | +€40 |

These differences become known when **both transactions have taken place**. After the sale alone, the repurchase is still pending; after the purchase alone, the resale is still pending. A proposed order is not a completed round trip.

## See the path in Jedi

`tools play` simulates chosen movements in memory. Chapters 13 and 14 will explain the scale. First read the resulting operations:

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 1 -1 -1 1
~~~

The warning about a future sale of a very small quantity concerns a continued rise beyond this round trip. It is explained in [chapter 12](en_12_positions_steps_and_levels.md#observe-both-jumps-with-play).

`1` requests an upward movement; `-1` a downward movement. `--` allows negative numbers to be passed as arguments. The backslashes continue the command, including inside the quotation marks.

| Operation | Flow before fees | Shares held | Current investment |
|---|---:|---:|---:|
| Opening purchase: 100 at €10 | −€1,000 | 100 | €1,000 |
| Sale: 20 at €12 | +€240 | 80 | €760 |
| Repurchase: 20 at €10 | −€200 | 100 | €960 |
| Purchase: 20 at €8 | −€160 | 120 | €1,120 |
| Resale: 20 at €10 | +€200 | 100 | €920 |

A sale reduces the holding and releases money; a purchase increases it and uses money. `play` executes the calculated orders at its scenario prices and records no operation in your portfolio.

## Understand investment and its maximum

**Current investment** is total purchases minus total sales, before fees. It ends at €920: €1,360 of purchases less €440 of sales.

**Historical maximum investment** is the highest current investment already reached. It is €1,120, after the purchase at €8. The following resale does not erase that maximum.

These figures are not the broker account balance: they track this trade's flows only. Future purchases may require an additional reserve, discussed in chapter 18.

## Add the value of the remaining shares

The two round trips earned €80 before fees and 100 shares remain. The result also depends on their value at the chosen price:

~~~text
holding value = shares held × chosen price
gross result = holding value − current investment
~~~

| Valuation of the same final holding | Value | Investment | Gross result |
|---|---:|---:|---:|
| 100 shares at €10 | €1,000 | €920 | +€80 |
| 100 shares at €9 | €900 | €920 | −€20 |

Profitable transactions therefore do not protect the remaining shares against a fall. The chosen price values the holding; it does not guarantee the price at which all shares could be sold.

## Keep fees separate

Jedi tracks fees separately. At 0.35%, with no minimum fee or transaction tax on this fictional security:

| Operation | Fees |
|---|---:|
| Opening purchase | €3.50 |
| Sale at €12 | €0.84 |
| Repurchase at €10 | €0.70 |
| Purchase at €8 | €0.56 |
| Resale at €10 | €0.70 |
| Total | **€6.30** |

At the final price of €10, the result after fees is **€73.70**. Current and maximum investment remain before fees. `trade results` distinguishes gross result from fees. In `play`, financial output `f` is gross. To read fees in the operations too, add column `16` to the selector: `-c o0,6-14,16-17`.

## When the return does not happen

After selling at €12, the price may keep rising without allowing a repurchase at €10. The trade then holds fewer shares for the next rise. After buying at €8, it may keep falling without allowing a resale: more shares remain exposed.

Immediately after that purchase, the holding is 120 and investment €1,120. At a price of €6, its value would be €720, a gross result of −€400. The first profitable round trip does not offset this fall.

A price change alone alters neither the holding nor recorded flows. [Chapter 12](en_12_positions_steps_and_levels.md) adds the mechanical position used to calculate what comes next.
