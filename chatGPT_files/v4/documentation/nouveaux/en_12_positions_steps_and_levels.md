# Positions, steps and levels

The holding tells us how many shares are owned. The **mechanical position** tells us where the trade stands within its scale. It is neither a quantity nor a result in euros.

## Read the three numbers

A position is written `x:y:e`:

| Number | Meaning |
|---|---|
| `x` | Number of jumps to a higher level since the active settings began. |
| `y` | Number of jumps to a lower level since those settings began. |
| `e` | Current step within the level reached. |

The counters `x` and `y` are nonnegative. Step `e` can be positive, negative or zero. `1:0:+1` means one upward jump, no downward jump and step `+1`.

A **step** is a local stage of the scale. A **level** is a reference from which another series of steps unfolds. The first purchase places the trade at `0:0:0`.

Some outputs put a number before the position: `1 0:0:+1`. That first `1` is the settings rank. The position still contains three numbers.

## Reach a boundary and change level

Chapter 11's type I scale has boundaries `emax=+2` and `emin=-2`. Its interior steps are `−1`, `0` and `+1`.

| Current position | Movement | Next position |
|---|---|---|
| `0:0:0` | Up | `0:0:+1` |
| `0:0:0` | Down | `0:0:-1` |
| `0:0:+1` | Up to the upper boundary | `1:0:0` |
| `0:0:-1` | Down to the lower boundary | `0:1:0` |

On reaching a boundary, Jedi increments the corresponding counter and resets `e` to zero. The position does not stay at `+2` or `−2`. Step zero after a jump does not automatically return to the first price or holding.

## Observe both jumps with play

At the upward jump, this teaching scale generates a sale of only one share at €14. Jedi displays a warning after the opening purchase, then reports a degraded operating mode after the first sale: the next upward order is for just one share. These messages flag a quantity too small for satisfactory operation; the simulation continues so the positions below can be observed. [Chapter 06](en_06_tools_candidate.md#understand-operability) explains the check.

Two upward steps, then two downward steps:

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 2 -2
~~~

| Moment | Position | Simulated price | Holding |
|---|---|---:|---:|
| Opening purchase | `0:0:0` | €10 | 100 |
| First rise | `0:0:+1` | €12 | 80 |
| Second rise, upward jump | `1:0:0` | €14 | 79 |
| First fall from this level | `1:0:-1` | €11.20 | 94 |
| Second fall, downward jump | `1:1:0` | €8.40 | 118 |

The final counters are `x=1` and `y=1`: they do not cancel each other. Prices and holdings come from the scale; the coordinates alone would not calculate them.

## Current and target positions

A **target position** is the position a calculated operation would reach. From `0:0:+1`, the next rise would target `1:0:0`, and the next fall `0:0:0`. These are alternative possibilities.

Placing, cancelling or letting a broker order expire does not change the recorded position. Jedi updates the path when you record the actual execution. The mechanical direction depends on operation type and mode, as chapter 17 explains.

Once the active settings have been used, orders start from their last operation. Before their first operation, orders start from the position recorded in the new settings.

## Carry the step into new settings

An ordinary settings change retains `e` and resets `x` and `y` to zero. A last operation at `1:1:-1` is thus continued by settings starting at `0:0:-1`.

Holdings, flows and historical positions are preserved. The effects of jumps carry into cumulative coefficients, discussed in chapter 16. Resetting the counters does not remove their effect on calculations.

The `reset` and `merge` reinitialisations establish a new origin `0:0:0`. Type I synchronisation resumes from a chosen position. [Chapter 09](en_09_adapting_or_ending_a_trade.md) gives the practical commands.

[Chapter 13](en_13_reading_the_structure_of_a_scale.md) presents the scale associating this position with a target price and holding.
