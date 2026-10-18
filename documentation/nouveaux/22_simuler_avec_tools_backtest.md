# Simuler un barème avec tools backtest

## Un barème fixé sur un historique

`backtest` parcourt les cotations d'un titre et simule les opérations proposées par un barème fixé. Il utilise une base de simulation en mémoire : il n'ajoute aucun trade à votre portefeuille et ne met pas à jour les cotations de marché.

La première ouverture utilise le prix **Open** de la première séance sélectionnée où le dimensionnement permet l'achat. Après une liquidation complète, une nouvelle ouverture est tentée à la séance suivante. Le rapport agrège donc éventuellement plusieurs trades successifs sur le même titre.

Depuis le fichier fictif livré :

~~~console
jedidemo tools backtest cotations_EXA.txt \
  --scale="kc:1.23,1.14,0.88,0.76,ki:0%,kb:1,kd:0.2"
~~~

Depuis la base Demo préparée au chapitre 10 :

~~~console
jedidemo tools backtest --database=demo --security=EXA \
  --scale="kc:1.23,1.14,0.88,0.76,ki:0%,kb:1,kd:0.2"
~~~

`--scale` accepte une définition ou le nom d'un barème déjà enregistré dans cet espace. Le préfixe `I:` ou `II:` montré par `score` est retiré avant transmission. Ici, le constructeur donne un barème de type I dont le rapport affiche la définition opérationnelle.

## Choisir les dates

Sans sélection explicite, `backtest` utilise **tout l'historique disponible**. Il ne reprend pas automatiquement la fenêtre de 750 séances de `score`.

~~~console
jedidemo tools backtest cotations_EXA.txt --select=l750 \
  --scale="kc:1.23,1.14,0.88,0.76,ki:0%,kb:1,kd:0.2"
~~~

