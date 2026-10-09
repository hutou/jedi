# Adapting or ending a trade

## Start from a checked state

Adaptation changes rules or references used for subsequent operations. It must not replace actual past operations.

Before intervening, check stock, recent operations and active broker orders. Cancel orders made obsolete by the change and confirm cancellation. Back up the database as described in [chapter 02](en_02_installing_and_preparing_jedi.md#back-up-and-recover-data).

The examples below are **separate choices**, each starting from fictional trade EXA01 at the end of [chapter 08](en_08_monitoring_a_trade.md): 94 shares, €934 net investment, position `0:0:+1` and scale `EXA-10`. Do not execute all variants successively on that same state. To compare them, retain a backup of this state and restore it into an empty experiment database before each variant.

## Choose the required change

| Need | Command or option |
|---|---|
| Continue with another scale | `settings create` with that scale, without a special option. |
| Give retained stock a new mechanical origin | `--reinit=reset,c0`. |
| Link a new origin to an actual transaction | `--reinit=merge,c0`, then the operation. |
| Account for a split or consolidation | `--split=NEW:OLD`. |
| Exceptionally resume a type I position | `--sync=x:y:e`. |
| Change the name or capital management | `trade update`. |
| End the trade | Record the actual sale of all remaining stock. |

`--split`, `--sync` and `--reinit` are mutually exclusive. New settings must respect global chronology as explained in chapter 07.

**The trade's latest settings must have been used by an operation before creating another set.** This also applies to a simple change, split or reset. If unused settings resulted from an entry mistake, the end-of-history correction is explained below; do not invent an operation to satisfy the check.

## Change scales while preserving continuity

In this variant, record a scale with 12% movements, then create the new settings:

~~~console
jedidemo scale create --name=EXA-12 \
  --comment="Exemple avec mouvements de 12 %" \
  --builder="vr:12%,np:3,nn:3,ki:10%,kb:1,kd:0"
jedidemo settings create EXA01 --scale=EXA-12 \
  --date=2026-09-23 --time=09:00:00
jedidemo settings list EXA01
jedidemo trade status EXA01
jedidemo trade orders EXA01
~~~

Stock remains 94. Here the new settings retain `q0=100` and `c0=10`; those references are not current stock and price. They resume step `+1` with position `0:0:+1`.

During a simple change, Jedi resets jump counters `x` and `y` to zero and incorporates their effects into cumulative coefficients. Calculations therefore remain continuous without copying all counters. Chapters 12 and 16 explain the mechanics.

The new scale must accommodate the retained step; otherwise Jedi refuses the change. Read new orders before placing them.

## Restart from current stock with reset

This variant retains 94 shares and chooses a fictional €11 reference price:

~~~console
jedidemo settings create EXA01 --scale=EXA-10 \
  --date=2026-09-23 --time=09:00:00 --reinit=reset,11
jedidemo settings list EXA01
jedidemo trade orders EXA01
~~~

The new settings have `q0=94`, `c0=11` and position `0:0:0`. No purchase or sale is created. Earlier operations and existing investment remain in the history.

Choose the new price under an explicit rule, such as the observed price at intervention. A reset can change subsequent orders; it neither corrects an erroneous stock count nor erases previous losses. Retain the reason, selected price and cancelled orders in a note.

## Link reinitialisation to an operation with merge

This other variant assumes an **actual** manual purchase of 6 shares at €11. Create settings, then record execution:

~~~console
jedidemo settings create EXA01 --scale=EXA-10 \
  --date=2026-09-23 --time=09:00:00 --reinit=merge,11
jedidemo operation create EXA01 \
  --date=2026-09-23 --time=09:01:00 \
  --type=Buy --mode=Market --quantity=6 --price=11 --fees=0.23
jedidemo settings list EXA01
jedidemo trade status EXA01
~~~

After settings creation, new references remain pending. The next operation establishes them from retained stock, the supplied price and the transaction. In this example, stock and `q0` become 100, `c0` is €11 and position is `0:0:0`.

Use `merge` when the transaction is part of the reinitialisation decision. Until that operation is recorded, the new settings are not ready for regular monitoring. The note should describe the reason and expected transaction.

## Account for a split or consolidation

A split changes share count and price units without a purchase or sale. For two new shares per old share:

~~~console
jedidemo settings create EXA01 --scale=EXA-10 \
  --date=2026-09-23 --time=09:00:00 --split=2:1
jedidemo quote set FR4487601001 --price=5.50
jedidemo trade status EXA01
jedidemo trade orders EXA01
~~~

Monitoring stock changes from 94 to **188 shares**. `q0` changes from 100 to 200 and `c0` from €10 to €5. Position retains step `+1`; net investment remains €934. The fictional €5.50 price is entered in the new price unit.

The Jedi ratio is always **new : old**:

| Event | Jedi option |
|---|---|
| 10 new shares per old share | `--split=10:1` |
| 1 new share per 10 old shares | `--split=1:10` |

Consolidating 101 old shares at ten for one leaves 10 whole new shares and a fractional entitlement of 0.1 share. Consult the event's terms for its treatment. Jedi handles neither this fraction nor any cash settlement. Compare whole stock with the broker's statement and note any amount received; this payment remains outside the trade results calculated by Jedi. Do not turn it into a fictional purchase or sale.

After the event, also check quotation ticks and every order. The ratio and effective date must match the actual event.

## Exceptionally resynchronise a position

Interrupted monitoring or a large gap can lead to resuming management at another theoretical position. Operations that did not occur must not be recorded.

`--sync` is restricted to **type I scales**. This fictional variant explicitly uses such a scale:

~~~console
jedidemo scale create --name=EXA-I \
  --comment="Exemple de type I pour sync" \
  --builder="kc:1.4,1.2,0.8,0.6,ki:10%,kb:1,kd:0"
jedidemo settings create EXA01 --scale=EXA-I \
  --date=2026-09-23 --time=09:00:00 --sync=1:0:+1
jedidemo settings list EXA01
jedidemo trade orders EXA01
~~~

Supplied position `1:0:+1` describes the requested connection. Jedi incorporates its effects and opens the active settings at `0:0:+1`. It does not correct stock or add missed operations.

Choosing a position requires understanding the scale and resumption price; part II covers this further. Before intervention, resolve stock discrepancies from actual executions. Note the interruption period or gap, previous position, price and selected position.

## Change the name or capital management

To change the trade name:

~~~console
jedidemo trade update EXA01 --name=EXA_LONG
~~~

To enable or change `money`:

~~~console
jedidemo trade update EXA_LONG --money="r:1%,o:1,n:2"
jedidemo trade orders EXA_LONG
~~~

These values use configured capital, here €5,000. They are illustrative choices; they change protective rules without altering past operations.

If a stored stop exists and `money` changes, Jedi requires explicit resetting:

~~~console
jedidemo trade update EXA_LONG --money="r:1.5%,o:1,n:2" --reset-stop
jedidemo trade orders EXA_LONG
~~~

Read the confirmation prompt. This option clears the stop stored in Jedi; it cancels no broker order. Check protective orders before and after the change. Increasing risk to make a loss acceptable on screen does not repair the trade.

## Correct the end of the history

There is no arbitrary editing of an earlier operation. Correction steps backwards from the end of global history, then recreates correct records.

~~~console
jedidemo operation delete
~~~

This command proposes deleting **the latest operation in the whole database**, rather than an operation chosen within EXA01. Read its confirmation. If more recent settings exist, the operation cannot be deleted first.

If those latest settings have not been used by any operation, the sequence is:

~~~console
jedidemo settings delete
jedidemo operation delete
~~~

After checking confirmations, recreate corrected records in their actual chronology and check orders. Deleting an operation can undo closure; use it to correct an entry rather than rewrite execution. Record the reason and corrected values in a note.

## End the trade through its actual sale

This final variant starts from the 94 shares at the end of chapter 08, without the previous adaptations. Cancel orders incompatible with the exit, sell the stock through the broker and record confirmed execution:

~~~console
jedidemo operation create EXA01 \
  --date=2026-09-23 --time=15:00:00 \
  --type=Sell --mode=Market --quantity=94 --price=11.20 --fees=3.68
jedidemo operation list EXA01 -c 0,6-14,17
jedidemo trade list
jedidemo trade results EXA01
~~~

Stock becomes **zero**: the trade is closed. There is no administrative `trade close` command. Record the appropriate `Market`, `Limit`, `Stop` or `StopLoss` mode according to the order actually executed.

Useful values for our example are:

| Information | Value |
|---|---:|
| Recorded purchases excluding fees | €1,000.00 |
| Recorded sales excluding fees | €1,118.80 |
| Gains excluding fees | €118.80 |
| Total fees | €7.41 |
| Final stock | 0 |

After fees, this example's gain is €111.39. The annualised rate displayed for such a short path is an extrapolation; it does not replace this monetary balance.

If the final sale remains partial, apply consolidation and remainder cancellation as explained in chapter 08. The trade remains open while holding shares.

Once stock is zero, Jedi refuses another operation on this trade. Create another trade for new management of the same security. Retain the completed trade: operations, settings, contextual notes and results support later checks. `trade delete` refuses to delete a trade with a history.
