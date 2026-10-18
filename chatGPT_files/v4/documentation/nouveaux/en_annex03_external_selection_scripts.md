# External selection script: JEDI ProScreener

## Purpose of the screener

JEDI ProScreener provides a list of securities to examine in ProRealTime. Its criteria are consistent with `profile`'s four main questions: trend, liquidity, volatility and oscillation.

Trend, liquidity and volatility provide the entry filters. Oscillation supplies selection information; it is not a rejection filter in this script. The user then chooses the security, scale and proposal to evaluate.

## Prepare execution

In ProRealTime, open ProScreener, create a programmed screener and paste the listing below. Explicitly choose the market or list and work with **daily bars**. The program specifies `TIMEFRAME(Daily)`.

Read results after the selected session has ended. A developing bar can still change its close, volume and range. For comparison with Jedi, check the dataset's latest quotation date with `market info` and `market list --last-quote`.

The [official ProScreener manual](https://www.prorealtime.com/en/pdf/proscreener.pdf), version 6.1.0 dated 1 December 2025, consulted on 3 October 2026, states that calculations use 256 candlesticks, or 1,024 on Premium platforms. The script's 252-session window fits this scope. The manual also specifies three or six output criteria depending on licence.

The listing has three active columns. A four-column alternative is kept in a comment: use it only when the platform supports it, replacing the final active instruction. Keep only one active `SCREENER` instruction.

## What the script measures

| Measure | Calculation and purpose |
|---|---|
| Trend | Slope over 252 sessions, annualised; filter strictly above −12%. |
| Liquidity | Median close × volume over 252 sessions; filter at or above 100,000. |
| ATR20 | Simple average of 20 true ranges divided by the close; filter at or above 1.5%. |
| Oscillation | Movements and reversals of at least 5% over 252 sessions, annualised; displayed information. |

With euro prices and share volumes, liquidity is expressed in euros per session. The threshold does not convert currencies. ATR is calculated directly with a simple average; retain this calculation for consistency with Jedi.

Active columns are `Trend %/y`, `ATR20 %` and `Sw5/y`. Liquidity is filtered even when not displayed. The program accepts at least 252 historical bars; it does not reproduce `profile`'s minimum three-year depth check.

## Complete listing

~~~text
// JEDI - ProScreener journalier
// Cible : ProRealTime / ProScreener
// Fenêtre principale : 252 séances ; ATR : 20 séances
//
// Filtres équivalents aux principaux critères éliminatoires de Jedi profile :
//   - tendance annualisée > -12 %
//   - montant quotidien médian >= 100 000
//   - ATR(20) simple >= 1,5 %
//
// L'oscillation à 5 % est calculée et affichée mais n'est pas éliminatoire.

TIMEFRAME(Daily)

// ------------------------------------------------------------------
// 1. Historique minimal disponible dans ProScreener
// ------------------------------------------------------------------
validHistory = BarIndex >= 251

// ------------------------------------------------------------------
// 2. Tendance sur 252 séances
// Approximation de JEDI : régression de LOG(Close) par numéro de barre,
// annualisée sur 252 séances.
// ------------------------------------------------------------------
trendSlope = LinearRegressionSlope[252](LOG(Close))
trendPct = (EXP(trendSlope * 252) - 1) * 100
trendOK = trendPct > -12

// ------------------------------------------------------------------
// 3. Liquidité : médiane de Close * Volume sur 252 séances
// ------------------------------------------------------------------
FOR i = 0 TO 251 DO
  $tradedValue[i] = Close[i] * Volume[i]
NEXT

ArraySort($tradedValue, ASCEND)
medianTradedValue = ($tradedValue[125] + $tradedValue[126]) / 2
liquidityOK = medianTradedValue >= 100000

// ------------------------------------------------------------------
// 4. Volatilité : ATR(20) SIMPLE, comme Jedi
// Ne pas utiliser AverageTrueRange[20], qui applique le lissage de Wilder.
// ------------------------------------------------------------------
atrSum = 0
FOR i = 0 TO 19 DO
  tr1 = High[i] - Low[i]
  tr2 = ABS(High[i] - Close[i + 1])
  tr3 = ABS(Low[i] - Close[i + 1])
  trueRange = MAX(tr1, MAX(tr2, tr3))
  atrSum = atrSum + trueRange
NEXT

atr20 = atrSum / 20
atrPct = 0
IF Close > 0 THEN
  atrPct = atr20 / Close * 100
ENDIF
volatilityOK = atrPct >= 1.5

// ------------------------------------------------------------------
// 5. Oscillation : nombre de mouvements/reversals de 5 % sur 252 séances
// Algorithme calqué sur Jedi ; valeur annualisée d'après la durée calendaire.
// Ce critère est informatif, pas éliminatoire.
// ------------------------------------------------------------------
pivot = Close[251]
direction = 0
swings5 = 0

FOR i = 250 DOWNTO 0 DO
  c = Close[i]

  IF direction = 0 THEN
    changePct = (c / pivot - 1) * 100

    IF changePct >= 5 THEN
      direction = 1
      swings5 = swings5 + 1
      pivot = c
    ELSIF changePct <= -5 THEN
      direction = -1
      swings5 = swings5 + 1
      pivot = c
    ENDIF

  ELSIF direction > 0 THEN

    IF c > pivot THEN
      pivot = c
    ELSE
      reversalPct = (pivot - c) / pivot * 100
      IF reversalPct >= 5 THEN
        direction = -1
        swings5 = swings5 + 1
        pivot = c
      ENDIF
    ENDIF

  ELSE

    IF c < pivot THEN
      pivot = c
    ELSE
      reversalPct = (c / pivot - 1) * 100
      IF reversalPct >= 5 THEN
        direction = 1
        swings5 = swings5 + 1
        pivot = c
      ENDIF
    ENDIF

  ENDIF
NEXT

spanYears = (Days - Days[251]) / 365.25
swingsPerYear = 0
IF spanYears > 0 THEN
  swingsPerYear = swings5 / spanYears
ENDIF

// ------------------------------------------------------------------
// 6. Sélection JEDI
// ------------------------------------------------------------------
selected = validHistory AND trendOK AND liquidityOK AND volatilityOK

// Version GRATUITE : ProScreener accepte 3 critères de sortie.
// La liquidité est bien filtrée mais n'est pas affichée afin de laisser
// visibles tendance, volatilité et oscillation.
SCREENER[selected](trendPct AS "Trend %/y", atrPct AS "ATR20 %", swingsPerYear AS "Sw5/y")

// Version PREMIUM : remplacer la ligne SCREENER précédente par celle-ci
// pour afficher aussi la liquidité :
// SCREENER[selected](trendPct AS "Trend %/y", medianTradedValue AS "Med value/d", atrPct AS "ATR20 %", swingsPerYear AS "Sw5/y")
~~~

## Read and use the list

Start with a few securities whose trend, ATR and oscillation are understandable. ATR above 6% deserves the same attention as the corresponding `profile` caution, although this script retains the security. Weak oscillation also deserves examination.

Consult gaps, maximum drawdown, the suggested step and long-history checks in Jedi or the history. The screener does not provide a seven-criterion global ranking.

The script's trend measure uses bar numbers and annualisation over 252 sessions; Jedi uses historical dates. Price sources, adjustments, volumes and compared populations can therefore produce differences. Examine a large discrepancy against these elements before changing the rules.

A screener result sends no price to Jedi's main database. For the chosen security, examine its quotation file or database history with `profile` and `score`, then run `candidate` with a checked current price. Chapter 03 describes this connection; chapter 10 explains files and groups.

The objective remains a coherent list of choices on the main criteria, with a reading of cautions.
