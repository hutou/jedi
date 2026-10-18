# Exemple d'étude sur Euronext Growth

Les captures chiffrées de ce chapitre sont celles de l’étude de référence de l’édition 1.0. Avec le calcul du maximum d’investissement corrigé en v1.1, relancer les commandes pour obtenir les valeurs d’investissement, les rendements et les classements actualisés.

## Un parcours à reproduire, puis à adapter

Ce chapitre montre comment organiser une étude de titres d'Euronext Growth : présélection à fin 2024, recherche sur les données antérieures, puis vérification en 2025. Les fichiers livrés contiennent **trois titres fictifs** EXA, EXB et EXC ; ils ne sont pas un export d'Euronext Growth. Le nom du dataset sert à montrer l'organisation de l'étude.

Les sorties sont calculées sur ces données de démonstration. Elles n'indiquent ni le rendement du marché Growth, ni celui de titres réels. Cet exemple rédigé après 2025 est **rétrospectif** ; les dates des commandes encadrent les calculs sans transformer l'exercice en décision réellement prise en 2024.

## Préparer une base historique figée

Après l'installation des lanceurs au [chapitre 02](02_installer_et_preparer_jedi.md), copier les fichiers TXT de `examples/` dans `~/jedi-examples/`. Utiliser une base principale d'essai sans trade engagé et les réglages suivants dans sa configuration :

~~~yaml
fees:
  rate: 0.0035
  min: 0.0
simulation:
  capital: 20000
  risk_rate: 0.015
  distance: 0.2
~~~

`Growth_demo_2021_2025.txt` contient 3 909 lignes de cotations : 1 303 jours de semaine par titre, du 4 janvier 2021 au 31 décembre 2025. `labels_growth_demo.txt` fournit les identités. La composition reste fixe ; le calendrier simplifié inclut des jours fériés.

Créer une base distincte de Demo, une seule fois :

~~~console
jedidemo market init growthdemo
jedidemo market import growthdemo Euronext_Growth \
  Growth_demo_2021_2025.txt labels_growth_demo.txt
jedidemo market info growthdemo --dataset=Euronext_Growth
jedidemo market list growthdemo --dataset=Euronext_Growth --last-quote
~~~

Vérifier trois titres, 3 909 cotations et une dernière cotation au 31 décembre 2025 pour chacun. Ne pas prolonger cette base par un update de 2026 : elle constitue l'entrée figée de cette étude.

## Présélectionner avec les données de fin 2024

~~~console
jedidemo tools profile --database=growthdemo --dataset=Euronext_Growth \
  --date=le:2024-12-31 --rank-criteria=4 --include-rejected
~~~

Le calcul dispose de quatre années de profondeur et utilise les 252 dernières séances jusqu'à cette date pour ses critères récents. Il donne :

| Titre | Total | Tendance/an | Liquidité médiane | ATR20 | Sw5/an | Statut |
|---|---:|---:|---:|---:|---:|---|
| EXA | 6 | 10,2 % | 1,2 M€ | 3,5 % | 12,5 | retenu |
| EXC | 6 | 1,8 % | 737 k€ | 3,5 % | 20,8 | retenu |
| EXB | — | −19,9 % | 741 k€ | 3,4 % | 9,4 | écarté |

Les quatre premiers rangs donnent le total ; les trois suivants restent informatifs. EXB est écarté pour sa tendance. EXA et EXC ont un total identique : EXA apparaît d'abord par le départage des rangs dans leur ordre d'importance. EXB n'entre pas dans ces rangs.

La fraîcheur courante n'est pas évaluée car l'historique est filtré. Vérifier que les trois historiques vont bien jusqu'à fin 2024 ; la date de fraîcheur de fin 2025 affichée par `market info` ne sert pas ici à mesurer un retard.

Pour la suite de l'exercice, choisir EXA. Dans une étude réelle, consigner également pourquoi ce titre a été retenu plutôt qu'EXC.

## Rechercher un barème avant 2025

~~~console
jedidemo tools score --database=growthdemo --security=EXA \
  --date=le:2024-12-31 --select=l750 --sort=fitness --budget=40
~~~

La période utilisée est **2022-02-16 → 2024-12-31**, soit 750 séances. La recherche adaptative évalue 40 barèmes parmi 11 793 candidats disponibles. Le premier résultat compact est :

