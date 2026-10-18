# Gérer la base de cotations

## La base Demo des exemples

Ce parcours prépare les données utilisées dès les chapitres 03 et 04. Les fichiers sont livrés dans [examples/](../../examples/README.md), à la racine de l'archive de documentation. Suivre d'abord le chapitre 02 pour installer `jedidemo` et copier les fichiers dans `~/jedi-examples/`. Le lanceur ouvre ce dossier pour les commandes, quel que soit le répertoire du terminal. Les commandes ci-dessous supposent l'univers par défaut `france` et une base `demo_france.db` encore absente.

Exécuter les étapes dans l'ordre, jusqu'à la mise à jour des trois titres au 2 octobre. Les exemples de `profile` du chapitre 04 utiliseront alors ce dataset `Demo`. Les fichiers individuels `cotations_EXA.txt`, `cotations_EXB.txt` et `cotations_EXC.txt` peuvent aussi être étudiés directement, sans créer cette base.

### Importer le dataset

Le répertoire `examples/` de ce lot contient des données **entièrement fictives**, avec un calendrier simplifié de jours de semaine. Avec les fichiers copiés dans le dossier de démonstration, les commandes suivantes créent une base `demo_france` qui doit être absente au départ :

~~~console
jedidemo market init demo
jedidemo market import demo Demo Demo_initial.txt labels_demo.txt
jedidemo market info demo --dataset=Demo
jedidemo market list demo --dataset=Demo --last-quote
~~~

`init` crée la base. `import` crée le dataset ; un dataset déjà présent doit être mis à jour ou remplacé avec les commandes adaptées.

La première importation de démonstration contient trois titres et 2 550 cotations, jusqu'au 1er octobre 2026. Le rapport indique les compteurs et anomalies. Certaines cotations invalides ou sans libellé peuvent être signalées et ignorées : examiner le rapport et le journal.

Pour consulter deux séances d'un titre :

~~~console
jedidemo market quote demo FR4487601001 --select=l2
~~~

`market quote` affiche l'historique de cet ISIN. Ce n'est pas `quote get`, qui interroge les fournisseurs de cours courant.

### Mettre les cotations à jour

Une mise à jour apporte un fichier contenant de nouvelles séances, avec les libellés nécessaires. Elle fusionne les données du dataset existant.

Dans la démonstration, n'apporter d'abord que le cours du 2 octobre pour EXA :

~~~console
jedidemo market update demo Demo Demo_partiel.txt labels_demo.txt
jedidemo market info demo --dataset=Demo
~~~

EXA est récent, les deux autres titres restent au 1er octobre. La sortie obtenue distingue :

~~~text
Période du dernier import complet : 2023-06-30 → 2026-10-01
Période actuellement disponible   : 2023-06-30 → 2026-10-02
Date de fraîcheur globale (95 %)  : 2026-10-01
~~~

Mettre ensuite les trois titres à jour :

~~~console
jedidemo market update demo Demo Demo_update.txt labels_demo.txt
jedidemo market info demo --dataset=Demo
~~~

Le doublon équivalent d'EXA est ignoré, les deux autres séances sont ajoutées. La référence globale passe au **2 octobre 2026**, tandis que la période du dernier import complet reste inchangée.

Ce parcours illustre l'entretien normal du dataset. Il n'est pas nécessaire de réimporter tout l'historique pour faire avancer sa fraîcheur.

## Deux bases aux usages distincts

| Base | Ce qu'elle conserve | Usage |
|---|---|---|
| Base principale Jedi | Titres, trades, paramètres, opérations, notes et cours enregistrés | Gestion des trades |
| Base de marché | Historiques OHLCV, datasets et groupes | Comparaison, recherche de barèmes et simulations |

**OHLCV** signifie ouverture, plus haut, plus bas, clôture et volume par séance. Ces données décrivent un historique ; un cours courant décrit un instant.

