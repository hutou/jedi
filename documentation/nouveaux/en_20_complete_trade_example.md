# Follow a complete trade example

Bring the calculations together in one path: size an opening, observe flows, change settings, compare two continuations and close the holding. This fictional security is separate from EXA01 in part I. All paths below run in memory with `tools play`; they create no trade.

The example uses type I, an initial €10 price, a €0.01 tick and 0.35% fees with no minimum. Reproduce `candidate` commands in an experiment database with no open trades.

## Size the project

By default, `candidate` checks three upward steps for operability. Help displays the configured value, which is `3` with the original configuration:

~~~console
jedidemo tools candidate --help
~~~

The `--operability-steps=COUNT` line says “default: 3”. If the configuration of this demonstration space changes, the displayed value follows that setting.

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --money=r:2.5%,o:1,n:2 --capital=20000
~~~

With €20,000 capital and 2.5% risk, `R` is €500. Two downward steps lead to €6, 40% below entry. The retained quantity is **125**, for an opening of **€1,250**.

The projected maximum requirement before fees is **€1,855.60**, including a €605.60 future reserve. This covers three steps according to the horizon reported by `candidate`. [Chapter 18](en_18_capital_risk_and_position_sizing.md) explains why that horizon differs from `n`.

The following paths **do not activate `money`**: they isolate the scale mechanics. A protected trade can follow other orders. These paths therefore do not imply that a protected trade would execute the same purchases and sales.

## Follow operations

~~~console
jedidemo tools play -c o0,6-14,17f -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=125,c0=10,tick=0.01" -1 1 mark 1 1
~~~

| Operation | Price | Holding afterwards | Net investment before fees |
|---|---:|---:|---:|
| Opening purchase of 125 | €10.00 | 125 | €1,250.00 |
| Purchase of 25 | €8.00 | 150 | €1,450.00 |
| Sale of 25 | €10.00 | 125 | €1,200.00 |
| Sale of 25 | €12.00 | 100 | €900.00 |
| Sale of 2 | €14.00 | 98 | €872.00 |

The mark follows the return to €10. This first round trip produced €50 gross. At the final €14 price, the 98 shares are worth €1,372: overall gross profit is **€500**. It includes the remaining holding's value; not all this profit has been received in cash.

Maximum investment actually encountered is €1,450. The `candidate` reserve examined another, downward path; it does not predict the purchases on every path.

## Reapply the same scale in new settings

Reapply the scale after the sale at €14, then advance one step:

~~~console
jedidemo tools play -c o0,6-14,17cf -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=125,c0=10,tick=0.01" -1 1 mark 1 1 \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 1
~~~

New settings retain `q0=125` and `c0=10`, reset local counters to zero and carry cumulative coefficients forward: `kcpc=1.4` and `kspc≈0.785714`. Changing settings triggers no transaction.

The next rise sells **19 shares at €16.80**. The holding becomes 79, net investment €552.80 and holding value €1,327.20. Gross profit is **€774.40**. New coordinates belong to the new settings; past operations retain theirs.

## Record an exceptional decision

For a trade actually monitored in the database, a note can explain a decision or check that cannot be read from operations. Here, the following optional write must stay in the experiment database:

~~~console
$ jedidemo note create 2026-10-05 "PEDA20 - settings" "State checked:
> 98 shares held after selling 2 shares at EUR 14.
> Same scale reapplied to check continuity.
> Broker orders to check before continuing."
~~~

`$` and `>` represent shell prompts and are not typed. The content contains real line breaks. The note belongs to the general journal; `PEDA20` in its summary is a reference, not a trade created by `play`.

~~~console
jedidemo note list PEDA20
~~~

If this note receives identifier 1 in an empty database:

~~~console
jedidemo note show 1
jedidemo note update 1 --edit
~~~

Otherwise, use the identifier displayed by `note list`. The editor can later add broker confirmation, including cancellation of old orders. Its setup is described in [chapter 08](en_08_monitoring_a_trade.md#write-with-an-editor).

## Compare a fall instead of the rise

Restart from the same state after the sale at €14 and settings change. Replace only the last movement with a fall:

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=125,c0=10,tick=0.01" -1 1 mark 1 1 \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 -1
~~~

This fall buys **20 shares at €11.20**. The holding becomes 118 and net investment €1,096.

| Continuation after the change | Holding | Final price | Gross profit |
|---|---:|---:|---:|
| One rise | 79 | €16.80 | €774.40 |
| One fall | 118 | €11.20 | €225.60 |

These branches show possible consequences of the same settings. They give no probability for either.

## Close the holding and reconcile the result

In the upward branch, manually sell the remaining 79 shares at €16.80:

~~~console
jedidemo tools play -c o0,6-14,17f -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=125,c0=10,tick=0.01" -1 1 mark 1 1 \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  1 "-79@16.80"
~~~

This sale deliberately closes the holding; it is not the target quantity of the next ordinary order.

| Closed branch result | Amount |
|---|---:|
| Total purchases | €1,450.00 |
| Total sales | €2,224.40 |
| Final holding | 0 shares |
| Gross profit | €774.40 |
| Total fees | €12.88 |
| Profit after fees | €761.52 |

The financial result splits gross profit into €50 before the mark and €724.40 afterwards. In a real trade, record the broker execution as in [chapter 09](en_09_adapting_or_ending_a_trade.md), with its actual charged fees.

At each stage, reconcile the holding, monetary flows, active settings and next orders. Notes explain exceptional events; they do not replace recording executions. Part III will confront these mechanics with historical quotations and the limits specific to simulation.
