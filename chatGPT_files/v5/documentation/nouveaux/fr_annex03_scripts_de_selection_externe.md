# Script de sélection externe ProScreener JEDI

## Rôle du screener

Le ProScreener JEDI fournit une liste de titres à examiner dans ProRealTime. Ses critères sont cohérents avec les quatre principales questions de `profile` : tendance, liquidité, volatilité et oscillation.

La tendance, la liquidité et la volatilité déclenchent les filtres d'entrée dans la liste. L'oscillation apporte une information de choix ; elle n'est pas éliminatoire dans ce script. La liste laisse ensuite l'utilisateur choisir le titre, le barème et le projet à évaluer.

## Préparer l'exécution

Dans ProRealTime, ouvrir ProScreener, créer un screener par programmation et coller le listing ci-dessous. Choisir explicitement le marché ou la liste de titres à examiner et travailler sur les **barres journalières**. Le programme indique `TIMEFRAME(Daily)`.

Lire les résultats après la fin de la séance choisie. Une barre en formation peut encore changer de clôture, de volume et d'amplitude. Pour rapprocher les résultats de Jedi, vérifier la date de la dernière cotation du dataset avec `market info` et `market list --last-quote`.

Le [manuel officiel ProScreener](https://www.prorealtime.com/en/pdf/proscreener.pdf), version 6.1.0 du 1er décembre 2025, consulté le 3 octobre 2026, indique 256 chandeliers utilisés pour les calculs, ou 1 024 sur les plateformes Premium. La fenêtre de 252 séances du script tient dans ce périmètre. Le manuel indique aussi trois ou six critères de sortie selon la licence.

Le listing utilise trois colonnes actives. Une variante à quatre colonnes est conservée en commentaire : utiliser cette variante seulement si la plateforme l'accepte, en remplaçant la dernière instruction active. Garder une seule instruction `SCREENER` active.

## Ce que mesure le script

| Mesure | Calcul et rôle |
|---|---|
| Tendance | Pente sur 252 séances, annualisée ; filtre strictement supérieur à −12 %. |
| Liquidité | Médiane de clôture × volume sur 252 séances ; filtre supérieur ou égal à 100 000. |
| ATR20 | Moyenne simple de 20 amplitudes réelles, divisée par la clôture ; filtre supérieur ou égal à 1,5 %. |
| Oscillation | Mouvements et retournements d'au moins 5 % sur 252 séances, annualisés ; information affichée. |

Avec des cours en euros et des volumes en titres, la liquidité est exprimée en euros par séance. Le seuil ne convertit pas les devises. L'ATR du script est calculé directement avec une moyenne simple ; conserver ce calcul pour la cohérence avec Jedi.

Les colonnes actives sont `Trend %/y`, `ATR20 %` et `Sw5/y`. La liquidité est filtrée même lorsqu'elle n'est pas affichée. Le programme accepte un historique d'au moins 252 barres ; il ne reproduit pas le contrôle de profondeur d'au moins trois années de `profile`.

## Listing complet

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

## Lire et utiliser la liste

Commencer par quelques titres dont la tendance, l'ATR et l'oscillation sont compréhensibles. Un ATR supérieur à 6 % mérite la même attention que la vigilance correspondante de `profile`, bien que ce script conserve le titre. Une faible oscillation reste également à examiner.

Les gaps, le recul maximal, le pas suggéré et les contrôles de qualité longs sont à consulter dans Jedi ou sur l'historique. Le screener ne fournit pas un classement global à sept critères.

La mesure de tendance du script utilise les numéros de barres et une annualisation sur 252 séances ; Jedi utilise les dates de l'historique. La source des cours, leurs ajustements, les volumes et les populations comparées peuvent donc produire des écarts. Examiner un écart important sur ces éléments avant de changer les règles.

Un résultat de screener ne transmet aucun cours à la base principale de Jedi. Pour le titre choisi, examiner son fichier de cotations ou son historique en base avec `profile` et `score`, puis lancer `candidate` avec un prix actuel vérifié. Le chapitre 03 décrit ce raccordement ; le chapitre 10 explique les fichiers et groupes.

L'objectif reste une liste de choix cohérente sur les principaux critères, accompagnée d'une lecture des points de vigilance.
