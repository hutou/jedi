# Check with tools calc and tools play

An isolated value helps explain a coefficient. A path shows how operations follow one another, including rounding, settings changes and protections. Jedi provides both tools: `calc` for a type I calculation, `play` for a type I or II simulation.

A simulation defined directly in the command creates no trade and records no operation in the main database. The `scale create` and `note create` commands used elsewhere in this part do write to that database: keep [chapter 02's experiment environment](en_02_installing_and_preparing_jedi.md#prepare-a-separate-experiment-environment).

## Choose the useful calculation

`tools calc` receives a type I scale, a position and a function. The position is written `x:y:e`, as in [chapter 12](en_12_positions_steps_and_levels.md).

| Function | Calculated value | Additional information |
|---|---|---|
| `kcb` | Base capital coefficient | Position |
| `kcp` | Price coefficient | Position |
| `ksp` | Holding coefficient | Position |
| `cpe` | Theoretical price | `c0` |
| `spe` | Theoretical holding | `q0` |
| `quantity` | Integer quantity to buy or sell | `q0` and current holding |
| `price` | Tick-rounded price | `c0`, `tick` and direction |

At the first upper level, our type I theoretical holding is approximately 78.571429 shares:

~~~console
jedidemo tools calc spe \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  position=1:0:0 q0=100
jedidemo tools calc quantity \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  position=1:0:0 q0=100 stock=80
~~~

Jedi rounds the target holding to 79. From 80 shares, the order quantity is therefore **−1**, a sale of one share. The decimal theoretical result is not an executable order quantity.

`calc` does not reproduce fees, protections or continuity across a settings history. It rejects type II scales, whose prices depend on previous executions. For these situations, use `play`.

## Define a path with play

The first argument describes the scale, reference holding, reference price and tick size. Following arguments describe actions:

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 1 -1
~~~

The `--` separator passes negative movements as arguments. Quotation marks keep the definition in one argument; the final `\` continues the line without adding a space before `q0`.

The opening buys 100 at €10. The rise sells 20 at €12, then the fall repurchases 20 at €10. The holding returns to 100 and net investment before fees becomes €960.

| Action | Interpretation |
|---|---|
| `1`, `-1` | One upward or downward step |
| `2`, `-2` | Two successive steps in the chosen direction |
| `"2x1,-1"` | Repeat the rise, fall pair twice |
| `8.00` | Move towards a price of €8 |
| `"20@12"` | Manual purchase of 20 at €12 |
| `"-20@12"` | Manual sale of 20 at €12 |
| `mark` | Set a mark after the previous operation |

**`8` means eight steps; `8.00` means a price.** A movement towards a price can cross several orders. A manual operation normally ends the path; the operation following `merge` reinitialisation receives special treatment, explained in [chapter 16](en_16_continuity_between_settings.md).

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" "2x1,-1"
~~~

These two round trips finish with 100 shares and €920 investment: €80 gross profit at the final €10 price.

## Choose displayed tables

| `--command` letter | Reading |
|---|---|
| `o` | Operations and holding changes |
| `c` | Settings and references |
| `r` | Orders available before operations |
| `f` | Gross financial result |

Letters can be combined, for example `--command=o0,6-14,17crf`. The selector `-c o0,6-14,17` keeps eleven operation columns: identifier, type, mode, quantity, price, position, purchases, sales, gross result, trade investment and holding. Gross result values the holding at each operation price; it includes more than realised gains.

To display fees too, add column `16`: `-c o0,6-14,16-17`. To append the financial result to the selected operations, add `f`: `-c o0,6-14,17f`. With `operation list`, enter the indices alone, without the letter `o`: `-c 0,6-14,17`.

Table `r` shows orders **before** each operation; an arrow identifies the followed order. Its last row should not be read as recalculated orders after the very last operation.

## Compare flows around a mark

A mark divides the financial reading without changing the scale or orders. Only one mark is allowed. For the financial result, place it after an operation following the opening: the base operation cannot serve as a mark.

~~~console
jedidemo tools play -c o0,6-14,17f -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 1 -1 mark -1 1
~~~

The upward round trip produces €40 gross profit. The second, downward one produces another €40. The total is €80 gross, **€6.30 fees** and **€73.70 after fees** with our 0.35% configuration and no minimum. The financial table separates periods before and after the mark; fees are read in operations when column `16` is added to the selector.

Scale changes and reinitialisations enter the path as in chapter 16. The definition can also contain `money`: then check `simulation.capital` and `loss` mode as in [chapter 18](en_18_capital_risk_and_position_sizing.md).

## Start from a recorded operation

Instead of a direct definition, `play` can receive an actual operation identifier. It reuses that context to examine a continuation without changing recorded operations:

~~~console
jedidemo tools play -c o0,6-14,17 -- 3 1 -1
~~~

Here, **3 is an example identifier**, to replace with an operation that exists in the database used. It is neither a trade name nor a quantity.

Keep commands, configuration and results when comparing settings. `play` follows movements supplied by the user; it does not measure their historical frequency. Part III will explain how `backtest` follows a quotation file and what assumptions it adds.
