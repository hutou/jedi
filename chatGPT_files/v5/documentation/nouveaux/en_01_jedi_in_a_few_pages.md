# Jedi in a few pages

The examples below use the `jedidemo` launcher, installed in [chapter 02](en_02_installing_and_preparing_jedi.md). It keeps their data in a demonstration environment separate from your real portfolio.

## Rules for managing a trade

Jedi is a command-line application for managing trades according to rules defined in advance. A **trade** brings together purchases and sales of one security, its scale, its settings and its history.

The **scale** connects price movements to quantities to buy or sell. From the current trade state, Jedi calculates the orders to consider. The user places them with their broker, checks their execution and records the operations actually completed.

This separation makes the process understandable: choose the rules, observe the levels reached, execute and record. A prolonged rise or fall, high fees or insufficient funds can nevertheless produce an unfavourable outcome.

## Working with fluctuations

A round trip can involve selling some shares after a rise, then buying them back during a fall. Here is a **fictional** example calculated with Jedi:

~~~console
jedidemo --border=markdown tools play -c o0,6-14,17 -- \
  scale=vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0,q0=100,c0=10,tick=0.01 1 -1
~~~

The created environment specifies a scale, 100 shares purchased at €10 and a tick size of €0.01. The arguments `1 -1` request one step upwards, then one step downwards. The double hyphen separates options from scenario arguments.

In the resulting output, the initial purchase is followed by:

| Operation | Quantity | Price | Amount | Holdings afterwards |
|---|---:|---:|---:|---:|
| Sale | 6 | €11.00 | €66.00 | 94 |
| Purchase | 6 | €9.90 | €59.40 | 100 |

Holdings return to 100 shares and the round trip adds €6.60 before fees. However, the final price is €9.90: the remaining shares must also be valued to determine the overall result. A profitable round trip and a profitable trade overall are separate findings.

`tools play` explains the mechanics here. It reads no historical prices and sends no orders to the broker. Type I and type II scales are developed in Part II.

## Three decisions before opening

| Stage | Question | Possible method |
|---|---|---|
| Choose a security | Which security should be examined? | Personal selection, external screener or `tools profile` |
| Choose a scale | Which rules should be examined? | An already chosen scale or a search with `tools score` |
| Evaluate the proposal | Can it be opened and continued with these quantities and funds? | `tools candidate` |

The user chooses the security. `profile` helps establish a list based on trend, liquidity, volatility, oscillation and three additional criteria. Its statuses are **retained**, **caution** and **rejected**.

`score` simulates different scales on the selected security's history. Its standard ranking shows raw results, activity and maximum investment. The reader can understand the sorting criteria and choose a scale definition.

`candidate` examines that definition at the supplied price or the price recorded in Jedi. It checks useful quantities and funding, considering existing trades. An operable proposal can require too much capital; a proposal with available funds can produce orders that are too small.

A further backtest can examine a fixed scale over a historical period. None of these calculations turns a selection into an automatic purchase order.

## The monitoring cycle

Once the trade is open, routine work consists of updating the price, consulting orders, monitoring their execution with the broker, recording operations and recalculating orders.

An **order** is a proposed or placed instruction; an **operation** is an executed purchase or sale. Recording an operation means describing what actually happened, including its quantity and price.

Exceptional events deserve a record: partial execution, cancellation of an order remainder, suspension, a quotation incident or a settings change. The `note` journal stores the date, security or trade name, facts and decision. Chapters 08 and 09 explain its use.

## The data required

The main database stores securities in use, trades, settings, operations, notes and recorded prices. A separate market database stores historical quotations.

This second database is optional. `score` and `backtest` can read a prepared individual file; `profile` can also examine that file. A market database is used to compare a population of securities and manage its freshness.

An **OHLCV** history contains the open, high, low, close and volume for each session. A current price is a point-in-time value. Importing a history with `market` does not update the price in the main database.

`quote get` queries price providers; it updates no database. Recording and monitoring commands are explained in the practical chapters.

## Where to continue

Chapter 03 helps choose a security. Chapters 04, 05 and 06 explain `profile`, `score` and `candidate`. Chapters 07 to 09 follow a real trade; chapter 10 explains files and market databases.

Part II develops the mechanics with `play` and `calc`. Part III explains backtests, period comparisons and result monitoring. The appendices provide references for commands, providers, the external screener and terminology.