~~~text
Fitness  Op/mois  Inv.max  Constructeur typé
  0.437    0.924    1.000  I: kc:1.5,1.38,1.23,1.14,0.52,0.4,
                             ki:0%, kb:1, kd:0.2
~~~

La définition est coupée sur deux lignes ici pour la lecture ; dans la commande, la transmettre comme une seule valeur. La fitness brute de 0,437 concerne la période de recherche, sans déduire les frais. Elle ne prédit pas la fitness de 2025. Le budget limité signifie que la première ligne est la meilleure selon le tri parmi les barèmes effectivement évalués.

Fixer pour l'exercice cette définition, les frais de 0,35 %, le montant de 1 500 € par ouverture et les conventions d'exécution par défaut. Un choix réel demande aussi une lecture de la mécanique et un contrôle d'opérabilité au prix de l'ouverture envisagée.

## Vérifier le choix sur 2025

~~~console
jedidemo tools backtest --database=growthdemo --security=EXA \
  --date=ge:2025-01-01 \
  --scale="kc:1.5,1.38,1.23,1.14,0.52,0.4,ki:0%,kb:1,kd:0.2"
~~~

La base s'arrête au 31 décembre 2025 : le filtre inférieur isole donc cette année. Le test démarre avec un nouveau trade ; il ne transporte pas les positions du parcours de recherche.

~~~text
Historique : 2025-01-01 → 2025-12-31 (261 séances)
Premier achat : 2025-01-01, 108 titres pour 1498.56 €
Opérations, ouvertures comprises : 7
Gain brut cumulé : -13.11 €
Frais cumulés : 7.10 €
Gain net cumulé : -20.21 €
Investissement maximal, hors frais : 1498.56 €
Gain net / investissement maximal : -1.35 %
Titres détenus en fin de test : 108 ; valeur 1450.47 €
~~~

Le parcours de recherche favorable est suivi d'un résultat net légèrement négatif. Les ventes et rachats génèrent des allers-retours, mais la valeur finale du stock contribue aussi au résultat. La commande avec `-c rfo` permet d'examiner les sept opérations.

Le début au 1er janvier reflète le calendrier fictif, pas une séance réelle du marché. Le résultat décrit ce fichier, ce barème et ces conventions. Il doit être conservé tel quel avant d'essayer d'autres réglages.

## Conserver les commandes et les résultats

~~~bash
study_dir="$HOME/jedi-study-growth-2025"
mkdir -p "$study_dir"
jedidemo version > "$study_dir/version.txt"
jedidemo config > "$study_dir/config.txt"
jedidemo tools score --database=growthdemo --security=EXA \
  --date=le:2024-12-31 --select=l750 --sort=fitness --budget=40 \
  > "$study_dir/score-before-2025.txt"
jedidemo tools backtest --database=growthdemo --security=EXA \
  --date=ge:2025-01-01 \
  --scale="kc:1.5,1.38,1.23,1.14,0.52,0.4,ki:0%,kb:1,kd:0.2" \
  > "$study_dir/backtest-2025.txt"
~~~

Ces redirections conservent les rapports standard ; l'avancement de `score` peut rester affiché au terminal. Joindre les deux fichiers source, la liste des titres, la question et la définition choisie. Le [chapitre 24](24_interpreter_comparer_et_suivre.md) explique le journal daté ; une note rédigée aujourd'hui doit porter sa date réelle.

## Passer aux données réelles

Préparer les titres effectivement présents sur Euronext Growth à la date retenue, avec leurs historiques et les opérations sur titres pertinentes. Décrire les exclusions et la disponibilité des données des sociétés sorties du marché. Vérifier la devise et l'unité des volumes.

Importer ces fichiers dans **une autre base d'étude**, avec un nom distinct et une borne finale explicite. Adapter les noms de source et de titres dans les commandes. Conserver séparément la présélection, la recherche et la vérification.

Si plusieurs titres sont simulés séparément, leurs investissements maximaux et leurs gains ne décrivent pas automatiquement un portefeuille finançable : les achats peuvent être simultanés. Examiner ensuite les projets d'ouverture et les réserves avec `candidate`, au prix et à la date de la décision réelle.
