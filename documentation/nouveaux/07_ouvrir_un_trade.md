# Ouvrir un trade

## Passer du projet aux opérations réelles

Le [chapitre 06](06_tools_candidate.md) a évalué un projet. `candidate` ne crée aucun titre, barème, trade ni achat dans la base principale. Il ne transmet aucun ordre au courtier.

L'ouverture comporte trois moments : préparer le trade dans Jedi, exécuter l'achat chez le courtier, puis enregistrer l'exécution réelle. Une opération simplement envisagée ne doit pas être enregistrée.

Ce chapitre reprend **EXA, un titre entièrement fictif** : achat initial de 100 titres à 10 €, barème avec mouvements de 10 %, capital de référence de 5 000 €. Utiliser une base principale d'essai vide, préparée au [chapitre 02](02_installer_et_preparer_jedi.md#préparer-un-espace-dessai-séparé). Les fichiers historiques EXA peuvent exister dans une base de marché ; ils ne créent pas ce titre dans la base principale.

## Préparer l'entrée sur un rebond près du support

Le [chapitre 03](03_choisir_un_titre_support.md#lire-le-graphe-et-ses-repères) décrit le choix d'un titre à partir de son graphe. Un titre retenu peut rester en attente jusqu'à l'apparition du signal d'entrée choisi. Dans un canal latéral ou haussier avec oscillations, un scénario consiste à rechercher le premier rebond observable après un retour près du support.

Avant ce retour, noter la zone de support, l'unité de temps et le critère de reprise. Une règle possible, à tester, est d'attendre une clôture journalière au-dessus du plus haut de la séance ayant testé le support. Le contact avec la ligne, puis un petit mouvement en cours de séance, ne suffisent pas à remplir ce critère de clôture.

Voici deux séances entièrement inventées, dans un canal allant d'une zone proche de 9,50 € à une résistance proche de 12 € :

| Séance | Plus bas | Plus haut | Clôture |
|---|---:|---:|---:|
| A : test du support | 9,50 € | 9,85 € | 9,65 € |
| B : début de reprise | 9,65 € | 10,10 € | 10,00 € |

À la clôture de B, le cours dépasse le plus haut de A : le critère proposé est rempli. La reprise peut cependant échouer. Attendre ce signal conduit ici à examiner une entrée vers 10 €, au-dessus du point bas de 9,50 €. Ces observations ne sont pas extraites du fichier historique EXA.

Vérifier alors le projet au prix auquel l'achat peut être exécuté. Une exécution ultérieure peut avoir un autre prix que la clôture du signal. La suite pédagogique du chapitre suppose une exécution effective à 10 € : la première vente du barème sera à 11 €, sous la résistance observée. Vérifier cette place disponible avec les niveaux du barème ; le niveau suivant peut déjà dépasser le canal.

Examiner également une poursuite de la baisse sous le support : achats proposés, réserve nécessaire et protections du projet. Un canal tracé ne plafonne pas la perte et ne finance pas les achats suivants. `candidate` évalue les règles et le financement ; il ne détecte ni le canal ni le rebond.

Conserver les repères et le critère d'ouverture avec les éléments du projet. Une fois le premier achat enregistré, son prix réel devient `c0` et sa quantité devient `q0`. Les ordres de fonctionnement suivent ensuite le barème et les règles de capital. Les lignes de support et de résistance du graphe ne sont pas enregistrées comme des ordres ou des protections par Jedi.

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

Cet exemple fixe un montant avec `--amount` et laisse `money` désactivé. Si votre projet a été dimensionné avec `--money`, reprendre ses mêmes valeurs `r`, `o` et `n` après le paramétrage initial du trade, avant l'achat. Le capital utilisé pendant le suivi vient de `trading.capital` : le `--capital` fourni à `candidate` n'est pas enregistré automatiquement pour le trade.

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

Pour un trade, utiliser **`T_<ticker>_<numéro>`** : `T_exa_01`, puis `T_exa_02` si un nouveau trade distinct est créé sur le titre fictif EXA. Avec le ticker ERF, le repère serait `T_erf_01`. Le préfixe `T_` permet de reconnaître un trade ; les barèmes utilisent `B_`. Le ticker fournit un repère court, tandis que le libellé complet et l'ISIN restent associés au titre.

À la création, saisir ce nom dans `--name` et choisir un numéro encore disponible, affiché sur au moins deux chiffres. Il s'agit d'une convention proposée à l'utilisateur ; le nom du trade et son numéro ne sont pas calculés automatiquement par Jedi. Le numéro identifie le trade, pas ses paramétrages. Un split, un changement de barème ou une réinitialisation conserve ce nom.

Pour un barème, laisser Jedi attribuer **`B_kc_NN` pour le type I ou `B_vr_NN` pour le type II**, en omettant `--name`. Le type est déduit du builder et le numéro est calculé dans cette famille. Dans notre base vide, le premier barème de type II sera `B_vr_01`. Le [chapitre 13](13_lire_la_structure_d_un_bareme.md#nommer-et-numéroter-un-barème) explique le nommage et le refus des définitions équivalentes.

Employer des lettres sans accents, des chiffres et des soulignés `_`, avec une lettre au début et au moins deux caractères. Les noms doivent être uniques dans leur catégorie et sont insensibles à la casse. Jedi normalise leur écriture : `T_EXA_01` devient `T_exa_01`.

Si le ticker contient un point, un tiret ou un autre caractère non admis dans le nom, adapter ce repère avec les caractères autorisés. Cette adaptation du nom du trade ne change pas le ticker enregistré dans la fiche du titre.

Les exemples de cette édition adoptent ces noms. Un trade déjà créé sous un ancien nom reste utilisable ; employer son nom réel dans les commandes ou le corriger avec `trade update --name`, selon le chapitre 09.

## Conserver le barème retenu

Le paramétrage d'un trade demande un barème permanent de la base principale. Enregistrer sous un nom la définition utilisée pour le candidat :

~~~console
jedidemo scale create \
  --comment="Exemple avec mouvements de 10 %" \
  --builder="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0"
jedidemo scale show B_vr_01
~~~

Si le barème existe déjà, le consulter et le réutiliser. Lorsqu'il vient de `score`, copier le constructeur sans son préfixe d'affichage `I:` ou `II:`. Le nom temporaire d'un barème littéral d'évaluation ne suffit pas à le conserver.

## Créer le trade et son paramétrage initial

~~~console
jedidemo trade create --name=T_exa_01 --security=FR4487601001
jedidemo trade show T_exa_01
~~~

Le nom identifie cette gestion et doit être unique. `--security` accepte l'ISIN ou l'identifiant interne du titre, pas son ticker. `trade create` crée le trade sans `money` ; cette commande n'accepte plus l'option `--money`.

Associer ensuite le trade au barème :

~~~console
jedidemo settings create T_exa_01 --scale=B_vr_01 \
  --date=2026-09-21 --time=09:00:00
~~~

Le trade est maintenant **paramétré**. Si le projet utilise la gestion du capital, activer à ce stade la définition évaluée avec `trade update`, par exemple `jedidemo trade update T_exa_01 --money="r:1%,o:1,n:2"`. L'exemple chiffré de ce chapitre conserve `money` désactivé.

Avant l'achat, ce premier paramétrage possède une position `0:0:0`, avec `q0` et `c0` à zéro. La première opération renseignera la quantité et le prix de référence. Les options d'adaptation `--split`, `--sync` et `--reinit` concernent un trade possédant déjà un paramétrage.

**Respecter la chronologie de toute la base principale.** Un nouveau paramétrage doit être strictement postérieur à la dernière opération et au dernier paramétrage, même s'ils concernent un autre trade. Une opération doit être postérieure au dernier paramétrage global et ne peut pas précéder la dernière opération globale. Les dates et heures saisies sont interprétées dans le fuseau du terminal.

À ce stade, Jedi connaît le projet mais aucun achat n'est encore enregistré.

## Acheter chez le courtier et enregistrer l'exécution

Passer vous-même l'ordre d'achat, suivre son exécution et reprendre les valeurs confirmées par le courtier. Notre exemple suppose l'exécution de 100 titres à 10 €, avec 3,50 € de frais :

~~~console
jedidemo operation create T_exa_01 \
  --date=2026-09-21 --time=09:01:00 \
  --type=Buy --mode=Limit --quantity=100 --price=10 --fees=3.50
~~~

La première opération est un achat de mode `Limit` ou `Market`, selon l'ordre réellement exécuté. Sa date est distincte de celle du paramétrage. La quantité et le prix sont ceux de l'exécution ; ils peuvent différer de l'évaluation préalable.

`--fees` donne le total des frais de cette opération, taxe éventuelle comprise. Si l'option est omise, Jedi applique les frais configurés et la taxe du titre pour un achat. Lorsque l'avis d'opéré donne les frais définitifs, les saisir explicitement. Après enregistrement, `operation fees ID MONTANT` permet de corriger ce total sur toute opération ; le [chapitre 08](08_suivre_un_trade.md#corriger-les-frais-dune-opération-enregistrée) explique comment retrouver son identifiant et vérifier la correction.

Un achat non exécuté ne crée aucune opération. S'il est exécuté en plusieurs fragments, attendre de pouvoir enregistrer une exécution consolidée ; le [chapitre 08](08_suivre_un_trade.md#traiter-une-exécution-partielle) explique la procédure.

## Contrôler l'ouverture et les premiers ordres

~~~console
jedidemo settings list T_exa_01
jedidemo operation list T_exa_01 -c 0,6-14,17
jedidemo trade status T_exa_01
jedidemo trade orders T_exa_01
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

## Reconnaître le statut d'un trade

La commande suivante affiche tous les trades. La colonne **Statut**, juste après
leur nom, indique l'étape atteinte :

~~~console
jedidemo trade list
~~~

| Statut | Situation enregistrée dans Jedi |
|---|---|
| créé | Le trade est associé à un titre, sans paramétrage ni opération. |
| paramétré | Le paramétrage initial avec un barème existe, sans achat enregistré. |
| ouvert | Seul l'achat initial est enregistré et des titres sont détenus. |
| en cours | Au moins une opération a suivi l'achat initial et des titres sont encore détenus. |
| clôturé | Des opérations existent et le stock de la dernière vaut zéro. |

Le statut est calculé sur tout l'historique. Un changement de barème ne ramène
pas un trade à « paramétré ». Une opération décidée personnellement compte aussi
pour le passage d'« ouvert » à « en cours ». L'annulation d'une opération peut
faire revenir à l'étape précédente.

Pour afficher uniquement les trades détenant des titres, donc les statuts
**ouvert** et **en cours** :

~~~console
jedidemo trade list -r
~~~

Pour choisir les statuts, utiliser le champ `status` dans la regex existante :

~~~console
jedidemo trade list "status=^configured$"
jedidemo trade list "status=^(opened|running)$"
jedidemo trade list "status=^closed$ && name=^T_exa"
~~~

Les codes `created`, `configured`, `opened`, `running` et `closed` fonctionnent dans les deux langues. Le libellé affiché dans la langue active est également reconnu, par exemple `status=^clôturé$` en français. Le filtre est insensible à la casse ; `&&` et `||` permettent de le combiner avec les autres champs. Avec `-r`, les deux filtres se cumulent. `--select` s'applique ensuite aux lignes retenues.

Le tableau simple utilise les indices `0=id`, `1=nom`, `2=statut`, `3=money` et
`4=stop`. Avec `--extended`, il ajoute `5=id du titre`, `6=ISIN` et `7=nom du titre`.
Pour ne voir que le nom et le statut :

~~~console
jedidemo trade list -c 1,2
~~~

Ces indices concernent `trade list` ; ceux de `operation list` restent ceux de
ses propres colonnes. En CSV, `status` est aussi placé après `name`, avec les
codes stables `created`, `configured`, `opened`, `running` et `closed`, quelle
que soit la langue d'affichage.

Conserver la définition du barème et le rapport d'ouverture. Le [chapitre 08](08_suivre_un_trade.md) reprend ce trade pour montrer le suivi d'une vente réelle et son enregistrement.
