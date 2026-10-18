# Préparer une étude historique

## Poser une question vérifiable

Une étude commence par une question précise : comment un barème donné se comporte-t-il sur un titre et une période ? Quelle activité entraîne-t-il ? Quel investissement maximal demande-t-il ? Comment résiste-t-il à une baisse ou à un gap ?

Écrire la question avant de lire les gains. Fixer les titres, les dates, les frais et le mode de dimensionnement. Une recherche avec `score` sert à choisir des barèmes sur ses données ; un backtest avec une définition fixée sert à examiner leur parcours. Changer un paramètre après lecture du résultat constitue un nouvel essai à conserver.

## Distinguer les périodes

Le [chapitre 23](23_exemple_etude_euronext_growth.md) utilise ce calendrier :

| Étape | Données accessibles | Usage |
|---|---|---|
| Préparation | Historique depuis début 2021 | Contrôles et profondeur historique |
| Présélection au 31 décembre 2024 | Cotations jusqu'à cette date | `profile` sur les 252 dernières séances, ATR sur 20 |
| Recherche au 31 décembre 2024 | Cotations jusqu'à cette date | `score` sur les 750 dernières séances |
| Vérification | Cotations de 2025 | `backtest` avec le barème déjà fixé |

La fenêtre de 252 séances décrit le comportement récent du titre. Celle de 750 expose les barèmes à un parcours plus long. Les données de vérification ne doivent pas servir à régler le choix qu'elles sont censées examiner.

Cette séparation n'efface pas ce que l'auteur sait déjà. Une étude réalisée après 2025 reste rétrospective, même si ses commandes isolent correctement les dates. Pour un suivi prospectif, consigner le choix à sa date réelle avant de disposer des observations suivantes.

## Choisir les titres et conserver leur liste

Préciser le périmètre : marché, dataset, groupe ou liste explicite. Pour une étude arrêtée fin 2024, rechercher la liste des titres présents à cette date. Une liste actuelle peut omettre des sociétés sorties du marché et ajouter des introductions ultérieures.

Conserver cette liste avec les fichiers. Signaler les exclusions, les historiques trop courts et les titres disparus. Ne pas supprimer discrètement un titre parce que son résultat est défavorable. Un dataset est un ensemble d'appartenances dans une base ; son nom ne certifie ni l'origine des données ni une composition historique.

Dans une base existante, examiner le périmètre :

~~~console
jedidemo market info demo --dataset=Demo
jedidemo market list demo --dataset=Demo --last-quote
~~~

Ces commandes supposent la [base Demo du chapitre 10](10_base_de_cotations.md#la-base-demo-des-exemples). Elles consultent la base sans télécharger de cotations.

## Contrôler les fichiers préparés

Conserver le fournisseur, la date de récupération, le format d'origine, les conversions et les conditions d'utilisation ou de diffusion. Les fichiers individuels et les fichiers d'import de dataset ont des présentations différentes, décrites au [chapitre 10](10_base_de_cotations.md).

Vérifier l'identité du titre, la devise, l'ordre des dates, les doublons, les volumes et la cohérence `Low ≤ Open, Close ≤ High`. Vérifier les séances absentes avec le calendrier du marché, plutôt qu'avec un simple comptage des jours ouvrés.

Identifier les divisions, regroupements et autres corrections de cours. Des cotations ajustées et non ajustées donnent des parcours différents. Ne pas mélanger une clôture ajustée avec des ouvertures et extrêmes non ajustés. Les cotations OHLCV ne constituent pas, à elles seules, un historique de dividendes ou de flux d'opérations sur titres pris en charge par la simulation.

Pour examiner un fichier individuel :

~~~console
jedidemo tools profile cotations_EXA.txt
jedidemo tools stats cotations_EXA.txt --date=le:2025-12-31
jedidemo tools plot cotations_EXA.txt --date=le:2025-12-31
~~~

Le profil met en évidence les caractéristiques et les contrôles qu'il calcule ; `stats` et `plot` complètent l'examen. Une courbe régulière ou un import réussi ne suffisent pas à certifier l'exactitude du fournisseur.

## Isoler réellement une année

Jedi accepte **un seul filtre `--date=OP:AAAA-MM-JJ` par commande** :

| Code | Sens |
|---|---|
| `ge` | Date supérieure ou égale |
| `gt` | Date strictement supérieure |
| `le` | Date inférieure ou égale |
| `lt` | Date strictement inférieure |

Le filtre de date est appliqué avant `--select`. Répéter `--date` ne construit pas une plage : la dernière valeur remplace la précédente. Pour isoler 2025 avec `--date=ge:2025-01-01`, utiliser un fichier ou une base **figés au 31 décembre 2025**, sans cotations ultérieures. Le fichier du chapitre 23 est livré ainsi.

Pour une recherche arrêtée à fin 2024, la borne supérieure suffit :

~~~console
jedidemo tools score cotations_EXA.txt --date=le:2024-12-31 \
  --select=l750 --sort=fitness --budget=40
~~~

Ce fichier ne contient pas 750 séances avant cette date ; le rapport annonce la période réellement disponible. Le fichier Growth du chapitre 23 fournit la profondeur nécessaire. Toujours lire les dates et le nombre de séances affichés.

`--select=l252` conserve les 252 dernières lignes après filtrage ; `f100` les 100 premières ; `1:100` une plage d'indices à partir de 1. Une sélection discontinue, par exemple `f10,-12:-1`, joint des morceaux de parcours : elle peut créer un saut artificiel entre deux dates. La réserver à l'inspection, en connaissant cet effet.

La fraîcheur courante de `profile` n'est pas évaluée lors d'une sélection historique avec `--date` ou `--select`. Cela évite de comparer des cotations arrêtées en 2024 à une référence de dataset de 2025 ou 2026. Contrôler soi-même que chaque titre atteint bien la borne historique voulue.

## Figer une copie d'étude

Une base maintenue avec `market update` évolue. Préparer une base de démonstration séparée pour l'étude et conserver les fichiers importés. Le lanceur `jedidemo` et l'option de dossier `JEDI_DEMO_DIR` permettent de séparer les essais ; les étapes figurent au chapitre 02.

Conserver aussi la version et la configuration effective :

~~~bash
study_dir="$HOME/jedi-study-2025"
mkdir -p "$study_dir"
jedidemo version > "$study_dir/version.txt"
jedidemo config > "$study_dir/config.txt"
jedidemo config --paths > "$study_dir/paths.txt"
~~~

Le dossier reçoit les sorties du terminal, indépendamment du dossier dans lequel le lanceur exécute Jedi. Avant de partager une configuration, retirer les clés de fournisseurs qu'elle peut contenir.

La fiche d'étude associe enfin la question, la liste de titres, les fichiers, les périodes, le barème, les frais et les commandes. Le [chapitre 24](24_interpreter_comparer_et_suivre.md) en propose un modèle.
