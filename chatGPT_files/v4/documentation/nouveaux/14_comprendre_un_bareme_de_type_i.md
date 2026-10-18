# Comprendre un barème de type I

Le type I associe chaque échelon à un coefficient de cours `kc` et à un coefficient de stock `ks`. Dans un même palier, ces coefficients donnent des niveaux connus. Un saut change les références auxquelles ils s'appliquent.

Nous reprenons 100 titres à 10 €, un pas de 0,01 € et le barème :

~~~text
kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1
~~~

## Calculer les premiers niveaux

Dans le premier palier, multiplier les références par les coefficients :

| Position | Cours théorique | Stock théorique |
|---|---:|---:|
| `0:0:0` | 10 € × 1 = 10 € | 100 × 1 = 100 |
| `0:0:+1` | 10 € × 1,20 = 12 € | 100 × 0,80 = 80 |
| `0:0:-1` | 10 € × 0,80 = 8 € | 100 × 1,20 = 120 |

Depuis 100 titres, la hausse propose de vendre 20 et la baisse d'acheter 20. Revenir à zéro, avant tout saut, retrouve le prix de 10 € et le stock théorique de 100.

## Passer au palier suivant

À la borne `+2`, le nouveau prix de référence vaut 10 € × 1,40 = 14 €. La référence théorique de capital est multipliée par `1+ki`, soit 1,10. Elle passe de 1 000 à 1 100 €.

Le stock théorique à l'origine du nouveau palier vaut 1 100 € ÷ 14 €, soit **78,571429 titres** environ. Il décrit une cible de calcul, pas un stock fractionnaire détenu.

À la borne `−2` atteinte directement depuis le premier palier, le prix de référence vaut 6 € et la référence de capital 900 €, avec `kb:1`. Le stock théorique devient 900 € ÷ 6 € = **150 titres**.

Ces valeurs ne sont ni l'investissement courant, ni le solde du compte, ni le gain du trade.

## Vérifier les multiplicateurs avec calc

Jedi nomme `kcp` le multiplicateur de cours du palier, `kcb` celui de sa référence de capital et `ksp` celui du stock. Leur relation est `ksp = kcb / kcp`.

Pour le premier saut haussier :

~~~console
jedidemo tools calc cpe \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  position=1:0:0 c0=10
jedidemo tools calc spe \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  position=1:0:0 q0=100
~~~

On retrouve `cpe=14` et `spe≈78.571429`, respectivement cours et stock théoriques.

Après un saut dans chaque sens, la référence de cours est multipliée par 1,40 × 0,60 = 0,84. La référence de capital est multipliée par 1,10 × 0,90 = 0,99 :

~~~console
jedidemo tools calc kcb \
  scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  position=1:1:0
~~~

La valeur obtenue est 0,99. Ces deux sauts ne rétablissent pas les références du premier palier.

## Suivre les transactions entières avec play

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 2 -2
~~~

| Opération | Position | Quantité | Prix | Stock après opération |
|---|---|---:|---:|---:|
| Buy Market | `0:0:0` | 100 | 10 € | 100 |
| Sell Limit | `0:0:+1` | 20 | 12 € | 80 |
| Sell Limit | `1:0:0` | 1 | 14 € | 79 |
| Buy Limit | `1:0:-1` | 15 | 11,20 € | 94 |
| Buy Limit | `1:1:0` | 24 | 8,40 € | 118 |

La cible de 78,571429 est arrondie à 79, puis comparée aux 80 titres détenus : la vente porte sur un titre. La dernière baisse part du palier supérieur ; elle n'est pas une baisse directe depuis l'ouverture.

Le contrôle structurel optimisé n'assure donc pas des ordres assez grands après arrondi. L'opérabilité et les frais restent à examiner.

## Laisser Jedi répartir les variations de stock

Le constructeur compact remplace la liste `ks` par `kd` :

~~~console
jedidemo scale create --name=B1_example_auto_v01 \
  --comment="Construction pédagogique" \
  --builder="kc:1.4,1.2,0.8,0.6,ki:10%,kb:1,kd:0"
jedidemo scale show B1_example_auto_v01
~~~

Créer ce nom une seule fois dans la base d'essai. Avec `kd:0`, la répartition est régulière entre les intervalles. Jedi produit **`ks:0.89,1.25`** : les stocks cibles intérieurs sont 89 et 125 pour `q0=100`.

C'est un autre barème que `ks:0.8,1.2`. Un `kd` positif donne davantage de poids aux intervalles tardifs ; un `kd` négatif aux premiers. Consulter le barème développé pour examiner les quantités.

## Situer le barème historique Qdt

`Qdt` est conservé pour la compatibilité. Sa définition canonique est :

~~~text
kc:1.61,1.38,1.23,1.14,0.88,0.76,0.64,0.52,0.4,
ks:0.4,0.68,0.87,1.9,2.9,4.1,5.5,ki:14%,kb:0
~~~

Il utilise `kb:0` : le saut baissier emploie l'inverse de `1+ki`. Ses bornes sont `+4` et `−5`. Il échoue au contrôle optimisé et peut demander un achat dans une hausse ou une vente dans une baisse.

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.61,1.38,1.23,1.14,0.88,0.76,0.64,0.52,0.4,\
ks:0.4,0.68,0.87,1.9,2.9,4.1,5.5,ki:14%,kb:0,\
q0=100,c0=10,tick=0.01" 4
~~~

Juste avant le saut supérieur, il reste 40 titres. Le saut vise 71 titres à 16,10 € : **achat Stop de 31 titres**. Sur un trajet baissier distinct, le saut inférieur demande une vente Stop de 331 titres, de 550 vers 219 à 4 €.

Ces Stops font fonctionner le barème ; ils diffèrent des StopLoss de protection. Le [chapitre 17](17_de_l_etat_du_trade_aux_ordres.md) explique leur mode. Le [chapitre 15](15_comprendre_un_bareme_de_type_ii.md) présente d'abord le type II.
