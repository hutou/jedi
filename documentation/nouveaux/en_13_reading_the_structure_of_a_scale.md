# Read the structure of a scale

A scale associates price movements with changes in the target holding. It does not describe transactions already performed. Jedi calculates a target, then compares it with the actual holding to determine the next order.

## Two references: c0 and q0

At the first purchase, `c0` is the unit price and `q0` the quantity. For 100 shares bought at €10, the references are `c0=10` and `q0=100`.

Later settings may retain them, adjust them for a split or replace them during reinitialisation. **`c0` is therefore not always the first operation's price, and `q0` is not always the initial holding.** Nor are they automatically the latest price and current holding.

The **theoretical price** is the price associated with a mechanical target. The **theoretical holding** is the number of shares the scale would like to hold at that target. The order then uses a tick-compliant price and an integer quantity. Actual executions can differ.

## Read the scale elements

A coefficient is a multiplier: a €10 reference with a price coefficient of 1.20 gives €12. A 100-share reference with a holding coefficient of 0.80 gives 80 shares, before level effects.

| Element | What it controls |
|---|---|
| `kc` | List of price coefficients for type I. |
| `vr` | Variation rate for the next price in type II. |
| `ks` | List of holding coefficients for either type. |
| `ki` | Adjustment to the theoretical capital reference on a jump. |
| `kb` | Convention for that adjustment; our usual examples use `kb:1`. |
| `kd` | Distribution of holding changes when Jedi builds the `ks` list. |
| `np`, `nn` | Upper and lower boundaries of a compact type II builder. |

`ki` differs from capital management risk `r`. A 10% level adjustment is neither 10% portfolio risk nor a promised gain.

## Expand a simple type I scale

Save this teaching scale in an experiment database:

~~~console
jedidemo scale create --name=PEDA-I \
  --comment="Teaching scale of type I" \
  --builder="kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1"
jedidemo scale show PEDA-I
~~~

Create this name once only. If it exists, inspect the scale before reusing it. Other examples often pass the definition directly to a tool without creating a permanent name.

Jedi adds coefficient `1` at step zero:

| Step | Price coefficient kc | Holding coefficient ks |
|---|---:|---:|
| `+2`, upper boundary | 1.40 | Jump to the next level |
| `+1` | 1.20 | 0.80 |
| `0` | 1.00 | 1.00 |
| `−1` | 0.80 | 1.20 |
| `−2`, lower boundary | 0.60 | Jump to the next level |

In the first level, `+1` targets 80 shares at €12 and `−1` targets 120 at €8. At the boundaries, Jedi changes level and calculates new references.

Jedi accepts boundaries from two to six movements in each direction, with one to five interior steps per side. In compact type II, `np:3,nn:3` means three movements to each boundary, with two interior steps per side.

## Distinguish the two types

| Question | Type I | Type II |
|---|---|---|
| Next price | From `kc` and the level references. | Applying `vr` to the relevant last execution price. |
| Target holding | From `ks` and holding references. | From `ks` and holding references. |
| Rise then fall | Within one level, coefficients identify the same prices. | Percentages restart from the last price; the return can target another price. |

[Chapters 14](en_14_understanding_a_type_i_scale.md) and [15](en_15_understanding_a_type_ii_scale.md) calculate these differences. The type does not predict a financial result.

## Builder and expanded definition

The **builder** is the text supplied to Jedi. The **canonical definition** is the expanded, normalised rule it produces.

| Form | Main fields |
|---|---|
| Type I, holding supplied directly | `kc`, `ks`, `ki`, `kb` |
| Type I, holding built by Jedi | `kc`, `ki`, `kb`, `kd` |
| Type II, holding supplied directly | `vr`, `ks`, `ki`, `kb` |
| Type II, holding built by Jedi | `vr`, `np`, `nn`, `ki`, `kb`, `kd` |

The expanded definition always exposes `ks`, even when the builder uses `kd`. Type I exposes `kc`, type II `vr`. `scale show` lets you read the result before using it.

## Understand optimised

Jedi checks whether the structure reduces the holding at the upper boundary and increases it at the lower boundary. It calls this structural check **optimised**.

The label measures neither profitability, fees nor portfolio requirements. Rounding and some type II paths still require inspection of the actual calculated orders. Chapter 17 will show a functioning Stop order.

An optimised builder is a method of constructing `ks`. A directly supplied list can also pass the check, as `PEDA-I` does.

To change a rule already used, creating a new scale preserves the interpretation of past operations. [Chapter 16](en_16_continuity_between_settings.md) explains how to associate it with new dated settings.
