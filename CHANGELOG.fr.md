# Notes de version

Les changements notables sont présentés par version, de la plus récente à la plus ancienne, selon les catégories de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 1.1.0 - 2026-10-18

### Ajouté

- Combinaison d'un split ou d'un regroupement avec une réinitialisation `reset` ou `merge` dans `settings create`.
- Commande `operation fees ID MONTANT` pour corriger les frais de toute opération enregistrée, y compris une opération ancienne ou appartenant à un trade clôturé.
- Colonne Statut placée après le nom dans `trade list`, avec cinq statuts calculés : créé, paramétré, ouvert, en cours et clôturé, sans nouveau champ en base de données.
- Champ `status` dans le filtre regex de `trade list`, par exemple `"status=^(opened|running)$"`. Les codes anglais et les libellés de la langue active sont reconnus ; le filtre se combine avec les champs et opérateurs existants.
- Annexe 05 décrivant les entrées de la configuration par défaut et leur usage effectif, en français et en anglais.

### Modifié

- Attribution automatique des noms de barèmes `B_kc_NN` ou `B_vr_NN` selon leur type opérationnel. Les définitions opérationnelles équivalentes sont refusées à la création et à la modification, indépendamment du nom ou du constructeur saisi.
- Saisie d'une valeur non vide de `money` réservée aux trades paramétrés, ouverts ou en cours, avec `trade update`. L'effacement par `--money=""` reste possible à tous les statuts.
- Ajout de `status` après `name` dans les exports CSV des trades ; les indices des colonnes du tableau sont également décalés pour intégrer le statut.
- Présentation des résultats financiers de `tools backtest` dans l'ordre de création des trades.
- Documentation du nommage recommandé des trades sous la forme `T_<ticker>_<numéro>` ; enrichissement du glossaire avec `kcpc`, `kspc`, `emax`, `emin` et PRU.
- Documentation de la sélection d'un titre par l'analyse technique et la lecture visuelle des tendances, canaux, supports et résistances, avec plusieurs plateformes Web comme exemples.

### Supprimé

- Option `--money` de `trade create`. Créer d'abord le trade et son paramétrage initial, puis définir `money` avec `trade update`.

### Corrigé

- Maximum investi global du backtest : il correspond désormais au plus grand maximum individuel des trades, puisque les trades simulés ne se chevauchent pas. Les calculs et les présentations utilisant cette mesure sont alignés.
- Réinitialisation de `money` et `stop` à `nil` lorsqu'une vente ramène le stock détenu à zéro, y compris en simulation.
- Présentation des regex des fournisseurs Web dans la documentation, pour éviter leur débordement dans les colonnes voisines des tableaux PDF.

## 1.0.0

Première version publique préparée de Jedi, application de gestion mécanique de trades en ligne de commande.

### Fonctions disponibles

- Gestion des titres, barèmes, trades, paramétrages, opérations exécutées et notes.
- Calcul des ordres à envisager à partir de l’état du trade et des règles retenues.
- Gestion facultative du capital et des protections avec les paramètres `r`, `o` et `n`.
- Historiques de cotations dans des bases de marché distinctes, imports, mises à jour, datasets et groupes.
- `tools profile` pour examiner les titres, `tools score` pour rechercher un barème et `tools candidate` pour évaluer une ouverture.
- `tools calc` et `tools play` pour examiner la mécanique ; `tools backtest` pour simuler un barème fixé sur des cotations historiques.
- Interface et documentation en français et en anglais ; graphiques avec gnuplot.

### Installation et documentation

La distribution initiale vise Linux x86_64, notamment Ubuntu sous WSL2. Le binaire statique intègre SQLite ; gnuplot reste externe.

Les lanceurs `jedi`, `jedidemo` et `jedidev` séparent la production, les démonstrations et les développements, y compris les bases de marché. Le binaire commun est dans `~/.local/libexec/jedi`. Les commentaires et messages des lanceurs sont en anglais.

Le manuel comprend, par langue, un avant-propos, la philosophie de Jedi, trois parties, 24 chapitres et quatre annexes. Les PDF fournis comptent 99 pages en français et 96 en anglais. Les numéros figurent dans les titres PDF, le sommaire et les signets ; les titres Markdown restent sans numéro. Les cotations d’exemple sont fictives.

La locale `C.UTF-8` est prise en charge. L’aide de `candidate` et de `backtest` affiche le nombre effectif d’échelons utilisé pour le contrôle d’opérabilité.

### Périmètre

Jedi calcule et conserve les informations ; l’investisseur choisit les règles et gère l’exécution chez son courtier. Les résultats historiques ne garantissent pas les résultats futurs. La documentation explique les hypothèses et les limites des simulations.

Le code, la documentation et les scripts de Jedi sont fournis sous licence MIT. La première livraison ne comprend pas de binaire Windows natif, macOS ou ARM64.
