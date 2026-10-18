# Comprendre un barème de type II

En fonctionnement ordinaire, le type II calcule le prochain prix en appliquant un taux `vr` au **prix de la dernière opération exécutée**, adapté à un split si nécessaire. Il conserve les positions et les coefficients de stock, sans liste de coefficients de cours `kc`.

**Après un `reinit=reset`, le prix de référence fourni à reset remplace immédiatement celui de la dernière opération pour les premiers ordres.** Si le reset accompagne un split, ce prix est déjà exprimé après le split. Les opérations suivantes reprennent ensuite leur prix réellement exécuté comme base. Avec `merge`, Jedi attend d'abord la transaction manuelle qui établit la nouvelle référence. Les [chapitres 09](09_adapter_ou_terminer_un_trade.md) et [16](16_continuite_entre_parametrages.md) présentent ces cas.

Notre exemple fictif utilise `vr:20%` pour rendre les différences lisibles, avec 100 titres à 10 € et un pas de 0,01 € :

~~~text
vr:20%,ks:0.8,1.2,ki:10%,kb:1
~~~

## Calculer le prochain prix

Depuis une exécution à 10 €, le prochain prix théorique vaut 12 € à la hausse et 8 € à la baisse. Après une exécution à 12 €, une baisse vise 12 € × 0,80 = **9,60 €**.

Une hausse de 20 % puis une baisse de 20 % ne revient pas à 10 €. Les pourcentages s'appliquent à des prix différents. Une baisse de 20 % puis une hausse de 20 % donne également 9,60 € depuis 10 €.

Le cours courant du marché situe les ordres ; il ne remplace pas le dernier prix exécuté dans cette formule.

## Rejouer les deux allers-retours

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=vr:20%,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 1 -1 -1 1
~~~

| Opération | Position | Prix au pas | Stock |
|---|---|---:|---:|
| Achat initial | `0:0:0` | 10 € | 100 |
| Vente de 20 | `0:0:+1` | 12 € | 80 |
| Rachat de 20 | `0:0:0` | 9,60 € | 100 |
| Achat de 20 | `0:0:-1` | 7,68 € | 120 |
| Vente de 20 | `0:0:0` | 9,22 € | 100 |

Le dernier cours théorique est 7,68 € × 1,20 = 9,216 €. Pour cette vente Limit, il est arrondi vers le haut à 9,22 €. Le calcul suivant repartira du prix exécuté de 9,22 €.

Les achats totalisent 1 345,60 €, les ventes 424,40 € et l'investissement courant 921,20 €. Les 100 titres à 9,22 € valent 922 € : résultat brut **0,80 €**. Les deux allers-retours ont pourtant apporté 78,80 € de trésorerie ; la baisse de valeur du stock compte aussi.

Comparer au type I illustre la mécanique. Les mêmes directions produisent d'autres prix ; ce n'est pas un classement historique de rentabilité.

## Comprendre le recalage au saut

Les bornes restent `+2` et `−2`. Au saut, Jedi recale la référence de cours du nouveau palier sur le prix du parcours. Pour l'ordre, il utilise le cours théorique ; pour l'opération enregistrée, le prix réellement exécuté.

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=vr:20%,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 2 -2
~~~

| Opération | Position | Quantité | Prix | Stock |
|---|---|---:|---:|---:|
| Buy Market | `0:0:0` | 100 | 10 € | 100 |
| Sell Limit | `0:0:+1` | 20 | 12 € | 80 |
| Sell Limit | `1:0:0` | 4 | 14,40 € | 76 |
| Buy Limit | `1:0:-1` | 16 | 11,52 € | 92 |
| Buy Limit | `1:1:0` | 15 | 9,21 € | 107 |

Au saut supérieur, la référence théorique de capital est 1 100 €. À 14,40 €, le stock théorique vaut environ 76,388889, arrondi à 76 pour l'ordre. Au dernier saut, 9,216 € est arrondi vers le bas à 9,21 € pour l'achat.

Les arrondis de prix influencent les calculs suivants. Un calcul sans arrondi et un parcours exécuté au pas peuvent donc se distinguer après plusieurs mouvements.

## Construire le stock avec np, nn et kd

~~~console
jedidemo scale create --name=B_vr_04 \
  --comment="Construction pédagogique" \
  --builder="vr:20%,np:2,nn:2,ki:10%,kb:1,kd:0"
jedidemo scale show B_vr_04
~~~

Créer ce nom une seule fois. `np:2,nn:2` fixe deux mouvements jusqu'à chaque borne, avec un échelon intérieur par côté. `kd:0` répartit régulièrement les variations. La définition développée contient **`ks:0.88,1.2`**.

Elle diffère donc de notre première liste `ks:0.8,1.2`. Lire `scale show` avant de comparer les ordres. Les autres valeurs de `kd` modifient la répartition comme en type I.

La forme historique utilisant `sr` et `mi` reste disponible pour compatibilité, avec ses propres règles. L'[annexe 01](fr_annex01.md#définitions-des-barèmes) décrit cette syntaxe ; le parcours courant utilise les formes ci-dessus.

## Lire les ordres même si le barème est optimisé

Le contrôle optimisé de type II s'appuie sur une suite de mouvements de même sens. Après des oscillations, le prix au saut peut différer de cette suite de référence.

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=vr:20%,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 1 -1 1 -1 1 1
~~~

Juste avant le dernier saut, il reste 80 titres après une vente à 11,06 €. Le saut vise un cours théorique de 13,272 € et un stock cible entier de 83. Jedi simule **un achat Stop de 3 titres à 13,28 €**, bien que le barème ait réussi le contrôle optimisé.

Ce qualificatif ne remplace pas la lecture des modes et quantités. Le [chapitre 16](16_continuite_entre_parametrages.md) examine la reprise du trade dans un nouveau paramétrage.
