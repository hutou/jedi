# Chercher un barème avec tools score

## Une recherche pour un titre déjà choisi

`score` simule plusieurs barèmes sur l'historique d'un titre et classe ceux qu'il a évalués. Le titre vient du choix de l'utilisateur, de `profile` ou d'une sélection externe.

Le parcours courant utilise une recherche **adaptative**, un classement **raw** et un affichage **compact**. « Raw » désigne ici les résultats directement triés selon les trois mesures affichées. La recherche adaptative explore des configurations, puis approfondit les zones les plus intéressantes selon le critère de tri choisi.

## Choisir les cotations

Depuis un fichier individuel :

~~~console
jedidemo tools score cotations_EXA.txt --sort=fitness --budget=40
~~~

Depuis une base de marché existante :

~~~console
jedidemo tools score --database=demo --security=EXA --sort=fitness --budget=40
~~~

Le nom du fichier est un argument positionnel. En base, `--database` désigne la source et `--security` le ticker ou l'ISIN. `--universe` permet de choisir un autre univers que celui de la configuration.

## Ce que signifie « fichier préparé »

Un fichier préparé est un historique acquis auprès d'une source identifiée, mis dans le format lu par Jedi et contrôlé avant utilisation. Pour un titre, la première ligne recommandée contient **ISIN ; ticker ; nom**. Les suivantes contiennent **ISIN ; date ; ouverture ; plus haut ; plus bas ; clôture ; volume**.

Extrait valide du fichier fictif livré `cotations_EXA.txt` :

~~~text
FR4487601001;EXA;Exemple A
FR4487601001;20230630;10.0000;10.1800;9.8200;10.0000;60000
FR4487601001;20230703;10.1075;10.2895;9.9173;10.0990;61000
~~~

Ces deux cotations illustrent le format ; elles ne suffisent pas à une étude représentative. Le fichier livré contient 851 séances fictives, du 30 juin 2023 au 2 octobre 2026.

Chaque ligne doit concerner le même ISIN. Les prix emploient le point décimal ; les dates ci-dessus sont en année, mois, jour. Le fichier est ordonné chronologiquement pour faciliter les contrôles. Éviter les doublons, vérifier les séances manquantes et identifier les éventuelles corrections de cours.

Les exports d'un fournisseur peuvent demander une conversion avant lecture : conserver les colonnes nécessaires, compléter l'ISIN et adapter les dates. Les commandes `market` ne téléchargent pas ces fichiers. Le chapitre 10 distingue le fichier individuel du fichier de plusieurs titres destiné à l'import.

## Pourquoi 750 séances après un profil sur 252 ?

`profile` examine le comportement récent du titre, principalement sur 252 séances, soit environ un an. `score` évalue le parcours de barèmes sur **750 séances par défaut**, soit environ trois ans. Cette période plus longue expose la mécanique à davantage de mouvements et de conditions historiques.

Ces réglages répondent à des questions différentes : « comment se comporte le titre récemment ? » et « comment ces barèmes ont-ils fonctionné sur l'historique choisi ? ». Ils ne constituent pas une démonstration que ces durées seraient toujours les meilleures.

Avec le fichier de démonstration, la commande précédente indique :

~~~text
Historique : 2023-11-20 → 2026-10-02 (750 séances)
Montant demandé à l'ouverture : 1500.00 €
Recherche adaptive : 40 backtests, 11793 candidats disponibles (budget : 40)
Recherche partielle : le classement porte sur les barèmes évalués.
Classement : brut transparent (raw)
~~~

Si le fichier contient moins de 750 séances, le rapport indique la période réellement disponible. Le contrôle de trois années propre à `profile` n'est pas une règle supplémentaire de `score`.

## Budget et recherche

Sans `--budget`, la recherche adaptative dispose d'un budget de **500 backtests de recherche**. Dans ce chapitre, 40 donne une démonstration courte. Ce budget compte les barèmes effectivement simulés, pas les lignes affichées.

La recherche ne teste pas nécessairement tous les candidats disponibles. Sa conclusion porte sur les configurations évaluées ; la première ligne n'est pas une preuve d'optimum global.

Un pourcentage d'avancement est affiché pendant les calculs. Le temps nécessaire dépend du budget, de la longueur de l'historique et des barèmes. Une recherche exhaustive `--search=grid` existe pour les usages détaillés ; elle peut être beaucoup plus longue.

## Lire les trois colonnes compactes

Les résultats compacts `raw` sont limités aux **20 premiers barèmes**, ou moins si la recherche en a évalué moins. Voici les trois premières lignes réellement obtenues avec le fichier fictif et le budget de 40 :

~~~text
 Fitness  Op/mois  Inv.max  Constructeur typé
   0.433    0.644    1.000  I: kc:1.23,1.14,0.88,0.76, ki:0%, kb:1, kd:0.2
   0.416    0.532    1.000  I: kc:2.01,1.75,1.52,1.32,1.15,0.85,0.72,0.61,0.52,0.44, ki:0%, kb:1, kd:0.0
   0.414    1.960    1.050  I: kc:1.22,1.16,1.1,0.95,0.9,0.86, ki:0%, kb:1, kd:0.0
~~~

| Colonne | Lecture |
|---|---|
| Fitness | Gain brut final divisé par le montant du premier achat. `0.433` signifie environ 43,3 % de ce premier achat sur toute la période. |
| Op/mois | Nombre de toutes les opérations, ouvertures comprises, ramené à 21 séances à partir de la première opération. |
| Inv.max | Investissement maximal divisé par le premier achat, hors frais. `1.050` signifie un pic de 1,05 fois ce premier achat. |
| Constructeur typé | Type I ou II, puis définition permettant de recréer le barème. |

