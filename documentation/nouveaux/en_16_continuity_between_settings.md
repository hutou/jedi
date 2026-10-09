# Maintain continuity between settings

A trade can change scale without restarting its history. Purchases, sales, fees and shares held remain those of the recorded operations. New settings must establish references consistent with the position reached.

[Chapter 09](en_09_adapting_or_ending_a_trade.md) gives the monitoring commands. Here we explain what Jedi preserves and recalculates.

## Change the local frame

An ordinary change retains step `e`. Level counters `x` and `y` restart at zero. Jumps already completed carry into cumulative coefficients:

| Coefficient | What it preserves |
|---|---|
| `kcpc` | Price multiplier from previous settings. |
| `kspc` | Holding multiplier from previous settings. |

Their initial value is 1. An ordinary change retains `c0` and `q0`, which do not automatically become the latest price and holding. It carries the multipliers needed for continuity.

Past positions are not rewritten. New settings use another local frame, identified by their rank in lists.

## Check a change without changing the scale

Three rises of our type I scale take 100 shares at €10 to 63 at €16.80, at position `1:0:+1`. Reapplying the same scale shows continuity without changing the rules:

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 3 \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 1
~~~

| Moment | Position in the frame used | Holding | Last execution price |
|---|---|---:|---:|
| Before change | Previous settings, `1:0:+1` | 63 | €16.80 |
| New starting point | New frame, `0:0:+1` | 63 | €16.80 |
| Next rise | New frame, `1:0:0` | 62 | €19.60 |

On changing, `kcpc=1.40` and `kspc=1.10/1.40≈0.785714`. With `c0=10` and `q0=100`, local references at zero correspond to €14 and 78.571429 theoretical shares. The retained step `+1` recovers €16.80 and a target close to the 63 shares held.

The next rise sells **1 share at €19.60**. Compare without a change:

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 3 1
~~~

Price and quantity are identical. The final position is `2:0:0`: the first jump remains in the original counters.

## Actually change the rules

Another scale uses the same carry-over. The past path is preserved; new rules determine the next targets and can change order prices, quantities or modes.

For type II, the last operation also affects the adjustment described in chapter 15. Rebuilding orders from the last price alone would lose some context.

`tools calc` does not take a trade's settings history or cumulative coefficients. To check a change, use `play` with the full path, or inspect the real trade's settings and orders.

## Distinguish carry-over and reinitialisation

| Action | Purpose |
|---|---|
| Ordinary change | Retain `q0`, `c0` and the step; carry jumps forward. |
| `reinit=reset,price` | New mechanical start from the holding and chosen price. |
| `reinit=merge,price` | New start incorporating the following additional operation. |
| `split=new:old` | Adapt references to a split or consolidation. |
| `sync=x:y:e` | Impose a justified position for type I. |

Reinitialisation resets the starting position and cumulative coefficients. It does not erase recorded losses or gains. `sync` retains the imposed step in the new frame; it is not a transaction.

After selling 20 at €12, resetting at €12 uses the **80 shares held**:

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 1 reinit=reset,12 -1
~~~

The next fall buys 16 at €9.60, taking the holding to 96. Without reset, the return would buy 20 at €10.

To incorporate an additional purchase of 20 at €12:

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 1 reinit=merge,12 "20@12.00" -1
~~~

References become 100 shares at €12. The next fall buys 20 at €9.60, leaving 120. The additional purchase is an operation; changing the settings alone does not perform it.

## Check the change

Keep the state before modification and inspect new proposals in a simulation. After recording, reread settings, operations and orders as in chapter 09.

A change needs an explicit reason: a studied new scale, corporate action, correction or monitoring decision. A note preserves the context. Broker orders must then be adapted to the actual executed state; continuity of calculations does not perform that adaptation.
