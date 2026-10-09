# Fichiers des exemples / Example files

## Français

Ces cotations sont **entièrement fictives**. Les trois ISIN servent uniquement aux démonstrations et ne désignent pas des titres à acheter. Le calendrier simplifié contient les jours de semaine, sans reprendre les jours fériés d'un marché réel.

| Fichier | Contenu et usage |
|---|---|
| `cotations_EXA.txt` | Identité d'EXA puis 851 séances, du 30 juin 2023 au 2 octobre 2026 ; exemples de `profile` et `score`. |
| `cotations_EXB.txt`, `cotations_EXC.txt` | Même format et même période pour les deux autres titres fictifs. |
| `Demo_initial.txt` | 2 550 cotations pour trois titres, jusqu'au 1er octobre 2026 ; import initial du chapitre 10. |
| `Demo_partiel.txt` | Une cotation du 2 octobre pour EXA ; exemple de mise à jour partielle. |
| `Demo_update.txt` | Trois cotations du 2 octobre ; exemple de mise à jour générale. |
| `labels_demo.txt` | Libellés au format ISIN, nom, ticker pour les commandes `market`. |
| `groupe_exemples.txt` | Trois ISIN pour créer le groupe `EXEMPLES`. |
| `jedi_proscreener_v1.txt` | Script JEDI validé, identique au listing de l'annexe 03. |
| `Growth_demo_2021_2025.txt` | 3 909 cotations fictives de trois titres, du 4 janvier 2021 au 31 décembre 2025 ; étude figée de la partie III. |
| `labels_growth_demo.txt` | Identités des trois titres de cette étude. |
| `cotations_GAP.txt` | Identité et deux cotations montrant une protection exécutée au-delà de son niveau après un gap. |

Après la préparation du chapitre 02, les fichiers TXT sont copiés dans `~/jedi-examples/`. Les commandes d'exemple utilisent **`jedidemo`**, qui ouvre ce dossier pour Jedi. Le terminal reste dans son répertoire courant ; `jedi` continue de désigner le portefeuille réel.

Pour retrouver les montants affichés, utiliser les réglages d'origine et une base principale sans trade engagé. Un portefeuille existant change les réserves et le financement de `candidate`. Les exemples `score` utilisent un budget de 40, une ouverture demandée de 1 500 € et les frais par défaut de 0,35 %, sans minimum. `candidate` contrôle par défaut deux titres minimum par ordre et trois échelons pour l'opérabilité.