La fitness n'est ni un taux annuel ni un rendement net. Le gain brut inclut les titres encore détenus, valorisés à la dernière clôture. Une hausse du titre peut donc contribuer au résultat sans provenir d'allers-retours.

L'investissement maximal est le pic des achats moins les ventes. Il peut dépasser le premier achat lorsque la mécanique demande des achats supplémentaires. Les frais doivent être examinés dans la lecture économique ou dans un backtest.

## Choisir le tri

| Option | Premier critère | Départage |
|---|---|---|
| `--sort=fitness`, défaut | Fitness décroissante | Activité décroissante, puis investissement maximal croissant |
| `--sort=activity` | Activité décroissante | Fitness décroissante, puis investissement maximal croissant |
| `--sort=investment` | Investissement maximal croissant | Activité décroissante, puis fitness décroissante |

Les tris comparent les mesures arrondies à trois décimales. Les anciens noms numériques `1`, `2`, `3` restent acceptés ; les exemples utilisent les noms explicites.

En recherche adaptative, le critère oriente aussi le raffinement. Changer de tri peut donc modifier les barèmes évalués, en plus de changer leur ordre. Pour comparer le parcours de barèmes fixes, utiliser leurs définitions dans `backtest`.

Une activité élevée augmente les interventions et peut donner davantage de frais. Une faible utilisation de capital et une forte fitness ne suffisent pas à vérifier l'opérabilité du projet réel.

## Examiner la lecture économique

~~~console
jedidemo tools score cotations_EXA.txt --sort=fitness --budget=40 --display=study
~~~

Cet affichage conserve le principe du classement et apporte le gain net, le résultat rapporté à l'investissement maximal, les frais et les opérations. Dans la première ligne de notre exemple, la fitness brute de 0,433 devient une fitness nette de 0,421 ; les frais affichés sont de 19 €.

Les colonnes `Rnet%` et `Rann%` rapportent le résultat net à l'investissement maximal. `Op/an` compte les opérations de barème hors ouvertures sur une base annuelle ; il ne remplace pas exactement `Op/mois`. Les montants arrondis de cet affichage servent à une lecture d'ensemble.

Les options `--ranking=jedi`, `--ranking=both` et `--display=technical` restent disponibles pour l'examen expert. Leurs détails figurent dans l'[annexe 01](fr_annex01.md#tools-score). Le parcours courant commence par `raw`.

## Examiner une autre période

~~~console
jedidemo tools score cotations_EXA.txt --sort=fitness --select=l252 --budget=40
~~~

Cette commande utilise les 252 dernières séances. Dans notre exemple, la première ligne sur 750 séances a une fitness de 0,433 ; la première ligne sur 252 séances a une fitness de 0,126 et un autre constructeur.

Ces deux gains couvrent des durées différentes et peuvent concerner des barèmes différents. Leur simple comparaison ne démontre pas la supériorité d'une fenêtre. Fixer un barème, puis le simuler sur les périodes voulues, permet d'examiner son comportement.

Pour arrêter la recherche à une date donnée :

~~~console
jedidemo tools score cotations_EXA.txt --date=le:2025-12-31 \
  --select=l750 --sort=fitness --budget=40
~~~

Le filtre de date est appliqué avant la sélection de lignes. Les codes sont `ge` pour « à partir de », `gt` pour « après », `le` pour « jusqu'à inclus » et `lt` pour « avant ».

## Transmettre un barème à candidate

Le préfixe `I:` ou `II:` indique le type dans le rapport ; il ne fait pas partie de la valeur à transmettre. Reprendre le texte qui suit ce préfixe :

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale="kc:1.23,1.14,0.88,0.76,ki:0%,kb:1,kd:0.2" \
  --amount=1000 --capital=5000
~~~

Cette définition est celle de la première ligne de démonstration. Le prix de 10 € et les montants sont fictifs. Le rapport `candidate` vérifie le projet actuel et affiche la définition opérationnelle du barème ; aucun achat n'est réalisé.

## Vérifier un prix avec calc

Pour le barème de type I repris ci-dessus, Jedi peut vérifier le prix du premier échelon à la hausse :

~~~console
jedidemo tools calc price \
  scale="kc:1.23,1.14,0.88,0.76,ki:0%,kb:1,kd:0.2" \
  position=0:0:1 c0=10 tick=0.01 dir=up
~~~

La sortie obtenue commence par :

~~~text
price = round_up(cpe) = 11.4
  cpe = 11.4
~~~

La position cible est le premier échelon haussier, le prix de référence est de 10 € et le pas de cotation de 0,01 €. Ce calcul vérifie un prix du barème ; il ne simule pas tout le trade. Pour un barème de type II ou un enchaînement d'opérations, utiliser `tools play`.

## Retenir une solution compréhensible

Lire d'abord les dates, le nombre de barèmes évalués et les mesures. Examiner ensuite quelques configurations, leur activité, les frais et les besoins de capital. Une fitness proche peut accompagner des rythmes très différents.

La simulation utilise le moteur de `backtest`, une ouverture par montant fixe, l'exécution `conservative` et des ordres actifs à la séance suivante après l'ouverture. Le montant demandé vient de la configuration de simulation ; il est affiché dans le rapport. Les exemples utilisent 1 500 € par ouverture avec la configuration par défaut de Jedi.

Conserver la définition retenue et les paramètres de l'étude. Vérifier son parcours sur une autre période puis évaluer le candidat au prix actuel. Modifier les dates ou les réglages après lecture des gains doit être considéré comme un nouvel essai.
