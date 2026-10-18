# Choisir un titre-support

## Commencer par une liste de travail

Le titre-support est le titre que l'on souhaite gérer dans un trade. Sa sélection précède le choix du barème et l'évaluation du montant à engager.

On peut partir d'une liste suivie personnellement, d'une plateforme de marché, d'un screener externe ou de `tools profile`. Dans tous les cas, les titres trouvés constituent une liste à examiner. L'utilisateur conserve le choix final.

Pour comprendre un résultat, noter la population étudiée et la date des cours. Une liste Euronext Growth et une liste réunissant plusieurs marchés ne comparent pas les mêmes titres. Un même titre peut changer de rang si la population change.

## Quatre questions pratiques

| Critère principal | Question à poser | Lecture pratique |
|---|---|---|
| Tendance | Le cours monte-t-il, baisse-t-il ou reste-t-il globalement stable ? | Une baisse persistante peut entraîner des achats successifs et immobiliser du capital. |
| Liquidité | Quels montants s'échangent habituellement ? | Mettre cette information en regard des quantités et montants envisagés. |
| Volatilité | Quelle ampleur ont les variations quotidiennes ? | Des mouvements trop faibles limitent les occasions ; des mouvements importants demandent davantage d'attention. |
| Oscillation | Les mouvements changent-ils régulièrement de sens ? | Les allers-retours reposent sur des mouvements dans les deux directions. |

Une variation journalière importante et une oscillation régulière sont différentes. Un titre qui baisse fortement chaque jour peut être volatil tout en offrant peu de retours à la hausse.

Trois critères complètent cette lecture : le **recul maximal**, c'est-à-dire la baisse depuis un sommet antérieur ; les **gaps**, écarts entre une clôture et l'ouverture suivante ; le **pas suggéré**, taille de mouvement proposée pour commencer l'examen d'un barème.

Le chapitre 04 explique les mesures, les seuils et les sept critères de classement. Commencer par les quatre principaux aide à lire le rapport ; les points de vigilance complémentaires restent à examiner.

## Utiliser une sélection externe

Un screener filtre une population selon des conditions. Le ProScreener JEDI de l'annexe 03 utilise des barres journalières et recherche une tendance compatible, une liquidité minimale et une volatilité suffisante. Il affiche aussi l'oscillation.

Choisir explicitement le marché ou la liste de titres dans la plateforme, puis lire les résultats sur une séance terminée. Repérer quelques titres et vérifier leur historique, leurs volumes et les éventuels événements récents.

La sélection externe et `profile` doivent fournir des listes cohérentes sur les principaux critères. Des différences peuvent venir de la date, du fournisseur, des ajustements des cours, du calcul de tendance ou de l'historique disponible. La concordance parfaite des listes n'est pas un objectif de choix.

Le script JEDI et sa procédure sont repris dans [l'annexe 03](fr_annex03_scripts_de_selection_externe.md).

## Utiliser une base de marché Jedi

Pour essayer les commandes avant de préparer vos propres données, suivre [le début du chapitre 10 : la base Demo des exemples](10_base_de_cotations.md#la-base-demo-des-exemples). Ce parcours crée la source `demo` et le dataset `Demo`, puis les met à jour. Le chapitre 04 les utilise pour expliquer les résultats de `profile`.

Une base de marché classe les historiques par **dataset**, ensemble importé, et peut réunir des titres dans des **groupes**, listes logiques définies par l'utilisateur.

~~~console
jedidemo tools profile --database=abcbourse --dataset=Euronext_A --rank-criteria=4
~~~

Cette commande examine les titres du dataset `Euronext_A` et additionne leurs rangs sur les quatre premiers critères. Remplacer `abcbourse` et le dataset par ceux de la base effectivement préparée.

Un groupe peut réunir des titres de plusieurs datasets :

~~~console
jedidemo tools profile --database=abcbourse --group=PEA --rank-criteria=4
~~~

Combiner `--dataset` et `--group` retient leur intersection. Le groupe `PEA` est une liste enregistrée dans la base ; son nom ne vérifie pas automatiquement l'éligibilité de chaque titre.

Les exemples préparatoires de Jedi utilisent notamment des historiques français et les datasets `Euronext_A`, `Euronext_B`, `Euronext_C`, `Euronext_Access` et `Euronext_Growth`. Ces noms n'imposent pas le marché sur lequel utiliser le logiciel.

## Travailler avec un fichier individuel

Une base de marché n'est pas nécessaire pour étudier un titre déjà choisi. Un **fichier préparé** contient ses cotations dans un format lisible par Jedi, avec son identité et des lignes OHLCV contrôlées. Sa préparation est expliquée aux chapitres 05 et 10.

Le fichier fictif [cotations_EXA.txt](../../examples/cotations_EXA.txt) se trouve dans le répertoire **examples/** livré avec cette documentation. Les données sont fournies sous forme de fichiers utilisables, séparément du texte des chapitres. Le [guide des exemples](../../examples/README.md) explique comment préparer le terminal et isoler les essais.

Après la copie des fichiers dans `~/jedi-examples/` au chapitre 02, les commandes suivantes utilisent directement le fichier. `jedidemo` ouvre ce dossier ; aucun import dans une base de marché n'est nécessaire :

~~~console
jedidemo tools profile cotations_EXA.txt
jedidemo tools score cotations_EXA.txt --sort=fitness --budget=40
~~~

Le premier rapport décrit le titre ; le second recherche des barèmes. Le budget de 40 permet une démonstration courte. Le budget courant du programme est de 500.

`profile` calcule les critères récents sur 252 séances, avec un contrôle de qualité sur l'historique long. `score` conserve 750 séances par défaut pour simuler davantage de situations. Le chapitre 05 explique cette différence et comment examiner une autre période.

## Passer au projet de trade

Après choix d'un barème, évaluer le candidat avec son ISIN, une définition de barème et un prix actuel vérifié :

~~~console
jedidemo tools candidate FR4487601001 --price=10 \
  --scale="vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0" \
  --amount=1000 --capital=5000
~~~

Cet exemple utilise un titre et un prix **fictifs**. Il évalue un achat initial de 100 titres et les besoins du projet. Il ne lit pas les cotations du fichier `EXA` : le prix de 10 € est fourni explicitement pour illustrer le calcul.

Avant de retenir le titre, lire ses alertes, examiner le barème, vérifier les ordres utiles et le financement. S'il reste une difficulté, choisir un autre projet ou préciser les données plutôt que retenir automatiquement la première ligne d'un classement.
