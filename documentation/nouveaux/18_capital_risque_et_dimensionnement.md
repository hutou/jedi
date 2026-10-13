# Comprendre le capital, le risque et le dimensionnement

Un projet doit répondre à deux questions : quelle quantité acheter au départ, et combien de capital garder disponible pour les achats suivants ? La gestion du capital donne un cadre de risque au dimensionnement. `tools candidate` vérifie aussi l'opérabilité et le financement, comme au [chapitre 06](06_tools_candidate.md).

Nos montants décrivent des simulations. Le risque théorique ne garantit pas la perte maximale effectivement obtenue : frais, arrondis ou exécution défavorable peuvent l'augmenter.

Après un split, les gains courants et les quantités des stops utilisent le **stock converti**, même si aucune transaction nouvelle n'a encore été enregistrée. Avec reset, le trajet de protection part de la nouvelle position mécanique. Ces adaptations ne remettent pas le résultat financier à zéro : les achats, ventes et frais passés restent conservés. Avec merge, les propositions automatiques attendent la transaction manuelle, selon le [chapitre 09](09_adapter_ou_terminer_un_trade.md).

## Donner un sens à K, r, o et n

| Paramètre | Question pratique | Effet |
|---|---|---|
| `K` | Quel capital est affecté au trading ? | Base monétaire des calculs. |
| `r` | Quelle fraction accepte-t-on de risquer par trade ? | Risque monétaire `R = K × r`. |
| `n` | À quelle distance du barème examine-t-on la baisse ? | Prix à `n` échelons et distance de dimensionnement. |
| `o` | Quel gain projeté faut-il dépasser avant de le protéger ? | Objectif monétaire `O = o × R`. |

Avec `K=20 000 €`, `r=2,5 %`, `n=2` et `o=1`, le risque et l'objectif valent chacun 500 €. `o=2` porterait l'objectif à 1 000 € sans changer la quantité initiale.

Avec sa configuration d'origine, Jedi accepte `r` entre 0,5 % et 5 %, `n` entre 1 et 5, et `o` entre 0,5 et 5. Ces bornes sont configurables. Nos valeurs sont des choix d'illustration à examiner, pas des réglages conseillés pour tout portefeuille.

Une définition `money` exige les trois champs `r`, `o` et `n` : aucun n'est complété implicitement. Sans `money`, le barème fonctionne sans les protections décrites ici.

## Utiliser le bon capital

Pour un trade réel, le capital vient de `trading.capital`. Pour **`tools play`**, il vient de **`simulation.capital`**. `candidate --capital=20000` impose le capital de cette évaluation sans modifier la configuration.