La base de marché est facultative. Un fichier individuel peut alimenter `profile`, `score` ou `backtest`. La base facilite le travail sur de nombreux titres et leurs mises à jour.

Les commandes `market` importent des fichiers fournis par l'utilisateur. Elles ne les téléchargent pas. Importer ces historiques ne met à jour ni le cours de la base principale, ni les opérations des trades.

## Source, univers, dataset et groupe

| Notion | Exemple | Rôle |
|---|---|---|
| Source | `abcbourse`, ou `demo` pour nos exemples | Nom logique de l'origine des fichiers |
| Univers | `france` | Périmètre qui complète le nom de la base |
| Dataset | `Euronext_A`, ou `Demo` | Ensemble de titres et de cotations importé |
| Groupe | `PEA`, ou `EXEMPLES` | Liste logique de titres |

Une source et un univers identifient un fichier SQLite, par exemple `abcbourse_france.db` ou `demo_france.db`. Le nom de la source ne déclenche aucune collecte.

Un même titre peut appartenir à plusieurs datasets et groupes. Des cotations peuvent être partagées entre datasets : les nombres affichés pour chaque dataset ne s'additionnent pas nécessairement.

Les datasets `Euronext_A`, `Euronext_B`, `Euronext_C`, `Euronext_Access` et `Euronext_Growth` appartiennent au contexte français utilisé pour préparer Jedi. Les commandes restent utilisables avec d'autres périmètres, en tenant compte des données et de leur unité monétaire.

## Vérifier les emplacements

~~~console
jedidemo config --paths
~~~

Avec `jedidemo`, les bases de marché sont normalement dans `~/jedi-examples/jedi/env_test/market/`. `JEDI_DEMO_MARKET_DIR` permet de sélectionner un autre répertoire. Avec `jedi`, le marché de production est normalement dans `~/.local/share/jedi/market/`, en tenant compte de `XDG_DATA_HOME`. Le chapitre 02 explique ces choix.

L'univers par défaut vient de `market_data.default_universe`, normalement `france`. Une option explicite le remplace :

~~~console
jedidemo market info demo --universe=france
~~~

Employer le même univers dans toute une suite de commandes. Changer d'univers désigne une autre base physique.

## Préparer les fichiers

« Préparer » signifie identifier la provenance, mettre les données dans le format attendu et vérifier leur cohérence. Il peut être nécessaire de convertir un export obtenu hors de Jedi. La licence du logiciel ne définit pas les droits d'usage des cotations fournies par un tiers.

Pour un import de dataset, préparer deux fichiers.

Le fichier de cotations contient **ISIN ; date ; ouverture ; plus haut ; plus bas ; clôture ; volume**, sans ligne d'identification à trois champs :

~~~text
FR4487601001;20230630;10.0000;10.1800;9.8200;10.0000;60000
FR4487601019;20230630;30.0000;30.4800;29.5200;30.0000;30000
~~~

Le fichier de libellés contient **ISIN ; nom ; ticker** :

~~~text
FR4487601001;Exemple A;EXA
FR4487601019;Exemple B;EXB
FR4487601027;Exemple C;EXC
~~~

Attention à l'ordre : un fichier individuel destiné aux outils commence, lui, par **ISIN ; ticker ; nom**, puis ses cotations :

~~~text
FR4487601001;EXA;Exemple A
FR4487601001;20230630;10.0000;10.1800;9.8200;10.0000;60000
~~~

Ne pas confondre ces deux premières lignes. Le fichier individuel doit concerner un seul ISIN ; le fichier de dataset peut en contenir plusieurs. Éviter une ligne d'en-tête de colonnes dans le fichier de cotations. Le fichier de libellés accepte un en-tête `ISIN;Name;Ticker`.

