# Ouvrir un trade

## Passer du projet aux opérations réelles

Le [chapitre 06](06_tools_candidate.md) a évalué un projet. `candidate` ne crée aucun titre, barème, trade ni achat dans la base principale. Il ne transmet aucun ordre au courtier.

L'ouverture comporte trois moments : préparer le trade dans Jedi, exécuter l'achat chez le courtier, puis enregistrer l'exécution réelle. Une opération simplement envisagée ne doit pas être enregistrée.

Ce chapitre reprend **EXA, un titre entièrement fictif** : achat initial de 100 titres à 10 €, barème avec mouvements de 10 %, capital de référence de 5 000 €. Utiliser une base principale d'essai vide, préparée au [chapitre 02](02_installer_et_preparer_jedi.md#préparer-un-espace-dessai-séparé). Les fichiers historiques EXA peuvent exister dans une base de marché ; ils ne créent pas ce titre dans la base principale.

## Vérifier le projet au prix retenu

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0" \
  --amount=1000 --capital=5000
~~~

Dans une base sans autre trade engagé, le résultat donne :

| Information | Valeur |
|---|---:|
| Quantité initiale | 100 |
| Achat initial | 1 000,00 € |
| Besoin maximal, ouverture et réserve hors frais | 1 187,83 € |
| Marge après candidat | 3 812,17 € |

L'opérabilité et le financement sont validés pour cet exemple. Vérifier à nouveau le projet si le prix, le montant, les paramètres ou les engagements du portefeuille changent avant l'exécution.

Cet exemple fixe un montant avec `--amount` et laisse `money` désactivé. Si votre projet a été dimensionné avec `--money`, reprendre ses mêmes valeurs `r`, `o` et `n` lors de la création du trade. Le capital utilisé pendant le suivi vient de `trading.capital` : le `--capital` fourni à `candidate` n'est pas enregistré automatiquement pour le trade.

## Enregistrer le titre et un cours courant

Vérifier d'abord si le titre existe :

~~~console
jedidemo security list EXA
~~~

Dans notre base vide, le créer :

~~~console
jedidemo security create --isin=FR4487601001 --name="Exemple A" --ticker=EXA \
  --tick-buy=0.01 --tick-sell=0.01 --tax-rate=0
jedidemo quote set FR4487601001 --price=10
~~~

Pour un titre réel, vérifier son ISIN, son libellé, son ticker, ses pas de cotation et sa taxe éventuelle. Les pas de 0,01 € et la taxe nulle sont des choix fictifs de cet exemple.

`quote set` enregistre le cours avec la date et l'heure de la saisie. Ce cours sert au suivi ; il ne remplace pas le prix réel de l'achat. Le prix fourni à `candidate` n'avait pas été écrit dans la base.

## Choisir des noms lisibles

Pour un trade, utiliser **`<repère_du_titre>_<numéro>`** : `Exa_01`, puis `Exa_02` si un nouveau trade distinct est créé sur ce titre. Un repère plus long, comme `Airliquide_01`, convient aussi. Le numéro identifie le trade, pas ses paramétrages. Un split, un changement de barème ou une réinitialisation conserve ce nom.

