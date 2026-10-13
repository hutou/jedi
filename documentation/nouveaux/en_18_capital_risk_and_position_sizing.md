# Understand capital, risk and position sizing

A project must answer two questions: how many shares to buy initially, and how much capital to keep available for subsequent purchases. Capital management provides a risk framework for sizing. `tools candidate` also checks operability and funding, as in [chapter 06](en_06_tools_candidate.md).

Our figures describe simulations. The theoretical risk does not guarantee the maximum loss actually obtained: fees, rounding or adverse execution can increase it.

After a split, current gains and stop quantities use the **converted holding**, even before a new transaction has been recorded. With reset, the protection path starts from the new mechanical position. These adjustments do not zero the financial result: past purchases, sales and fees remain retained. With merge, automatic proposals wait for the manual transaction, as explained in [chapter 09](en_09_adapting_or_ending_a_trade.md).

## Give K, r, o and n a meaning

| Parameter | Practical question | Effect |
|---|---|---|
| `K` | What capital is allocated to trading? | Monetary basis of calculations. |
| `r` | What fraction can be risked per trade? | Monetary risk `R = K × r`. |
| `n` | How far down the scale should we examine a fall? | Price at `n` steps and sizing distance. |
| `o` | What projected gain must be exceeded before protecting it? | Monetary objective `O = o × R`. |

With `K=€20,000`, `r=2.5%`, `n=2` and `o=1`, risk and objective are each €500. `o=2` would raise the objective to €1,000 without changing the initial quantity.

With its original configuration, Jedi accepts `r` from 0.5% to 5%, `n` from 1 to 5, and `o` from 0.5 to 5. These bounds are configurable. Our values illustrate choices to examine; they are not recommendations for every portfolio.

A `money` definition requires all three fields `r`, `o` and `n`: none is implicitly completed. Without `money`, the scale works without the protections described here.

## Use the right capital

For a real trade, capital comes from `trading.capital`. For **`tools play`**, it comes from **`simulation.capital`**. `candidate --capital=20000` sets the capital for that evaluation without modifying configuration.

