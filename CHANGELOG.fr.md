# Notes de version

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
