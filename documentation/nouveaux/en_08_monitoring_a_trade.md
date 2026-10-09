# Monitoring a trade daily

## A monitoring loop

Monitoring means obtaining a relevant price, reading status and orders, maintaining orders through the broker, then recording only actual executions. Recalculate orders after an operation.

Three kinds of information remain distinct:

| Information | What it describes |
|---|---|
| Recorded price | A price observation used for monitoring. |
| Calculated orders | The next operations proposed from the trade's state. |
| Recorded operations | Purchases and sales actually executed. |

A price change does not alter stock. Placing or cancelling a broker order does not change the Jedi database. A broker execution appears there only after you record it.

This chapter continues **fictional trade EXA01 opened in [chapter 07](en_07_opening_a_trade.md)**: 100 shares bought at €10, scale `EXA-10`. Recording commands are experiments for the separate database prepared in [chapter 02](en_02_installing_and_preparing_jedi.md#prepare-a-separate-experiment-environment).

## Obtain a relevant price

For fictional experiments, enter the desired price:

~~~console
jedidemo quote set FR4487601001 --price=11
~~~

`quote set` stores the price with the entry time, source `manual` and no retained variation. It cannot know when your observation was made: check that the price corresponds to the intended session and time.

With configured providers, usual commands are:

~~~console
jedidemo quote update FR4487601001
jedidemo quote refresh
jedidemo quote refresh --mode=eod
~~~

`update` refreshes a registered security. By default, `refresh` updates securities linked to open trades. To collect data for an actual security, replace the fictional ISIN with your registered security's ISIN: EXA has no market-provider price.

`--mode=eod` requests end-of-day mode; `--mode=live` requests current-price mode. Content, delays and availability depend on the provider. A mode option can also be supplied to `quote update`.

For consultation without writing the result to the main database:

~~~console
jedidemo quote get FR4487601001
~~~

Detailed provider configuration appears in [appendix 02](en_annex02_data_providers.md). Manual entry allows monitoring when collection is unavailable. Chapter 10's `market update` commands maintain histories; they do not replace these monitoring prices.

Monitoring commands can attempt to refresh a price whose configured retention time has expired. If collection fails, an old price can be reused with a warning. Read the warning and check the price's relevance before using orders.

## Read status and orders

~~~console
jedidemo trade status EXA01
jedidemo trade orders EXA01
~~~

Compare displayed stock with broker stock. Read each order's `Buy` or `Sell` type, mode, quantity, price and amount. At €11 and without another operation, EXA01 still holds 100 shares and proposes the previous chapter's orders.

| Mode | Practical meaning |
|---|---|
| Limit | Limit order. |
| Stop | Operating order triggered when a threshold is crossed. |
| StopLoss | Protective order resulting from `money` capital management. |

An operating Stop and a StopLoss have different purposes. Even with a scale described as optimised, read the mode actually proposed; some paths can produce an operating Stop.

The **READY** mark means the known price has crossed the order price in the direction corresponding to execution. **WATCH** means proximity under the configured threshold. An exactly equal price can still be marked “watch”. Neither mark proves broker execution.

If Jedi reports insufficient quantities, an old price or inapplicable capital management, examine the reason before continuing. [Chapter 06](en_06_tools_candidate.md#when-existing-trades-have-exceeded-r) describes losses exceeding R.

## Maintain orders through the broker

After calculation, compare Jedi's rows with actual active orders. Cancel outdated orders, then modify or replace those that need it. Check the broker's final summary: direction, mode, quantity, price and validity period.

A sale can reduce stock available for another sale order. The broker and Jedi do not automatically coordinate orders. After execution, check remaining orders before keeping them.

When a StopLoss and Limit sale must coexist, `trade orders --net-stop` can display a StopLoss quantity reduced by the upward sale's quantity. This option creates no cancellation link between broker orders; you remain responsible for coordinating them.

## Record an actual sale

Our example assumes a confirmed sale of 6 shares at €11 with €0.23 fees. Record it:

~~~console
jedidemo operation create EXA01 \
  --date=2026-09-22 --time=10:15:00 \
  --type=Sell --mode=Limit --quantity=6 --price=11 --fees=0.23
jedidemo operation list EXA01 -c 0,6-14,17
jedidemo trade status EXA01
jedidemo trade orders EXA01
~~~

Stock becomes **94 shares**. Net investment excluding fees decreases from €1,000 to **€934**, since the sale received €66. Position becomes `0:0:+1`.

These are recalculated orders, including rounding to the example's quotation tick:

| Type | Mode | Quantity | Price | Amount excluding fees |
|---|---|---:|---:|---:|
| Buy | Limit | 6 | €9.90 | €59.40 |
| Sell | Limit | 6 | €12.11 | €72.66 |

Use these new values with the broker. An order that has only expired, been cancelled or remained unexecuted creates no Jedi operation.

## Handle partial execution

Several fragments of one order must be grouped into **one consolidated operation**. Each operation record can advance the mechanical position; treating fragments as successive steps would distort that order's path.

For our example sale, the broker might have executed:

| Fragment | Quantity | Price | Time | Fees |
|---|---:|---:|---|---:|
| First | 2 | €11.00 | 10:14:00 | €0.10 |
| Second | 4 | €11.00 | 10:15:00 | €0.13 |
| To record | 6 | €11.00 | 10:15:00 | €0.23 |

The sale command above records this consolidation. If prices differ, use the quantity-weighted average price, total fees and time of the last fragment.

While the remainder can still execute, wait for the situation to stabilise before recording. During that wait, Jedi's state is temporarily behind: do not use it to launch another set of orders.

If you decide to retain and record only the executed part, **immediately cancel the remainder through the broker and confirm cancellation before replacing recalculated orders**. Record only the quantity actually executed. The trade continues with its actual stock.

The average price of several executions may not match the quotation tick. Jedi normally checks that tick. To record a broker-confirmed average without artificial rounding, prefixing the price with `+` disables this check for that entry: for example, `--price=+11.013333`. It does not increase the price. Use this form to report actual execution, rather than bypassing order-price checks.

## Retain context with note

Operations record stock and cash movements. `note` retains the context of exceptional events: partial execution, cancellation, interrupted monitoring, an incident or a particular decision.

To write several lines, open the content's quotation marks and close them only after the last line:

~~~console
$ jedidemo note create 2026-09-22 "EXA01 - partial sale" "Sale of 6 shares:
> 2 then 4 shares at EUR 11. Execution completed at 10:15.
> Total fees: EUR 0.23. One consolidated operation recorded."
~~~

`$` and `>` represent terminal prompts: do not type them. While quotation marks remain open, the terminal continues the same command; line breaks are preserved in the note. This syntax also suits long text that would be cut off in print on a single line.

~~~console
jedidemo note list EXA01
~~~

In a database without previous notes, this note has ID 1. Use the ID actually shown to read or complete it:

~~~console
jedidemo note show 1
jedidemo note update 1 --edit
~~~

`--contents` remains available and replaces the whole content, which can also span several lines. Retain existing text when adding information.

### Write with an editor

Option **`--edit`** makes note creation and modification easier. Jedi uses the program in `VISUAL`, or `EDITOR` if `VISUAL` is absent. These variables must contain the executable's name or path, for example `nano`.

In the Ubuntu or Linux terminal, if chapter 02's configuration has not yet been made:

~~~bash
export EDITOR=nano
export VISUAL=nano
~~~

Then create a note:

~~~console
jedidemo note create --edit
~~~

The editor opens a template with three markers, to keep in this order. Here is a completed example; marker names remain in English in every language:

~~~text
# Date
2026-09-22

# Summary
EXA01 - partial sale

# Contents
Sale of 6 shares: 2 then 4 shares at EUR 11.
Execution completed at 10:15; total fees EUR 0.23.
One consolidated operation recorded.
~~~

In nano, save with **Ctrl+O**, confirm the filename with **Enter**, then exit with **Ctrl+X**. Leaving the template unchanged cancels creation. To resume an existing note, `jedidemo note update 1 --edit` opens its current content: replace 1 with its identifier. Do not combine `--edit` with field options `--date`, `--summary` or `--contents`.

Notes form a general journal; including the trade name in the summary or text makes them searchable. There is no automatic trade link. A note replaces neither execution nor its operation record.

After this monitoring example, EXA01 holds 94 shares. [Chapter 09](en_09_adapting_or_ending_a_trade.md) starts from this state to present possible adaptations and closure.