Installer [les trois lanceurs du chapitre 02](../documentation/nouveaux/02_installer_et_preparer_jedi.md#installer-lexécutable-sous-linux), livrés dans `launchers/` : [jedi](launchers/jedi), [jedidemo](launchers/jedidemo), [jedidev](launchers/jedidev). Le binaire compilé est installé dans `~/.local/libexec/jedi` et les lanceurs dans `~/.local/bin/`. Depuis ce répertoire `examples/`, préparer la démonstration :

~~~bash
mkdir -p "$HOME/jedi-examples"
cp *.txt "$HOME/jedi-examples/"
jedidemo config --paths
~~~

Au premier lancement, répondre explicitement `O` aux demandes de création en français. Vérifier `environment: test` et la base `~/jedi-examples/jedi/env_test/data/jedi_test.db`. Le marché est dans `~/jedi-examples/jedi/env_test/market/`. Pour les commandes d'essai, employer `jedidemo` depuis n'importe quel dossier ; il n'y a aucun contexte à recharger. Les scripts s'exécutent normalement et refusent `source`.

Suivre [le début du chapitre 10](../documentation/nouveaux/10_base_de_cotations.md#la-base-demo-des-exemples) dans l'ordre : création de la base `demo`, import, mise à jour partielle, puis mise à jour générale. `market init` suppose que la base n'existe pas encore. Les fichiers individuels peuvent être utilisés sans cet import.

Pour les [chapitres 07 à 09](../documentation/nouveaux/07_ouvrir_un_trade.md), créer un autre dossier neuf, y copier les fichiers TXT et utiliser le préfixe `JEDI_DEMO_DIR=...` pour chacune de ses commandes, selon [le chapitre 02](../documentation/nouveaux/02_installer_et_preparer_jedi.md#conserver-plusieurs-espaces-dessai). Ajouter le capital fictif de 5 000 € dans sa propre configuration. Ces chapitres ouvrent EXA01 avec 100 titres, enregistrent une vente de 6 titres, puis partent du stock de 94 pour les adaptations. Les variantes du chapitre 09 sont indépendantes : chacune reprend cet état de départ. Une fois ces opérations enregistrées, la base ne permet plus de retrouver les rapports de `candidate` calculés sans trade engagé ; utiliser l'espace initial pour ces évaluations.

Les données EXA permettent de comprendre les sorties ; leurs résultats ne caractérisent aucun titre réel. Le script ProScreener s'utilise dans ProRealTime selon l'annexe 03.

## Exemples de mécanique des chapitres 11 à 20

Ces exemples utilisent des mouvements choisis avec `tools play`, sans importer de cotations. Le type I de départ utilise 100 titres à 10 € et un pas de 0,01 € ; il diffère du type II d'EXA01. Les chapitres 18 et 20 utilisent aussi 125 titres. Les hypothèses de frais restent à 0,35 %, sans minimum.

Préparer un espace neuf selon le chapitre 02, sans trade ouvert pour les évaluations de `candidate`. Pour les protections du chapitre 18, ajouter `simulation.capital: 20000` sous la forme YAML montrée dans [l'ouverture de la partie II](../documentation/nouveaux/partie_ii_comprendre_jedi.md#préparer-les-exemples-de-mécanique). Le capital de `candidate` est fourni par option ; celui des trades réels vient de `trading.capital`.

Les parcours définis directement dans `play` n'enregistrent aucune opération. Les commandes `scale create` enregistrent les trois barèmes pédagogiques ; créer chaque nom une seule fois. Les commandes `note` écrivent dans le journal de l'espace d'essai. L'exemple de `play` partant d'un identifiant au chapitre 19 exige une opération déjà enregistrée : utiliser son identifiant réel, éventuellement dans l'espace EXA01 de la partie I.

## English

These quotations are **entirely fictional**. The three ISINs are demonstration identifiers, not securities to buy. The simplified calendar contains weekdays without reproducing actual market holidays.

| File | Contents and use |
|---|---|
| `cotations_EXA.txt` | EXA's identity followed by 851 sessions, from 30 June 2023 to 2 October 2026; `profile` and `score` examples. |
| `cotations_EXB.txt`, `cotations_EXC.txt` | The same format and period for the other two fictional securities. |
| `Demo_initial.txt` | 2,550 quotations for three securities, through 1 October 2026; chapter 10's initial import. |
| `Demo_partiel.txt` | One quotation for EXA on 2 October; partial update example. |
| `Demo_update.txt` | Three quotations on 2 October; full population update example. |
| `labels_demo.txt` | Labels in ISIN, name, ticker order for `market` commands. |
| `groupe_exemples.txt` | Three ISINs for the `EXEMPLES` group. |
| `jedi_proscreener_v1.txt` | Validated JEDI script, identical to appendix 03's listing. |
| `Growth_demo_2021_2025.txt` | 3,909 fictional quotations for three securities, 4 January 2021 to 31 December 2025; part III's frozen study. |
| `labels_growth_demo.txt` | Identities of those three study securities. |
| `cotations_GAP.txt` | Identity and two quotations showing protection executed beyond its level after a gap. |

After chapter 02 preparation, TXT files are copied to `~/jedi-examples/`. Example commands use **`jedidemo`**, which opens that directory for Jedi. The terminal stays in its current directory; `jedi` continues to select your real portfolio.

To reproduce the amounts, use default settings and a main database without committed trades. An existing portfolio changes `candidate` reserves and funding. The `score` examples use a budget of 40, a requested opening amount of €1,500 and default fees of 0.35%, with no minimum. By default, `candidate` checks at least two shares per order and three steps for operability.

Install [chapter 02's three launchers](../documentation/nouveaux/en_02_installing_and_preparing_jedi.md#install-the-executable-on-linux), supplied in `launchers/`: [jedi](launchers/jedi), [jedidemo](launchers/jedidemo), [jedidev](launchers/jedidev). The compiled binary is installed in `~/.local/libexec/jedi`; launchers are in `~/.local/bin/`. From this `examples/` directory, prepare the demonstration:

~~~bash
mkdir -p "$HOME/jedi-examples"
cp *.txt "$HOME/jedi-examples/"
jedidemo config --paths
~~~

At first launch, explicitly answer `Y` to English creation prompts. Check `environment: test` and `~/jedi-examples/jedi/env_test/data/jedi_test.db`. Market databases are under `~/jedi-examples/jedi/env_test/market/`. For experiment commands, call `jedidemo` from any directory; there is no environment to reload. Run the scripts normally; they refuse to be sourced.

Follow [the start of chapter 10](../documentation/nouveaux/en_10_market_database.md#the-demo-database-for-the-examples) in order: create the `demo` database, import, perform the partial update, then update the full population. `market init` requires a database that does not yet exist. Individual files can be used without this import.

For [chapters 07–09](../documentation/nouveaux/en_07_opening_a_trade.md), create another new directory, copy the TXT files there and use the `JEDI_DEMO_DIR=...` prefix for every command using it, as in [chapter 02](../documentation/nouveaux/en_02_installing_and_preparing_jedi.md#keep-several-experiment-environments). Set €5,000 fictional capital in its own configuration. These chapters open EXA01 with 100 shares, record a sale of 6, then use the remaining 94 for adaptations. Chapter 09's variants are independent: each resumes that starting state. After these operations are recorded, the database no longer reproduces `candidate` reports calculated without committed trades; use the initial environment for those evaluations.

EXA helps explain the output; its results do not describe any real security. Run the ProScreener script in ProRealTime as described in appendix 03.

### Mechanics examples in chapters 11–20

These examples use chosen movements in `tools play`, without importing quotations. The initial type I uses 100 shares at €10 and a €0.01 tick; it differs from EXA01's type II. Chapters 18 and 20 also use 125 shares. Fees remain 0.35%, with no minimum.

Prepare a new environment as in chapter 02, with no open trades for `candidate` evaluations. For chapter 18's protections, set `simulation.capital: 20000` using the YAML structure in [part II's preparation](../documentation/nouveaux/en_part_ii_understanding_jedi.md#prepare-the-mechanics-examples). `candidate` capital is supplied by option; real trades use `trading.capital`.

Paths defined directly in `play` record no operations. `scale create` records the three teaching scales; create each name once. `note` commands write to the experiment journal. Chapter 19's `play` example starting from an identifier needs a recorded operation: use its actual identifier, possibly in part I's EXA01 environment.

## Étude historique de la partie III / Part III historical study

Suivre le [chapitre 23](../documentation/nouveaux/23_exemple_etude_euronext_growth.md) pour créer `growthdemo` et importer les deux fichiers Growth. Cette base est distincte de Demo et reste figée à fin 2025. Le profil et la recherche s'arrêtent fin 2024 ; le backtest commence en 2025. La configuration de simulation utilise 20 000 €, `risk_rate: 0.015`, `distance: 0.2`, soit 1 500 € demandés par ouverture, avec 0,35 % de frais sans minimum. Le fichier GAP s'utilise directement au chapitre 22.

Follow [chapter 23](../documentation/nouveaux/en_23_euronext_growth_study_example.md) to create `growthdemo` and import the two Growth files. It is separate from Demo and stays frozen at the end of 2025. Profile and search stop at the end of 2024; backtesting starts in 2025. Simulation uses €20,000, `risk_rate: 0.015`, `distance: 0.2`, hence €1,500 requested per opening, with 0.35% fees and no minimum. Use the GAP file directly in chapter 22.

Ces données sont fictives et ne constituent pas une liste de sociétés d'Euronext Growth. These data are fictional and are not an Euronext Growth company list.
