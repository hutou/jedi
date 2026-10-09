# From trade state to orders

An order compares the actual holding with the integer holding targeted by the scale. A positive difference is a purchase; a negative difference is a sale. Its price follows the mechanical direction and the security's tick size.

## Separate direction, type and mode

A price rise does not always require a sale, nor a fall a purchase. The scale determines the holding change:

| Mechanical movement | Transaction needed | Ordinary order mode |
|---|---|---|
| Up | Sell | Sell Limit |
| Down | Buy | Buy Limit |
| Up | Buy | Buy Stop |
| Down | Sell | Sell Stop |

A functioning Stop can therefore come from the scale. It does not necessarily mean liquidation or capital protection.

At the first step of our type I scale, selling 20 at €12 or buying 20 at €8 are two Limit proposals.

## Observe a functioning Stop

Another `ks` list can reverse the expected direction. Keep prices and replace the holding coefficients with `ks:0.4,1.8`:

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.4,1.8,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 2
~~~

The first rise sells 60 at €12, leaving 40. The jump targets 79 at €14: **a Stop purchase of 39 shares**.

On a separate downward path:

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.4,1.8,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" -2
~~~

The first fall buys 80 at €8, taking the holding to 180. The lower jump targets 150 at €6: **a Stop sale of 30 shares**. The trade is not liquidated; 150 shares remain.

The optimised check helps identify some reversals. It guarantees neither sufficient quantities after rounding nor absence of Stops on every type II path.

## Round to the tick size

An upward target rounds up; a downward target rounds down, using the tick for the purchase or sale concerned.

A €10.03 reference multiplied by 1.20 gives €12.036. With a €0.05 tick:

~~~console
jedidemo tools calc price \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  position=0:0:+1 c0=10.03 tick=0.05 dir=up
jedidemo tools calc price \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  position=0:0:+1 c0=10.03 tick=0.05 dir=down
~~~

The results are **€12.05** with `dir=up` and **€12.00** with `dir=down`. The second command shows the other rounding of the same number; it does not turn `+1` into a downward target. Declare the tick for the security and market concerned.

## Examine small quantities

An apparently substantial initial holding can produce a small order:

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 3
~~~

The three rises sell 20, **1**, then 16 shares. With the default minimum of two shares, quantity 1 indicates degraded functioning. A zero quantity blocks that direction and the order is not added to proposals. A warning can also identify a forthcoming small quantity.

[Chapter 18](en_18_capital_risk_and_position_sizing.md) explains why the opening check does not remove the need to reread orders after sizing and during monitoring.

## Distinguish StopLoss

With `money` capital management, Jedi can propose a StopLoss sale of the holding. Its state shows `CL` for loss control or `GP` for protection of a calculated gain. The net quantity option can account for the upward sale order.

This StopLoss comes from a financial projection and the trade state. It is not a third step. It can remove ordinary orders at or below its price. Chapter 18 explains its calculation and limits.

The price indicators in `trade orders` locate proposals relative to the known price. They do not prove execution or guarantee its price. After a partial execution, gap or cancellation, check the holding, orders still active and recorded operations.