Avant les exemples de protection, utiliser [l'espace d'essai du chapitre 02](02_installer_et_preparer_jedi.md#préparer-un-espace-dessai-séparé) et vérifier dans son fichier de configuration :

~~~yaml
simulation:
  capital: 20000
~~~

Les frais restent à 0,35 %, sans minimum. Le capital de 5 000 € d'Exa_01 dans la partie I est un autre exemple. Modifier seulement `trading.capital` ne modifie pas le capital de `play`.

## Dimensionner une ouverture

Notre type I entre à 10 €. Deux échelons de baisse conduisent à 8 €, puis 6 €. La distance depuis l'entrée est de 40 %.

Le montant issu du risque vaut `R/d`, avec `d` exprimé en fraction : 500 € ÷ 0,40 = **1 250 €**, soit **125 titres** à 10 €.

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --money=r:2.5%,o:1,n:2 --capital=20000 --extended
~~~

L'ISIN est celui du titre fictif de démonstration. Le prix est fourni par la commande ; aucune cotation téléchargée n'intervient.

| Résultat utile | Valeur |
|---|---:|
| Prix théorique à deux échelons | 6,00 € |
| Distance de risque | 40 % |
| Risque monétaire | 500,00 € |
| Quantité initiale | 125 |
| Montant d'ouverture hors frais | 1 250,00 € |
| Quantité minimale opérable annoncée | 82 |
| Besoin maximal du candidat hors frais | 1 855,60 € |
| Marge après candidat hors frais | 18 144,40 € |

Jedi compare les contraintes de risque, de capital et de minimum opérable. Le risque limite ici la quantité à 125. La quantité maximale selon le capital sur le trajet de risque est 1 492 ; ce nombre n'autorise pas à ignorer le plafond de risque.

Le prix théorique de 6 € sert au dimensionnement. Ce n'est pas une instruction permanente de vente à 6 € : le StopLoss évolue avec les opérations.

## Garder une réserve pour les achats futurs

L'ouverture immobilise 1 250 €, mais le trajet baissier sans protection demande d'autres achats :

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=125,c0=10,tick=0.01" -3
~~~

| État | Stock | Investissement net hors frais |
|---|---:|---:|
| Ouverture à 10 € | 125 | 1 250,00 € |
| Achat de 25 à 8 € | 150 | 1 450,00 € |
| Achat de 38 à 6 € | 188 | 1 678,00 € |
| Achat de 37 à 4,80 € | 225 | 1 855,60 € |

`candidate` retient ici trois échelons et une réserve future de **605,60 €** en plus de l'ouverture. Cet horizon vient du contrôle opérationnel et peut dépasser `n`. La projection examine les achats entiers du barème ; elle ne suppose pas que le StopLoss les interrompra.

Les réserves des autres trades ouverts sont déduites du capital libre. Les frais sont exclus de cette projection. Prévoir aussi les frais et examiner les besoins au-delà de l'horizon affiché.

Une ouverture imposée de 1 250 € avec seulement 1 700 € de capital reste opérable, mais donne une marge de **−155,60 €** :

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --amount=1250 --capital=1700 --extended
~~~

Pouvoir payer l'achat initial ne suffit donc pas à financer le scénario.

## Choisir ses paramètres

Commencer par le capital affecté et le montant de perte accepté pour le projet ; en déduire `r`. Examiner ensuite les prix correspondant à `n` avec le barème choisi : deux échelons ne représentent pas toujours 40 %.

Ces comparaisons changent un seul paramètre à la fois. Chaque commande est complète :

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --money=r:1%,o:1,n:2 --capital=20000
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --money=r:5%,o:1,n:2 --capital=20000
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --money=r:2.5%,o:1,n:1 --capital=20000
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --money=r:2.5%,o:1,n:3 --capital=20000
jedidemo tools candidate FR4487601001 --price=10 \
  --scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1 \
  --money=r:2.5%,o:2,n:2 --capital=20000
~~~

| Réglage | Risque R | Prix à n échelons | Quantité retenue | Objectif O |
|---|---:|---:|---:|---:|
| `r:1%,o:1,n:2` | 200 € | 6,00 € | 0 : refus | 200 € |
| `r:2.5%,o:1,n:2` | 500 € | 6,00 € | 125 | 500 € |
| `r:5%,o:1,n:2` | 1 000 € | 6,00 € | 250 | 1 000 € |
| `r:2.5%,o:1,n:1` | 500 € | 8,00 € | 250 | 500 € |
| `r:2.5%,o:1,n:3` | 500 € | 4,80 € | 96 | 500 € |
| `r:2.5%,o:2,n:2` | 500 € | 6,00 € | 125 | 1 000 € |

À `r:1%`, la contrainte de risque ne permet pas d'atteindre le minimum opérable annoncé. Jedi refuse l'ouverture et retient zéro titre. Augmenter `r` pour obtenir « OUI » augmente aussi le risque monétaire : ce doit rester une décision de risque.

Augmenter `n` éloigne ici le prix de risque et réduit la quantité initiale. Réduire `n` augmente la quantité et les besoins de financement. Choisir `n` en examinant les prix, les mouvements habituels du titre et la réserve nécessaire.

Vérifier ensuite les ordres entiers. Le minimum annoncé n'assure pas que toute quantité supérieure donne de grands ordres : les arrondis peuvent faire varier les petits écarts irrégulièrement. Avec `q0=100`, trois hausses vendent 20, 1 et 16 ; avec `q0=125`, elles vendent 25, 2 et 19. Le contrôle d'ouverture actuel ne revalide pas chaque ordre de la quantité finale ; compléter sa lecture avec `play` et les diagnostics de suivi.

## Comprendre le contrôle de perte

Pendant le trade, Jedi projette le résultat après `n` échelons de baisse, avec les achats et ventes demandés par le barème. Si ce résultat est inférieur à `−R`, il calcule une protection `CL` pour viser cette perte monétaire.

~~~console
jedidemo tools play -c o0,6-14,17rf -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=125,c0=10,tick=0.01,money=r:2.5%,o:1,n:2,loss=fallback" -2
~~~

À l'ouverture, un StopLoss de 125 à 6 € coexiste avec l'achat ordinaire à 8 €. Après l'achat de 25 à 8 €, le stock vaut 150 et l'investissement 1 450 €. La protection est recalculée à `(1450−500)/150`, soit environ 6,333333 €, arrondi à **6,33 €**.

L'achat ordinaire à 6 € est supprimé, car sous la protection. La simulation vend 150 à 6,33 € : **500,50 € de perte brute** et **8,40 € de frais**, soit **508,90 € de perte après frais**.

`loss=fallback`, défaut de `play`, suit d'abord l'ordre baissier ordinaire disponible, puis le StopLoss. `loss=active` donnerait priorité au StopLoss dès la première baisse : la chronologie simulée diffère.

Un gap sous la protection peut aggraver la perte. Si le cours connu a déjà dépassé la protection ou la perte acceptée, Jedi signale le problème ; il ne garantit pas de rattraper une vente non exécutée.

## Comprendre la protection des gains

La protection `GP` commence quand le **gain projeté après `n` baisses** dépasse strictement `O`. Un gain actuel de 500 € ne suffit pas nécessairement pour `o:1` et `R=500 €`.

Pour observer `o`, simuler 25 allers-retours de 100 titres entre 10 et 12 €. Ce scénario volontairement répétitif montre le seuil ; il n'annonce pas 25 occasions réelles de gain :

~~~console
jedidemo tools play -c o0,6-14,17r -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01,money=r:2.5%,o:1,n:2" "25x1,-1"
jedidemo tools play -c o0,6-14,17r -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,\
q0=100,c0=10,tick=0.01,money=r:2.5%,o:2,n:2" "25x1,-1"
~~~

Les deux parcours finissent avec 100 titres à 10 € et 1 000 € de gain brut. Avec `o:1`, des StopLoss de protection des gains apparaissent pendant le parcours. Avec `o:2`, aucun n'apparaît : le gain projeté n'a pas dépassé 1 000 €.

Une fois `GP` établie, Jedi conserve le gain monétaire protégé ou le relève si la projection s'améliore. Son prix est recalculé quand le stock change. Cette protection est calculée hors frais et reste soumise à l'exécution réelle. Un `o` plus grand retarde ici son activation ; il ne promet pas un gain plus grand et ne fixe pas un prix de vente immédiate.

Après ces vérifications, `tools backtest` permet d'observer le barème sur des cotations historiques. Ses hypothèses sont expliquées au [chapitre 22](22_simuler_avec_tools_backtest.md).
