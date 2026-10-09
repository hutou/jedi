# Suivre un exemple complet de trade

Rassemblons les calculs dans un parcours : dimensionner, observer les flux, changer un paramétrage, comparer deux suites et fermer le stock. Ce titre fictif est distinct d'EXA01 dans la partie I. Tous les parcours ci-dessous sont exécutés en mémoire avec `tools play` ; ils ne créent aucun trade.

L'exemple utilise un type I, un cours initial de 10 €, un pas de 0,01 € et des frais de 0,35 %, sans minimum. Les commandes de `candidate` se reproduisent dans une base d'essai sans trade ouvert.

## Dimensionner le projet

Par défaut, `candidate` contrôle trois échelons haussiers pour l'opérabilité. L'aide affiche la valeur configurée, soit `3` avec la configuration d'origine :

~~~console
jedidemo tools candidate --help
~~~

La ligne `--operability-steps=COUNT` indique « défaut : 3 ». Si la configuration de cet espace d'essai change, la valeur affichée suit ce réglage.

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --money=r:2.5%,o:1,n:2 --capital=20000
~~~

Avec 20 000 € de capital et 2,5 % de risque, `R` vaut 500 €. Deux échelons de baisse mènent à 6 €, soit 40 % sous l'entrée. La quantité retenue est **125**, pour une ouverture de **1 250 €**.

Le besoin maximal projeté hors frais vaut **1 855,60 €**, dont 605,60 € de réserve future. Ce montant porte sur trois échelons, selon l'horizon indiqué par `candidate`. Le [chapitre 18](18_capital_risque_et_dimensionnement.md) explique pourquoi cet horizon diffère de `n`.

Les parcours suivants **n'activent pas `money`** : ils isolent la mécanique du barème. Un trade avec protections peut suivre d'autres ordres. On ne déduit donc pas de ces parcours que le trade protégé exécuterait les mêmes achats et ventes.

## Suivre les opérations

~~~console
jedidemo tools play -c o0,6-14,17f -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=125,c0=10,tick=0.01" -1 1 mark 1 1
~~~

| Opération | Prix | Stock après opération | Investissement net hors frais |
|---|---:|---:|---:|
| Achat initial de 125 | 10,00 € | 125 | 1 250,00 € |
| Achat de 25 | 8,00 € | 150 | 1 450,00 € |
| Vente de 25 | 10,00 € | 125 | 1 200,00 € |
| Vente de 25 | 12,00 € | 100 | 900,00 € |
| Vente de 2 | 14,00 € | 98 | 872,00 € |

La marque suit le retour à 10 €. Ce premier aller-retour a produit 50 € brut. Au cours final de 14 €, les 98 titres valent 1 372 € : le gain brut global est **500 €**. Il comprend la valeur du stock restant ; tout ce gain n'a pas été encaissé.

L'investissement maximal effectivement rencontré est ici 1 450 €. La réserve de `candidate` examinait un autre trajet, baissier : elle ne prédit pas les achats de chaque parcours.

## Reprendre le même barème dans un nouveau paramétrage

Réappliquons le barème après la vente à 14 €, puis avançons d'un échelon :

~~~console
jedidemo tools play -c o0,6-14,17cf -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=125,c0=10,tick=0.01" -1 1 mark 1 1 \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 1
~~~

Le nouveau paramétrage conserve `q0=125` et `c0=10`, remet les compteurs locaux à zéro et reporte les coefficients cumulés : `kcpc=1,4` et `kspc≈0,785714`. Changer le paramétrage ne déclenche aucune transaction.

La hausse suivante vend **19 titres à 16,80 €**. Le stock devient 79, l'investissement net 552,80 € et la valeur du stock 1 327,20 €. Le gain brut vaut **774,40 €**. Les nouvelles coordonnées se lisent dans le nouveau paramétrage ; les anciennes opérations conservent les leurs.

## Consigner une décision exceptionnelle

Pour un trade suivi réellement dans la base, une note peut expliquer une décision ou un contrôle qui ne se lit pas dans les opérations. Pour cet exemple, l'écriture ci-dessous est facultative et doit rester dans la base d'essai :

~~~console
$ jedidemo note create 2026-10-05 "PEDA20 - réglage" "État vérifié :
> 98 titres détenus après la vente de 2 titres à 14 EUR.
> Même barème réappliqué pour vérifier la continuité.
> Ordres du courtier à contrôler avant de poursuivre."
~~~

`$` et `>` représentent les invites du shell et ne se saisissent pas. Le contenu comporte de vrais retours à la ligne. La note appartient au journal général ; `PEDA20` dans son résumé sert de repère et n'est pas un trade créé par `play`.

~~~console
jedidemo note list PEDA20
~~~

Si cette note reçoit l'identifiant 1 dans une base vide :

~~~console
jedidemo note show 1
jedidemo note update 1 --edit
~~~

Sinon, utiliser l'identifiant affiché par `note list`. L'éditeur permet d'ajouter ensuite la confirmation du courtier, notamment l'annulation d'anciens ordres. Sa préparation est décrite au [chapitre 08](08_suivre_un_trade.md#rédiger-avec-un-éditeur).

## Comparer une baisse au lieu de la hausse

Repartons du même état après la vente à 14 € et le changement de paramétrage. Remplaçons seulement le dernier mouvement par une baisse :

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=125,c0=10,tick=0.01" -1 1 mark 1 1 \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 -1
~~~

Cette baisse achète **20 titres à 11,20 €**. Le stock devient 118 et l'investissement net 1 096 €.

| Suite après le changement | Stock | Cours final | Gain brut |
|---|---:|---:|---:|
| Une hausse | 79 | 16,80 € | 774,40 € |
| Une baisse | 118 | 11,20 € | 225,60 € |

Ces deux branches montrent des conséquences possibles du même réglage. Elles ne donnent pas la probabilité de chacune.

## Fermer le stock et rapprocher le résultat

Dans la branche haussière, vendons manuellement les 79 titres restants à 16,80 € :

~~~console
jedidemo tools play -c o0,6-14,17f -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=125,c0=10,tick=0.01" -1 1 mark 1 1 \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  1 "-79@16.80"
~~~

Cette vente ferme volontairement le stock ; elle ne correspond pas à la quantité cible de l'ordre ordinaire suivant.

| Bilan de la branche fermée | Montant |
|---|---:|
| Achats totaux | 1 450,00 € |
| Ventes totales | 2 224,40 € |
| Stock final | 0 titre |
| Gain brut | 774,40 € |
| Frais cumulés | 12,88 € |
| Gain après frais | 761,52 € |

Le bilan financier répartit le gain brut en 50 € avant la marque et 724,40 € après. Dans un trade réel, enregistrer l'exécution du courtier selon le [chapitre 09](09_adapter_ou_terminer_un_trade.md), avec ses frais effectivement facturés.

À chaque étape, rapprocher le stock, les flux monétaires, le paramétrage actif et les prochains ordres. Les notes expliquent les événements exceptionnels ; elles ne remplacent pas l'enregistrement des exécutions. La partie III confrontera cette mécanique à des cotations historiques, avec les limites propres à la simulation.
