# Understand a type I scale

Type I associates each step with a price coefficient `kc` and a holding coefficient `ks`. Within one level, these coefficients give known targets. A jump changes the references to which they apply.

We use 100 shares at €10, a €0.01 tick and this scale:

~~~text
kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1
~~~

## Calculate the first targets

In the first level, multiply references by coefficients:

| Position | Theoretical price | Theoretical holding |
|---|---:|---:|
| `0:0:0` | €10 × 1 = €10 | 100 × 1 = 100 |
| `0:0:+1` | €10 × 1.20 = €12 | 100 × 0.80 = 80 |
| `0:0:-1` | €10 × 0.80 = €8 | 100 × 1.20 = 120 |

From 100 shares, the rise proposes selling 20 and the fall buying 20. Returning to zero before any jump restores the €10 price and theoretical holding of 100.

## Move to the next level

At boundary `+2`, the new price reference is €10 × 1.40 = €14. The theoretical capital reference is multiplied by `1+ki`, or 1.10. It rises from €1,000 to €1,100.

The theoretical holding at the new level's origin is €1,100 ÷ €14, approximately **78.571429 shares**. This is a calculation target, not a fractional holding actually owned.

At boundary `−2`, reached directly from the first level, the price reference is €6 and the capital reference €900 with `kb:1`. The theoretical holding becomes €900 ÷ €6 = **150 shares**.

These values are neither current investment, account balance nor trade profit.

## Check the multipliers with calc

Jedi calls the level's price multiplier `kcp`, its capital reference multiplier `kcb`, and its holding multiplier `ksp`. Their relationship is `ksp = kcb / kcp`.

For the first upward jump:

~~~console
jedidemo tools calc cpe \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  position=1:0:0 c0=10
jedidemo tools calc spe \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  position=1:0:0 q0=100
~~~

We obtain `cpe=14` and `spe≈78.571429`, the theoretical price and holding respectively.

After one jump in each direction, the price reference is multiplied by 1.40 × 0.60 = 0.84. The capital reference is multiplied by 1.10 × 0.90 = 0.99:

~~~console
jedidemo tools calc kcb \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  position=1:1:0
~~~

The result is 0.99. These two jumps do not restore the first level's references.

## Follow integer transactions with play

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 2 -2
~~~

| Operation | Position | Quantity | Price | Holding afterwards |
|---|---|---:|---:|---:|
| Buy Market | `0:0:0` | 100 | €10 | 100 |
| Sell Limit | `0:0:+1` | 20 | €12 | 80 |
| Sell Limit | `1:0:0` | 1 | €14 | 79 |
| Buy Limit | `1:0:-1` | 15 | €11.20 | 94 |
| Buy Limit | `1:1:0` | 24 | €8.40 | 118 |

The target of 78.571429 rounds to 79, then is compared with the 80 shares held: one share is sold. The last fall starts from the upper level, rather than directly from the opening.

The optimised structural check therefore does not ensure sufficiently large orders after rounding. Operability and fees still need examination.

## Let Jedi distribute holding changes

The compact builder replaces the `ks` list with `kd`:

~~~console
jedidemo scale create --name=PEDA-I-AUTO \
  --comment="Teaching builder" \
  --builder="kc:1.4,1.2,0.8,0.6,ki:10%,kb:1,kd:0"
jedidemo scale show PEDA-I-AUTO
~~~

Create this name once in the experiment database. With `kd:0`, changes are distributed evenly between intervals. Jedi produces **`ks:0.89,1.25`**: interior targets of 89 and 125 for `q0=100`.

This differs from `ks:0.8,1.2`. Positive `kd` weights later intervals more; negative `kd` weights earlier ones more. Inspect the expanded scale to examine quantities.

## Place the historical Qdt scale in context

`Qdt` remains for compatibility. Its canonical definition is:

~~~text
kc:1.61,1.38,1.23,1.14,0.88,0.76,0.64,0.52,0.4,
ks:0.4,0.68,0.87,1.9,2.9,4.1,5.5,ki:14%,kb:0
~~~

It uses `kb:0`: a downward jump uses the inverse of `1+ki`. Its boundaries are `+4` and `−5`. It fails the optimised check and can request a purchase on a rise or a sale on a fall.

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.61,1.38,1.23,1.14,0.88,0.76,0.64,0.52,0.4,\
ks:0.4,0.68,0.87,1.9,2.9,4.1,5.5,ki:14%,kb:0,\
q0=100,c0=10,tick=0.01" 4
~~~

Immediately before the upward jump, 40 shares remain. The jump targets 71 at €16.10: **a Stop purchase of 31 shares**. On a separate five-step downward path, the holding falls from 550 to 219 at the boundary: a Stop sale of 331 at €4.

Qdt illustrates why the mode and holding change matter, not just the direction of price. It is not the reference scale for the remaining examples. [Chapter 15](en_15_understanding_a_type_ii_scale.md) examines the other price calculation method.