`--date` et `--select` suivent les règles du [chapitre 21](21_preparer_une_etude_historique.md#isoler-réellement-une-année). Le début sélectionné change le prix d'ouverture et le point de départ de la mécanique. Un test commencé le 1er janvier avec un nouveau trade ne prolonge pas automatiquement un trade commencé l'année précédente.

## Deux modes de dimensionnement

Sans `--capital`, chaque ouverture demande un **montant fixe**, calculé avec la configuration :

~~~text
montant = partie entière de
          simulation.capital × simulation.risk_rate / simulation.distance
~~~

Avec les réglages d'origine, `20000 × 0.015 / 0.2 = 1500 €`. La quantité entière réellement achetée peut laisser une petite fraction de ce montant inutilisée. L'option `--distance` modifie ce calcul ; elle ne représente pas le nombre d'échelons `n` de `money`.

Ajouter `--money` sans `--capital` ajoute les protections du trade, mais conserve ce dimensionnement par montant fixe.

Avec **`--capital`**, Jedi demande aussi **`--money`** et calcule la quantité à chaque ouverture selon le risque, le plafond de capital et les exigences d'opérabilité :

~~~console
jedidemo tools backtest cotations_EXA.txt \
  --scale="kc:1.23,1.14,0.88,0.76,ki:0%,kb:1,kd:0.2" \
  --capital=20000 --money="r:1.5%,o:1,n:2"
~~~

Le [chapitre 18](18_capital_risque_et_dimensionnement.md) explique `r`, `o` et `n`. Par défaut, ce mode exige au moins **deux titres par ordre contrôlé** et examine **trois échelons haussiers**. `--minimum-quantity` et `--operability-steps` modifient ces contrôles ; ces options exigent le mode `--capital`.

Une ouverture non opérable est reportée à la séance suivante et comptée dans le rapport. `--distance` ne se combine pas avec `--capital`. Le capital fourni reste la référence de dimensionnement : le backtest ne simule pas le financement simultané d'un portefeuille de plusieurs titres et ne réinvestit pas automatiquement les gains dans un capital augmenté. `candidate` reste nécessaire pour examiner le financement d'un projet réel avec les réserves de votre portefeuille.

## Connaître les hypothèses d'exécution

Le fonctionnement courant utilise **`--execution=conservative`** et **`--opening-day-orders=next`**. Les ordres issus de l'achat initial deviennent actifs à la séance suivante. Le moteur retient **au plus une opération proposée par séance**, en plus de l'ouverture lorsqu'elle a lieu ; il ne déroule pas tous les échelons qu'une journée pourrait traverser.

Avec des données journalières, on connaît Open, High, Low et Close, mais pas l'ordre des mouvements entre l'ouverture et la clôture. Jedi applique donc des règles explicites :

1. Un ordre déjà exécutable au prix d'ouverture est prioritaire sur un ordre seulement touché plus tard dans la séance.
2. Si plusieurs ordres restent possibles sans chronologie connue, la politique choisit selon leur nature. Elle donne généralement priorité à la protection, puis à l'achat à la baisse, puis à la vente à la hausse. Pour une protection de perte encore non franchie à l'ouverture, l'achat à la baisse peut précéder cette protection ; une protection des gains est prioritaire sur cet achat.
3. Le prix d'ouverture est appliqué lorsqu'un gap rend l'ordre immédiatement exécutable ; sinon, le niveau de l'ordre est utilisé.

| Ordre actif | Niveau | Open | Prix simulé |
|---|---:|---:|---:|
| Achat Limit | 8 € | 7 € | 7 € |
| Vente Limit | 12 € | 13 € | 13 € |
| Vente StopLoss | 6 € | 4 € | 4 € |
| Achat Stop | 12 € | 13 € | 13 € |

Un gap favorable peut améliorer un prix Limit ; un gap défavorable peut dépasser le niveau Stop et le risque prévu. Le nom `conservative` désigne cette convention, sans garantir le pire parcours intrajournalier possible.

La simulation ne reconstitue ni le carnet d'ordres, ni les exécutions partielles, ni le spread. Le volume quotidien ne sert pas à limiter automatiquement la quantité exécutée. Les frais viennent de la configuration ; les prix simulés ne remplacent pas l'application réelle des pas de cotation et des conditions du courtier.

Les variantes `--execution=legacy` et `--opening-day-orders=same` sont conservées pour des examens particuliers. `legacy` change les priorités et utilise les niveaux théoriques plutôt que les prix de gap. `same` autorise les ordres dès la journée d'ouverture. Les indiquer explicitement dans toute comparaison qui les utilise.

## Lire d'abord le rapport compact

La première commande de ce chapitre, sur les 851 séances d'EXA, produit :

~~~text
Historique : 2023-06-30 → 2026-10-02 (851 séances)
Montant demandé par ouverture : 1500.00 €
Ouvertures : 1 ; tentatives non opérables : 0
Premier achat : 2023-06-30, 150 titres pour 1500.00 €
Opérations, ouvertures comprises : 25
Gain brut cumulé : 647.11 €
Frais cumulés : 19.14 €
Gain net cumulé : 627.97 €
Investissement maximal, hors frais : 1500.00 €
Gain net / investissement maximal : 41.86 %
Titres détenus en fin de test : 122 ; valeur 1578.97 €
~~~

Le gain brut additionne les ventes, soustrait les achats et ajoute la valeur des titres restants à la dernière clôture. Le gain net retire les frais. L'investissement maximal est le plus grand des pics d’achats moins ventes de chaque trade, hors frais. Les trades du backtest se succèdent sans se chevaucher : ce maximum global doit donc apparaître dans au moins un des trades.

Les 41,86 % couvrent toute la période ; ce n'est pas un taux annuel. La valeur finale de 1 578,97 € est une composante du gain, pas un gain à ajouter aux 627,97 €. Les 122 titres ne sont pas vendus artificiellement à la fin : le rapport ne facture pas une liquidation finale qui n'a pas eu lieu.

## Comprendre le maximum quand un trade est rouvert

Un autre exemple fictif illustre le calcul : le premier trade achète 100 titres à 10 €, puis les vend tous à 8,50 €. Sa perte brute est de 150 €. Le suivant achète de nouveau 100 titres à 10 €.

| Trade | Pic d’investissement hors frais | Situation |
|---|---:|---|
| Trade_01 | 1 000 € | Clos, perte brute de 150 €. |
| Trade_02 | 1 000 € | Ouvert après la clôture du précédent. |
| Maximum du backtest | **1 000 €** | Le plus grand des deux pics. |

Le solde cumulé achats moins ventes vaut alors 1 150 € : les 150 € perdus restent dans le bilan financier. Ce solde sert à calculer le gain cumulé ; il ne constitue pas le maximum individuel d’un trade. Dans les rapports détaillés et techniques, son libellé est **solde achats–ventes**. Il peut dépasser le maximum, notamment après une perte passée.

Le tableau financier demandé par `-c f` suit désormais **l’ordre de création des trades**, du premier au dernier. La synthèse compacte `r`, la synthèse technique et le total de `f` utilisent le même maximum. Les rendements et les ratios fondés sur ce maximum sont recalculés avec cette valeur.

## Examiner les opérations et les gaps

~~~console
jedidemo tools backtest cotations_EXA.txt \
  --scale="kc:1.23,1.14,0.88,0.76,ki:0%,kb:1,kd:0.2" -c rfo
~~~

`r` conserve le rapport, `f` ajoute les résultats financiers et `o` les opérations. `t` liste les trades, `d` les ordres encore actifs et `p` le graphique. Ces sorties détaillées peuvent être larges : les examiner au terminal ou les conserver dans un fichier. Les sélecteurs de colonnes de `play` ne sont pas des options de `backtest`.

Le petit fichier `cotations_GAP.txt` permet de vérifier une perte dépassant le risque prévu :

~~~console
jedidemo tools backtest cotations_GAP.txt \
  --scale="kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1" \
  --capital=20000 --money="r:2.5%,o:1,n:2" -c ro
~~~

Jedi achète 125 titres à 10 €, puis exécute la protection à l'ouverture suivante à 4 €, alors que son niveau était à 6 €. Le risque nominal de 500 € devient une perte brute de 750 €, et une perte nette de 756,13 € avec les frais. Ce parcours fictif de deux séances explique une règle ; il ne constitue pas une étude de rendement.

## Comparer des scénarios fixés

Changer seulement le barème, sur les mêmes données et avec les mêmes options, permet une comparaison lisible. Par exemple :

~~~console
jedidemo tools backtest cotations_EXA.txt \
  --scale="vr:5%,np:2,nn:2,ki:0%,kb:1,kd:0.0"
~~~

Conserver aussi un scénario perdant et les hypothèses qui l'expliquent. L'affichage `--display=technical` ajoute les diagnostics détaillés de compatibilité ; le rapport compact fournit la première lecture économique. Le [chapitre 24](24_interpreter_comparer_et_suivre.md) organise l'interprétation commune aux scénarios.