Pour un barème, utiliser **`B<type>_<caractéristiques>_v<version>`**. Notre exemple est `B2_vr10_ki10_v01` : type II, `vr=10%`, `ki=10%`, version 01. La définition complète reste fournie à `--builder` ; le nom ne configure aucun paramètre. Le [chapitre 13](13_lire_la_structure_d_un_bareme.md#nommer-et-versionner-un-barème) précise cette convention.

Employer des lettres sans accents, des chiffres et des soulignés `_`, avec une lettre au début et au moins deux caractères. Les noms doivent être uniques dans leur catégorie et sont insensibles à la casse. Jedi normalise leur écriture : `EXA_01` devient `Exa_01`.

Les exemples de cette édition adoptent ces noms. Un trade déjà créé sous un ancien nom reste utilisable ; employer son nom réel dans les commandes ou le corriger avec `trade update --name`, selon le chapitre 09.

## Conserver le barème retenu

Le paramétrage d'un trade demande un barème permanent de la base principale. Enregistrer sous un nom la définition utilisée pour le candidat :

~~~console
jedidemo scale create --name=B2_vr10_ki10_v01 \
  --comment="Exemple avec mouvements de 10 %" \
  --builder="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0"
jedidemo scale show B2_vr10_ki10_v01
~~~

Si le barème existe déjà, le consulter et le réutiliser. Lorsqu'il vient de `score`, copier le constructeur sans son préfixe d'affichage `I:` ou `II:`. Le nom temporaire d'un barème littéral d'évaluation ne suffit pas à le conserver.

## Créer le trade et son paramétrage initial

~~~console
jedidemo trade create --name=Exa_01 --security=FR4487601001
jedidemo trade show Exa_01
~~~

Le nom identifie cette gestion et doit être unique. `--security` accepte l'ISIN ou l'identifiant interne du titre, pas son ticker. Si le projet utilise la gestion du capital, ajouter la définition évaluée, par exemple `--money="r:1%,o:1,n:2"`, à la commande de création.

Associer ensuite le trade au barème :

~~~console
jedidemo settings create Exa_01 --scale=B2_vr10_ki10_v01 \
  --date=2026-09-21 --time=09:00:00
~~~

Avant l'achat, ce premier paramétrage possède une position `0:0:0`, avec `q0` et `c0` à zéro. La première opération renseignera la quantité et le prix de référence. Les options d'adaptation `--split`, `--sync` et `--reinit` concernent un trade possédant déjà un paramétrage.

**Respecter la chronologie de toute la base principale.** Un nouveau paramétrage doit être strictement postérieur à la dernière opération et au dernier paramétrage, même s'ils concernent un autre trade. Une opération doit être postérieure au dernier paramétrage global et ne peut pas précéder la dernière opération globale. Les dates et heures saisies sont interprétées dans le fuseau du terminal.

À ce stade, Jedi connaît le projet mais aucun achat n'est encore enregistré.

## Acheter chez le courtier et enregistrer l'exécution

Passer vous-même l'ordre d'achat, suivre son exécution et reprendre les valeurs confirmées par le courtier. Notre exemple suppose l'exécution de 100 titres à 10 €, avec 3,50 € de frais :

~~~console
jedidemo operation create Exa_01 \
  --date=2026-09-21 --time=09:01:00 \
  --type=Buy --mode=Limit --quantity=100 --price=10 --fees=3.50
~~~

La première opération est un achat de mode `Limit` ou `Market`, selon l'ordre réellement exécuté. Sa date est distincte de celle du paramétrage. La quantité et le prix sont ceux de l'exécution ; ils peuvent différer de l'évaluation préalable.

`--fees` donne le total des frais de cette opération, taxe éventuelle comprise. Si l'option est omise, Jedi applique les frais configurés et la taxe du titre pour un achat. Lorsque l'avis d'opéré donne les frais définitifs, les saisir explicitement. Après enregistrement, `operation fees ID MONTANT` permet de corriger ce total sur toute opération ; le [chapitre 08](08_suivre_un_trade.md#corriger-les-frais-dune-opération-enregistrée) explique comment retrouver son identifiant et vérifier la correction.

Un achat non exécuté ne crée aucune opération. S'il est exécuté en plusieurs fragments, attendre de pouvoir enregistrer une exécution consolidée ; le [chapitre 08](08_suivre_un_trade.md#traiter-une-exécution-partielle) explique la procédure.

## Contrôler l'ouverture et les premiers ordres

~~~console
jedidemo settings list Exa_01
jedidemo operation list Exa_01 -c 0,6-14,17
jedidemo trade status Exa_01
jedidemo trade orders Exa_01
~~~

Le stock doit être de **100 titres**, `q0` de 100, `c0` de 10 € et la position `0:0:0`. L'investissement net hors frais vaut 1 000 €. Comparer le stock et l'opération au relevé du courtier.

Les deux ordres de fonctionnement obtenus sont :

| Type | Mode | Quantité | Cours | Montant hors frais |
|---|---|---:|---:|---:|
| Buy | Limit | 8 | 9,00 € | 72,00 € |
| Sell | Limit | 6 | 11,00 € | 66,00 € |

Ces lignes sont des propositions calculées. Il vous reste à placer les ordres chez le courtier et à surveiller leur exécution. Ne pas les enregistrer comme des opérations avant leur réalisation.

Pour examiner un mouvement de hausse puis de baisse sans toucher aux opérations de la base :

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  scale=vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0,q0=100,c0=10,tick=0.01 1 -1
~~~

Le parcours calculé vend 6 titres à 11 €, puis en rachète 6 à 9,90 € : le stock revient à 100. `play` sert ici à comprendre le barème ; il ne décrit pas des exécutions réelles et ne garantit pas ce parcours.

Conserver la définition du barème et le rapport d'ouverture. Le [chapitre 08](08_suivre_un_trade.md) reprend ce trade pour montrer le suivi d'une vente réelle et son enregistrement.