Le lecteur de cotations accepte le point-virgule ou la virgule comme séparateur, et plusieurs formats de dates. Pour préparer un nouveau fichier, les dates `AAAAMMJJ` et le point décimal évitent les ambiguïtés. Pour des dates ambiguës, `--date-order=dmy` ou `ymd` précise l'ordre ; consulter l'aide de la commande.

Avant l'import, contrôler les ISIN, les dates, les colonnes, les prix positifs, le plus haut et le plus bas, les volumes non négatifs et les doublons. Les prix bruts et ajustés doivent être identifiés et employés de façon cohérente. Un import réussi ne prouve pas que les séances manquantes, les suspensions ou les corrections du fournisseur ont été traitées correctement.

Conserver les fichiers d'origine, la période couverte, les transformations, la liste des titres et la date d'acquisition. Prévoir assez d'historique pour les outils : `profile` étudie récemment 252 séances mais demande un historique plus long pour ses contrôles ; `score` en utilise 750 par défaut.

## Les trois dates à comprendre

| Information | Ce qu'elle décrit |
|---|---|
| Dernier import complet et sa période | L'opération d'import et la période de cotations apportée par cet import |
| Période actuellement disponible | Les plus anciennes et plus récentes cotations présentes pour le dataset |
| Date de fraîcheur globale | La date atteinte par au moins 95 % des titres |

La référence globale est calculée à partir de la dernière cotation de chaque titre du dataset. Elle peut avancer avec quelques titres en retard, si au moins 95 % ont atteint la nouvelle date. Pour 600 titres, il en faut au moins 570 ; le cas de 595 titres récents et cinq retardataires satisfait cette condition.

Elle ne dépend pas simplement de l'heure du dernier appel à `market update`. Elle reste également une référence relative : si tous les titres sont anciens, vérifier la date face à la séance que l'on veut étudier.

`profile` utilise cette référence pour les retards individuels : zéro séance, vigilance à une ou deux séances, élimination au-delà de deux. Une sélection historique ou un dataset ambigu peut rendre ce contrôle indisponible ; le chapitre 04 précise ces cas.

## Lire les anomalies et les trous

Une cotation déjà présente avec les mêmes valeurs est considérée comme un doublon équivalent. Une valeur contradictoire lors d'un `update` est signalée et ignorée ; la valeur enregistrée reste conservée. Une mise à jour n'est donc pas une procédure de correction des cotations anciennes conflictuelles.

Si la première nouvelle séance est située à plus de sept jours calendaires après la fin actuelle du dataset, l'extension est refusée sauf avec `--allow-gap` :

~~~console
jedidemo market update demo Demo Demo_update.txt labels_demo.txt --allow-gap
~~~

Cette option accepte le trou ; elle ne le comble pas. Le contrôle porte sur l'extension globale du dataset et ne détecte pas toutes les lacunes de chaque titre. Consulter les séries individuelles lorsque le rapport ou le fournisseur indique un problème.

## Remplacer un dataset et gérer les groupes

`market replace` sert à reprendre un dataset avec un nouveau corpus complet, par exemple après une correction de données. Vérifier les fichiers et garder une sauvegarde avant d'utiliser cette commande ; les données partagées avec d'autres datasets sont préservées.

Un groupe est créé ou synchronisé à partir d'une liste d'ISIN ou de tickers, un par ligne :

~~~console
jedidemo market sync-group demo EXEMPLES groupe_exemples.txt \
  --as-of=2026-10-02 --reference-source=demonstration
jedidemo market list demo 'group=EXEMPLES' --last-quote
jedidemo tools profile --database=demo --dataset=Demo --group=EXEMPLES --rank-criteria=4
~~~

La synchronisation remplace la composition actuelle : un membre absent du fichier est retiré du groupe. La date `--as-of` décrit la référence de la liste, pas une reconstruction automatique de sa composition passée.

Maintenir les fichiers, lire `market info`, vérifier les dernières cotations avec `market list`, puis lancer les outils sur la population voulue. La base principale et les cours du suivi réel continuent d'être gérés séparément.
