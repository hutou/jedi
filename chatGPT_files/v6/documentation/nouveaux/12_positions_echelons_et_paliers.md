# Positions, échelons et paliers

Le stock indique combien de titres sont détenus. La **position mécanique** indique où le trade se trouve dans son barème. Elle ne donne ni une quantité ni un résultat en euros.

## Lire les trois nombres

Une position s'écrit `x:y:e` :

| Nombre | Lecture |
|---|---|
| `x` | Nombre de sauts vers un palier supérieur depuis le début du paramétrage actif. |
| `y` | Nombre de sauts vers un palier inférieur depuis le début de ce paramétrage. |
| `e` | Échelon courant dans le palier atteint. |

Les compteurs `x` et `y` sont positifs ou nuls. L'échelon `e` peut être positif, négatif ou nul. `1:0:+1` signifie un saut haussier, aucun saut baissier et l'échelon `+1`.

Un **échelon** est une étape locale du barème. Un **palier** est un niveau de référence à partir duquel une nouvelle série d'échelons se déroule. Le premier achat place le trade à `0:0:0`.

Dans certaines sorties, un nombre précède la position : `1 0:0:+1`. Ce premier `1` est le rang du paramétrage. La position reste composée de trois nombres.

## Atteindre une borne et changer de palier

Le barème de type I du chapitre 11 a pour bornes `emax=+2` et `emin=-2`. Ses échelons intérieurs sont `−1`, `0` et `+1`.

| Position actuelle | Mouvement | Position suivante |
|---|---|---|
| `0:0:0` | Hausse | `0:0:+1` |
| `0:0:0` | Baisse | `0:0:-1` |
| `0:0:+1` | Hausse atteignant la borne haute | `1:0:0` |
| `0:0:-1` | Baisse atteignant la borne basse | `0:1:0` |

Quand une borne est atteinte, Jedi augmente le compteur correspondant et remet `e` à zéro. La position ne reste pas à `+2` ou `−2`. Un échelon zéro après un saut n'est pas un retour automatique au premier prix ou au premier stock.

## Observer les deux sauts avec play

Ce barème pédagogique génère au saut supérieur une vente d'un seul titre à 14 €. Jedi affiche un avertissement après l'achat initial, puis « Fonctionnement de Jedi dégradé » après la première vente : l'ordre haussier suivant ne porte que sur un titre. Ces messages signalent une quantité trop faible pour un fonctionnement satisfaisant ; la simulation se poursuit et permet d'observer les positions ci-dessous. Le [chapitre 06](06_tools_candidate.md#comprendre-lopérabilité) explique ce contrôle.

Deux hausses, puis deux baisses :

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 2 -2
~~~

| Moment | Position | Prix simulé | Stock |
|---|---|---:|---:|
| Achat initial | `0:0:0` | 10 € | 100 |
| Première hausse | `0:0:+1` | 12 € | 80 |
| Deuxième hausse, saut supérieur | `1:0:0` | 14 € | 79 |
| Première baisse depuis ce palier | `1:0:-1` | 11,20 € | 94 |
| Deuxième baisse, saut inférieur | `1:1:0` | 8,40 € | 118 |

À la fin, `x=1` et `y=1` : les compteurs ne s'annulent pas. Les prix et stocks viennent du barème ; les seules coordonnées ne suffiraient pas à les calculer.

## Position actuelle et position cible

Une **position cible** est celle qu'atteindrait une opération calculée. Depuis `0:0:+1`, la prochaine hausse viserait `1:0:0`, et la prochaine baisse `0:0:0`. Ce sont deux possibilités alternatives.

Placer, annuler ou laisser expirer un ordre chez le courtier ne change pas la position enregistrée. Jedi met à jour le parcours lorsque vous enregistrez l'exécution réelle. Le sens mécanique dépend du type et du mode de l'opération, comme l'explique le chapitre 17.

Quand le paramétrage actif a déjà servi, les ordres partent de sa dernière opération. Avant sa première opération, ils partent de la position inscrite dans le nouveau paramétrage.

## Reprendre l'échelon dans un nouveau paramétrage

Un changement ordinaire conserve `e` et remet `x` et `y` à zéro. Une dernière opération à `1:1:-1` est ainsi reprise par un paramétrage commençant à `0:0:-1`.

Le stock, les flux et la position historique restent conservés. Les effets des sauts sont reportés dans des coefficients cumulés, étudiés au chapitre 16. La remise à zéro des compteurs ne supprime pas leur effet sur les calculs.

Les réinitialisations `reset` et `merge` établissent une nouvelle origine `0:0:0`. Une synchronisation de type I reprend une position choisie. Le [chapitre 09](09_adapter_ou_terminer_un_trade.md) donne les commandes pratiques.

Le [chapitre 13](13_lire_la_structure_d_un_bareme.md) présente le barème associant cette position à un cours et à un stock cibles.