Before the protection examples, use [chapter 02's experiment environment](en_02_installing_and_preparing_jedi.md#prepare-a-separate-experiment-environment) and check its configuration file:

~~~yaml
simulation:
  capital: 20000
~~~

Fees remain 0.35%, without a minimum. Part I's €5,000 capital for Exa_01 belongs to another example. Changing only `trading.capital` does not change `play` capital.

## Size an opening

Our type I enters at €10. Two downward steps lead to €8, then €6. The distance from entry is 40%.

The risk-derived amount is `R/d`, with `d` expressed as a fraction: €500 ÷ 0.40 = **€1,250**, or **125 shares** at €10.

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --money=r:2.5%,o:1,n:2 --capital=20000 --extended
~~~

The ISIN identifies the fictional demonstration security. The command supplies the price; no downloaded quote is used.

| Useful result | Value |
|---|---:|
| Theoretical price after two steps | €6.00 |
| Risk distance | 40% |
| Monetary risk | €500.00 |
| Initial quantity | 125 |
| Opening amount before fees | €1,250.00 |
| Reported minimum operable quantity | 82 |
| Candidate maximum requirement before fees | €1,855.60 |
| Margin after candidate before fees | €18,144.40 |

Jedi compares risk, capital and minimum operability constraints. Risk limits the quantity to 125 here. The maximum according to capital on the risk path is 1,492; this does not allow the risk ceiling to be ignored.

The theoretical €6 price serves sizing. It is not a permanent instruction to sell at €6: the StopLoss evolves with operations.

## Keep a reserve for future purchases

The opening uses €1,250, but the downward path without protection requires further purchases:

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=125,c0=10,tick=0.01" -3
~~~

| State | Holding | Net investment before fees |
|---|---:|---:|
| Opening at €10 | 125 | €1,250.00 |
| Purchase of 25 at €8 | 150 | €1,450.00 |
| Purchase of 38 at €6 | 188 | €1,678.00 |
| Purchase of 37 at €4.80 | 225 | €1,855.60 |

`candidate` uses three steps here and a future reserve of **€605.60** beyond the opening. This horizon comes from the operational check and can exceed `n`. The projection examines the scale's full integer purchases; it does not assume that StopLoss will interrupt them.

Reserves for other open trades are deducted from free capital. Fees are excluded from this projection. Also allow for fees and examine requirements beyond the displayed horizon.

A fixed €1,250 opening with only €1,700 capital remains operable, but gives a margin of **−€155.60**:

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --amount=1250 --capital=1700 --extended
~~~

Being able to pay for the first purchase is therefore insufficient to fund the scenario.

## Choose parameters

Start with the assigned capital and the accepted loss amount for the project; derive `r`. Then examine the prices corresponding to `n` for the chosen scale: two steps do not always represent 40%.

These comparisons change one parameter at a time. Each command is complete:

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --money=r:1%,o:1,n:2 --capital=20000
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --money=r:5%,o:1,n:2 --capital=20000
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --money=r:2.5%,o:1,n:1 --capital=20000
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --money=r:2.5%,o:1,n:3 --capital=20000
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --money=r:2.5%,o:2,n:2 --capital=20000
~~~

| Settings | Risk R | Price after n steps | Retained quantity | Objective O |
|---|---:|---:|---:|---:|
| `r:1%,o:1,n:2` | €200 | €6.00 | 0: rejected | €200 |
| `r:2.5%,o:1,n:2` | €500 | €6.00 | 125 | €500 |
| `r:5%,o:1,n:2` | €1,000 | €6.00 | 250 | €1,000 |
| `r:2.5%,o:1,n:1` | €500 | €8.00 | 250 | €500 |
| `r:2.5%,o:1,n:3` | €500 | €4.80 | 96 | €500 |
| `r:2.5%,o:2,n:2` | €500 | €6.00 | 125 | €1,000 |

At `r:1%`, the risk constraint cannot reach the reported operable minimum. Jedi rejects the opening and retains zero shares. Increasing `r` to obtain “YES” also increases monetary risk: it must remain a risk decision.

Increasing `n` moves the risk price farther away here and reduces initial quantity. Reducing `n` increases quantity and funding needs. Choose `n` by examining prices, the security's usual movements and the required reserve.

Then inspect integer orders. The reported minimum does not ensure that every larger quantity produces large orders: rounding can make small differences vary irregularly. With `q0=100`, three rises sell 20, 1 and 16; with `q0=125`, they sell 25, 2 and 19. The current opening check does not revalidate every order for the final quantity; complement it with `play` and monitoring diagnostics.

## Understand loss control

During the trade, Jedi projects the result after `n` downward steps, including the scale's purchases and sales. If this result is below `−R`, it calculates a `CL` protection targeting that monetary loss.

~~~console
jedidemo tools play -c o0,6-14,17rf -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=125,c0=10,tick=0.01,money=r:2.5%,o:1,n:2,loss=fallback" -2
~~~

At opening, a StopLoss for 125 at €6 coexists with the ordinary purchase at €8. After buying 25 at €8, the holding is 150 and investment €1,450. Protection is recalculated as `(1450−500)/150`, approximately €6.333333, rounded to **€6.33**.

The ordinary purchase at €6 is removed because it is below protection. The simulation sells 150 at €6.33: **€500.50 gross loss** and **€8.40 fees**, or **€508.90 loss after fees**.

`loss=fallback`, the `play` default, first follows an available ordinary downward order, then StopLoss. `loss=active` would prioritise StopLoss on the first fall: the simulated chronology differs.

A gap below protection can worsen the loss. If the known price has already passed protection or the accepted loss, Jedi flags the problem; it cannot guarantee to recover an unexecuted sale.

## Understand gain protection

`GP` protection starts when the **projected gain after `n` falls** strictly exceeds `O`. A current gain of €500 is not necessarily enough for `o:1` and `R=€500`.

To observe `o`, simulate 25 round trips of 100 shares between €10 and €12. This deliberately repetitive scenario shows the threshold; it does not predict 25 real profit opportunities:

~~~console
jedidemo tools play -c o0,6-14,17r -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01,money=r:2.5%,o:1,n:2" "25x1,-1"
jedidemo tools play -c o0,6-14,17r -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01,money=r:2.5%,o:2,n:2" "25x1,-1"
~~~

Both paths finish with 100 shares at €10 and €1,000 gross profit. With `o:1`, gain-protection StopLoss orders appear during the path. With `o:2`, none appears: the projected gain has not exceeded €1,000.

Once `GP` is established, Jedi retains the protected monetary gain or raises it if the projection improves. Its price is recalculated when the holding changes. Protection is calculated before fees and remains subject to actual execution. A larger `o` delays activation here; it promises no larger gain and sets no immediate selling price.

After these checks, `tools backtest` can observe the scale on historical quotations. Its assumptions are explained in [chapter 22](en_22_simulating_with_tools_backtest.md).
