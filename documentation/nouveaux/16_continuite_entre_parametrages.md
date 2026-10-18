# Assurer la continuité entre paramétrages

Un trade peut changer de barème sans recommencer son histoire. Achats, ventes, frais et titres détenus restent ceux des opérations enregistrées. Le nouveau paramétrage doit retrouver des références cohérentes avec la position atteinte.

Le [chapitre 09](09_adapter_ou_terminer_un_trade.md) donne les commandes de suivi. Nous expliquons ici ce que Jedi conserve et recalcule.

## Changer le repère local

Un changement ordinaire conserve l'échelon `e`. Les compteurs de paliers `x` et `y` repartent de zéro. Les sauts déjà parcourus sont reportés dans des coefficients cumulés :

| Coefficient | Ce qu'il conserve |
|---|---|
| `kcpc` | Multiplicateur de cours provenant des paramétrages antérieurs. |
| `kspc` | Multiplicateur de stock provenant des paramétrages antérieurs. |

Leur valeur initiale est 1. Un changement ordinaire conserve `c0` et `q0`, qui ne deviennent pas automatiquement le dernier prix et le stock détenu. Il transporte les multiplicateurs nécessaires à la continuité.

Les anciennes positions ne sont pas réécrites. Le nouveau paramétrage emploie un autre repère local, identifié par son rang dans les listes.

## Vérifier un changement sans modifier le barème

Trois hausses de notre type I conduisent de 100 titres à 10 € à 63 titres à 16,80 €, en position `1:0:+1`. Réappliquer le même barème montre la continuité sans changer les règles :

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 3 \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 1
~~~

| Moment | Position dans le repère utilisé | Stock | Dernier prix exécuté |
|---|---|---:|---:|
| Avant changement | Ancien paramétrage, `1:0:+1` | 63 | 16,80 € |
| Départ du nouveau | Nouveau repère, `0:0:+1` | 63 | 16,80 € |
| Hausse suivante | Nouveau repère, `1:0:0` | 62 | 19,60 € |

Au changement, `kcpc=1.40` et `kspc=1.10/1.40≈0.785714`. Avec `c0=10` et `q0=100`, les références locales à zéro correspondent à 14 € et 78,571429 titres théoriques. L'échelon conservé `+1` retrouve 16,80 € et une cible proche des 63 titres détenus.

La hausse suivante vend **1 titre à 19,60 €**. Comparer sans changement :

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 3 1
~~~

Prix et quantité sont identiques. La position finale est `2:0:0` : le premier saut reste dans les compteurs initiaux.

## Modifier réellement les règles

Un autre barème emploie le même report. Le parcours passé est conservé ; les nouvelles règles fixent les prochaines cibles et peuvent changer prix, quantité ou mode des ordres.

Pour le type II, la dernière opération intervient aussi dans le recentrage du chapitre 15. Reconstituer les ordres avec le dernier cours seul ferait perdre une partie du contexte.

`tools calc` ne prend pas l'historique des changements ni les coefficients cumulés d'un trade. Pour vérifier un changement, utiliser `play` avec le parcours complet, ou consulter les paramétrages et les ordres du trade réel.

## Distinguer report et réinitialisation

| Action | Intention |
|---|---|
| Changement ordinaire | Conserver `q0`, `c0` et l'échelon ; reporter les sauts. |
| `reinit=reset,prix` | Nouveau départ mécanique avec le stock détenu et le prix choisi. |
| `reinit=merge,prix` | Nouveau départ incorporant l'opération complémentaire suivante. |
| `split=nouveau:ancien` | Adapter les références à une division ou un regroupement. |
| `sync=x:y:e` | Imposer une position justifiée pour un type I. |

Une réinitialisation remet la position de départ à `0:0:0` et les coefficients cumulés `kcpc` et `kspc` à **1**. Elle n'efface pas les pertes et gains enregistrés. `sync` conserve l'échelon imposé dans le nouveau repère ; ce n'est pas une transaction.

Après la vente de 20 à 12 €, réinitialiser à 12 € utilise les **80 titres détenus** :

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 1 reinit=reset,12 -1
~~~

La baisse suivante achète 16 à 9,60 €, portant le stock à 96. Sans reset, le retour aurait acheté 20 à 10 €.

Pour incorporer un achat complémentaire de 20 à 12 € :

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 1 reinit=merge,12 "20@12.00" -1
~~~

Les références deviennent 100 titres à 12 €. La baisse suivante achète 20 à 9,60 €, pour un stock de 120. L'achat complémentaire est bien une opération ; il ne résulte pas du seul changement de réglage.

## Appliquer le split avant la réinitialisation

`split + reinit=reset` et `split + reinit=merge` sont acceptés dans un même paramétrage à partir de cette évolution de Jedi 1.1. Le stock de la dernière opération est converti d'abord. Les prix fournis à `reinit` et à la transaction suivante sont déjà dans la nouvelle unité : ils ne subissent pas une conversion supplémentaire.

Pour 1 790 anciens titres regroupés à raison de `1:10`, le stock effectif est de 179 titres. Avec un prix de reprise de 12 € :

| État | Stock effectif | q0 | c0 | Position de départ |
|---|---:|---:|---:|---|
| Après `split=1:10,reinit=reset,12` | 179 | 179 | 12 € | `0:0:0` |
| Après `split=1:10,reinit=merge,12`, avant transaction | 179 | 0 | 0 | `0:0:0` |
| Merge, après achat de 21 nouveaux titres à 10 € | 200 | 200 | 11,79 € | `0:0:0` |

Les coefficients cumulés repartent à 1 dans les deux réinitialisations. Pour merge, le prix de 12 € reste conservé dans l'option `reinit` pendant l'attente ; il sert au calcul pondéré de la transaction manuelle. Les ordres automatiques ne sont disponibles qu'après celle-ci.

Les opérations anciennes gardent leurs unités et leurs positions. Avant la première transaction du nouveau paramétrage, la synthèse, les ordres et les projections utilisent son stock effectif et sa nouvelle position. Après cette transaction, le stock enregistré est déjà converti ; Jedi ne réapplique pas le split.

`split + sync`, `sync + reinit` et les trois options réunies restent refusés. Un paramétrage doit toujours être utilisé par une opération avant d'en créer un autre. Les exemples pratiques figurent au chapitre 09 et les simulations complètes au [chapitre 19](19_verifier_avec_tools_calc_et_play.md#simuler-un-regroupement-avec-reset-ou-merge).

## Contrôler le changement

Conserver l'état avant modification et examiner les nouvelles propositions dans une simulation. Après enregistrement, relire paramétrages, opérations et ordres comme au chapitre 09.

Un changement doit avoir une raison explicite : nouveau barème étudié, opération sur titres, correction ou nouvelle décision de suivi. Une note en conserve le contexte. Les ordres du courtier doivent ensuite être adaptés à l'état réellement exécuté ; la continuité des calculs ne réalise pas cette adaptation.
