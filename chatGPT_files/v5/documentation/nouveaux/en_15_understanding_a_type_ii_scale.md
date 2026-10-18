# Understand a type II scale

In ordinary operation, type II calculates the next price by applying rate `vr` to the **last executed operation's price**, adjusted for a split when necessary. It retains positions and holding coefficients, without a `kc` price coefficient list.

**After `reinit=reset`, the price supplied to reset immediately replaces the latest operation's price for the first orders.** If reset accompanies a split, this price already uses post-split units. Subsequent operations then resume using their actual execution price as the basis. With `merge`, Jedi first waits for the manual transaction establishing the new reference. [Chapters 09](en_09_adapting_or_ending_a_trade.md) and [16](en_16_continuity_between_settings.md) cover these cases.

Our fictional example uses `vr:20%` to make the differences easy to see, with 100 shares at €10 and a €0.01 tick:

~~~text
vr:20%,ks:0.8,1.2,ki:10%,kb:1
~~~

## Calculate the next price

From an execution at €10, the next theoretical price is €12 upwards and €8 downwards. After an execution at €12, a fall targets €12 × 0.80 = **€9.60**.

A 20% rise followed by a 20% fall does not return to €10. The percentages apply to different prices. A 20% fall followed by a 20% rise also gives €9.60 from €10.

The current market price locates the orders; it does not replace the last execution price in this formula.

## Replay both round trips

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=vr:20%,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 1 -1 -1 1
~~~

| Operation | Position | Tick-compliant price | Holding |
|---|---|---:|---:|
| Opening purchase | `0:0:0` | €10 | 100 |
| Sale of 20 | `0:0:+1` | €12 | 80 |
| Repurchase of 20 | `0:0:0` | €9.60 | 100 |
| Purchase of 20 | `0:0:-1` | €7.68 | 120 |
| Sale of 20 | `0:0:0` | €9.22 | 100 |

The last theoretical price is €7.68 × 1.20 = €9.216. For this Limit sale, it rounds up to €9.22. The next calculation will start from the executed €9.22 price.

Purchases total €1,345.60, sales €424.40 and current investment €921.20. The 100 shares at €9.22 are worth €922: a gross result of **€0.80**. The two round trips nevertheless produced €78.80 in cash; the fall in holding value also matters.

Comparison with type I illustrates the mechanics. The same directions produce other prices; this is not a historical profitability ranking.

## Understand adjustment on a jump

Boundaries remain `+2` and `−2`. On a jump, Jedi adjusts the new level's price reference to the path's price. For an order, it uses the theoretical price; for a recorded operation, the actual execution price.

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=vr:20%,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 2 -2
~~~

| Operation | Position | Quantity | Price | Holding |
|---|---|---:|---:|---:|
| Buy Market | `0:0:0` | 100 | €10 | 100 |
| Sell Limit | `0:0:+1` | 20 | €12 | 80 |
| Sell Limit | `1:0:0` | 4 | €14.40 | 76 |
| Buy Limit | `1:0:-1` | 16 | €11.52 | 92 |
| Buy Limit | `1:1:0` | 15 | €9.21 | 107 |

At the upward jump, the theoretical capital reference is €1,100. At €14.40, the theoretical holding is approximately 76.388889, rounded to 76 for the order. At the last jump, €9.216 rounds down to €9.21 for the purchase.

Price rounding affects subsequent calculations. An unrounded calculation and a tick-compliant executed path can therefore diverge after several movements.

## Build the holding with np, nn and kd

~~~console
jedidemo scale create --name=B_vr_04 \
  --comment="Teaching builder" \
  --builder="vr:20%,np:2,nn:2,ki:10%,kb:1,kd:0"
jedidemo scale show B_vr_04
~~~

Create this name once. `np:2,nn:2` sets two movements to each boundary, with one interior step per side. `kd:0` distributes changes evenly. The expanded definition contains **`ks:0.88,1.2`**.

It therefore differs from our first list, `ks:0.8,1.2`. Read `scale show` before comparing orders. Other `kd` values change the distribution as in type I.

The historical form using `sr` and `mi` remains available for compatibility, with its own rules. [Appendix 01](en_annex01.md#scale-definitions) describes that syntax; the usual reading path uses the forms above.

## Read orders even when the scale is optimised

The type II optimised check uses a sequence of movements in the same direction. After oscillations, the jump price can differ from that reference sequence.

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=vr:20%,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 1 -1 1 -1 1 1
~~~

Immediately before the last jump, 80 shares remain after a sale at €11.06. The jump targets a theoretical price of €13.272 and an integer holding of 83. Jedi simulates **a Stop purchase of 3 shares at €13.28**, even though the scale passed the optimised check.

That label does not replace inspection of modes and quantities. [Chapter 16](en_16_continuity_between_settings.md) examines how a trade continues under new settings.
