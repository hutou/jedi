# Passer de l'état du trade aux ordres

Un paramétrage plus récent que la dernière transaction peut déjà modifier le stock effectif ou la position de départ. Après `split + reset`, Jedi utilise immédiatement le stock converti, la position `0:0:0` et le prix de reprise. Après `split + merge`, il attend la transaction manuelle avant de calculer les ordres automatiques. Voir le [chapitre 09](09_adapter_ou_terminer_un_trade.md#combiner-un-regroupement-et-une-réinitialisation).

Après une opération, Jedi calcule les cibles voisines du barème. Il transforme chaque cible de stock en une quantité à négocier et chaque cours théorique en un prix compatible avec le pas de cotation.

Le courtier exécute les ordres ; Jedi ne lui transmet rien. Une opération est enregistrée quand une exécution a réellement eu lieu, comme au [chapitre 08](08_suivre_un_trade.md).

## Calculer la quantité à négocier

Le stock théorique est arrondi au titre entier le plus proche, puis comparé au stock détenu :

~~~text
quantité signée = stock cible arrondi − stock détenu
~~~

Un résultat positif demande un achat ; un résultat négatif une vente de sa valeur absolue. Depuis 100 titres, une cible de 80 donne `−20` : vendre 20 titres.

Jedi ne vend donc pas toujours une fraction fixe de `q0`. Il rejoint une cible depuis le stock effectivement enregistré, y compris lorsque l'exécution précédente a différé de la théorie.

## Lire Limit et Stop

Le sens du mouvement et celui de la transaction déterminent le mode :

| Cible atteinte par | Transaction | Mode |
|---|---|---|
| Une hausse | Vendre | Sell Limit |
| Une baisse | Acheter | Buy Limit |
| Une hausse | Acheter | Buy Stop |
| Une baisse | Vendre | Sell Stop |

Un Stop de fonctionnement peut donc venir du barème. Il ne signifie pas nécessairement liquidation ou protection du capital.

Au premier échelon de notre type I, vendre 20 à 12 € ou acheter 20 à 8 € sont deux propositions Limit.

## Observer un Stop de fonctionnement

Une autre liste `ks` peut inverser le sens attendu. Garder les cours et remplacer le stock par `ks:0.4,1.8` :

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.4,1.8,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 2
~~~

La première hausse vend 60 à 12 €, laissant 40 titres. Le saut vise 79 à 14 € : **achat Stop de 39 titres**.

Sur un trajet baissier distinct :

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.4,1.8,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" -2
~~~

La première baisse achète 80 à 8 €, portant le stock à 180. Le saut inférieur vise 150 à 6 € : **vente Stop de 30 titres**. Le trade n'est pas liquidé ; il reste 150 titres.

Le contrôle optimisé aide à repérer certaines inversions. Il ne garantit ni des quantités suffisantes après arrondi ni l'absence de Stop sur tous les parcours de type II.

## Arrondir au pas de cotation

La cible d'une hausse est arrondie vers le haut, celle d'une baisse vers le bas, avec le pas correspondant à l'achat ou à la vente.

Une référence de 10,03 € multipliée par 1,20 donne 12,036 €. Avec un pas de 0,05 € :

~~~console
jedidemo tools calc price \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  position=0:0:+1 c0=10.03 tick=0.05 dir=up
jedidemo tools calc price \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  position=0:0:+1 c0=10.03 tick=0.05 dir=down
~~~

On obtient **12,05 €** avec `dir=up` et **12,00 €** avec `dir=down`. La seconde commande montre l'autre arrondi du même nombre ; elle ne transforme pas `+1` en cible baissière. Déclarer le pas du titre et du marché concernés.

## Examiner les petites quantités

Un stock initial apparemment important peut produire un petit ordre :

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 3
~~~

Les trois hausses vendent 20, **1**, puis 16 titres. Avec le contrôle par défaut de deux titres minimum, la quantité 1 signale un fonctionnement dégradé. Une quantité nulle bloque la direction et l'ordre n'est pas ajouté aux propositions. Un avertissement peut aussi annoncer une petite quantité à venir.

Le [chapitre 18](18_capital_risque_et_dimensionnement.md) montre pourquoi le contrôle d'ouverture ne dispense pas de relire les ordres après dimensionnement et pendant le suivi.

## Distinguer le StopLoss

Avec la gestion du capital `money`, Jedi peut proposer une vente StopLoss du stock. Son état indique `CL` pour contrôler la perte ou `GP` pour protéger un gain calculé. L'option de quantité nette peut tenir compte de l'ordre de vente haussier.

Ce StopLoss découle d'une projection financière et de l'état du trade. Ce n'est pas un troisième échelon. Il peut supprimer les ordres ordinaires situés à son prix ou plus bas. Le chapitre 18 explique son calcul et ses limites.

Les indicateurs de prix de `trade orders` situent les propositions par rapport au cours connu. Ils ne prouvent pas une exécution et ne garantissent pas son prix. Après une exécution partielle, un gap ou une annulation, contrôler le stock, les ordres encore actifs et les opérations enregistrées.
