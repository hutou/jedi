# Allers-retours et flux du trade

Un cours qui monte ne fait entrer de l'argent que si une vente a lieu. Un cours qui baisse ne fait sortir de l'argent que si un achat a lieu. Pour lire un trade, commencer par le prix d'un titre, le nombre de titres détenus et les achats ou ventes exécutés.

Ce chapitre utilise **Exemple A, un titre fictif**, avec 100 titres achetés à 10 €. C'est un exemple de type I, distinct du barème d'EXA01 dans la partie I. Les prix sont choisis pour expliquer les calculs ; ils ne décrivent aucun marché réel.

## Vendre puis racheter, ou acheter puis revendre

Un aller-retour comporte deux transactions opposées sur la même quantité. Après les deux transactions, le stock retrouve son niveau précédent.

| Aller-retour achevé | Argent reçu | Argent dépensé | Écart hors frais |
|---|---:|---:|---:|
| Vendre 20 à 12 €, puis racheter 20 à 10 € | 240 € | 200 € | +40 € |
| Acheter 20 à 8 €, puis revendre 20 à 10 € | 200 € | 160 € | +40 € |

Ces écarts sont connus lorsque **les deux transactions ont eu lieu**. Après la vente seule, le rachat reste à faire ; après l'achat seul, la revente reste à faire. Une proposition d'ordre n'est pas un aller-retour achevé.

## Voir le parcours dans Jedi

`tools play` déroule des mouvements choisis dans une simulation en mémoire. Les chapitres 13 et 14 expliqueront le barème. Lire d'abord les opérations obtenues :

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01" 1 -1 -1 1
~~~

L'avertissement sur une future vente de très petite quantité concerne la poursuite de la hausse au-delà de cet aller-retour. Il est expliqué dans le [chapitre 12](12_positions_echelons_et_paliers.md#observer-les-deux-sauts-avec-play).

`1` demande un mouvement haussier ; `-1` un mouvement baissier. `--` permet de transmettre les nombres négatifs. Les antislashs prolongent la commande, y compris à l'intérieur des guillemets.

| Opération | Flux hors frais | Stock détenu | Investissement courant |
|---|---:|---:|---:|
| Achat initial : 100 à 10 € | −1 000 € | 100 | 1 000 € |
| Vente : 20 à 12 € | +240 € | 80 | 760 € |
| Rachat : 20 à 10 € | −200 € | 100 | 960 € |
| Achat : 20 à 8 € | −160 € | 120 | 1 120 € |
| Revente : 20 à 10 € | +200 € | 100 | 920 € |

Une vente réduit le stock et rend de l'argent disponible ; un achat augmente le stock et consomme de l'argent. `play` exécute les ordres calculés aux prix de son scénario et n'enregistre aucune opération dans votre portefeuille.

## Comprendre l'investissement et son maximum

L'**investissement courant** est le total des achats moins le total des ventes, hors frais. Il vaut 920 € à la fin : 1 360 € d'achats diminués de 440 € de ventes.

L'**investissement maximal historique** est le plus grand investissement courant déjà atteint. Il vaut 1 120 €, après l'achat à 8 €. La revente suivante ne fait pas disparaître ce maximum.

Ces nombres ne sont pas le solde du compte du courtier : ils suivent uniquement les flux du trade. Les futurs achats peuvent demander une réserve supplémentaire, étudiée au chapitre 18.

## Ajouter la valeur des titres restants

Les deux allers-retours ont rapporté 80 € hors frais et il reste 100 titres. Le résultat dépend aussi de leur valeur au cours retenu :

~~~text
valeur du stock = quantité détenue × cours retenu
résultat brut = valeur du stock − investissement courant
~~~

| Évaluation du même stock final | Valeur | Investissement | Résultat brut |
|---|---:|---:|---:|
| 100 titres à 10 € | 1 000 € | 920 € | +80 € |
| 100 titres à 9 € | 900 € | 920 € | −20 € |

Les transactions bénéficiaires ne mettent donc pas les titres restants à l'abri d'une baisse. Le cours retenu évalue le stock ; il ne garantit pas le prix auquel tous les titres pourraient être vendus.

## Tenir les frais à part

Jedi suit les frais séparément. Avec 0,35 %, sans minimum ni taxe sur ce titre fictif :

| Opération | Frais |
|---|---:|
| Achat initial | 3,50 € |
| Vente à 12 € | 0,84 € |
| Rachat à 10 € | 0,70 € |
| Achat à 8 € | 0,56 € |
| Revente à 10 € | 0,70 € |
| Total | **6,30 €** |

Au cours final de 10 €, le résultat après frais vaut **73,70 €**. L'investissement courant et son maximum restent exprimés hors frais. `trade results` distingue le résultat brut et les frais. Dans `play`, la sortie financière `f` est brute. Pour lire aussi les frais dans les opérations, ajouter la colonne `16` au sélecteur : `-c o0,6-14,16-17`.

## Lorsque le retour ne se produit pas

Après la vente à 12 €, le cours peut continuer à monter sans permettre le rachat à 10 €. Le trade détient moins de titres pour la hausse suivante. Après l'achat à 8 €, il peut continuer à baisser sans permettre la revente : davantage de titres restent exposés.

Juste après cet achat, le stock vaut 120 et l'investissement 1 120 €. À un cours de 6 €, sa valeur serait 720 €, soit un résultat brut de −400 €. Le premier aller-retour bénéficiaire ne compense pas cette baisse.

Une variation de cours seule ne modifie ni le stock ni les flux enregistrés. Le [chapitre 12](12_positions_echelons_et_paliers.md) ajoute la position mécanique utilisée pour calculer la suite.
