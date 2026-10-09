# Contributing to Jedi

[Français ci-dessous](#français)

Use a separate development directory and the `jedidev` launcher. Keep production databases, local configuration, API keys and logs out of commits.

For the 1.0 release, changes should address release blockers, correctness or clear documentation errors. Discuss larger features separately so that the release stays within its reviewed scope.

Use Crystal 1.21.1 and follow [BUILD.md](BUILD.md). Before proposing a code change, run:

```bash
bash release/check.sh
```

For a locally compiled development binary:

```bash
JEDI_DEV_BINARY="$PWD/build/jedi" jedidev config --paths
```

When changing a launcher, update its identical documentation copy in `examples/launchers/`. Keep script comments and messages in English. Preserve French and English user-facing translations and documents together.

Explain the concrete problem, the resulting behavior and which checks you executed. For a bug report, include `jedi version`, the command, the actual result and the expected result. Use fictional or anonymized data. Do not include API keys or a personal trading database.

## Français

Employer un répertoire de développement distinct et le lanceur `jedidev`. Garder les bases de production, les configurations locales, les clés API et les journaux hors des commits.

Pour la livraison 1.0, limiter les changements aux anomalies qui bloquent la livraison, aux erreurs de fonctionnement ou aux erreurs documentaires précises. Discuter les nouvelles fonctions séparément.

Avec Crystal 1.21.1, suivre [BUILD.fr.md](BUILD.fr.md) et exécuter `bash release/check.sh` avant de proposer un changement du code. `JEDI_DEV_BINARY="$PWD/build/jedi" jedidev config --paths` permet d’utiliser le binaire compilé pour le développement.

Une modification de lanceur doit être reproduite dans sa copie identique `examples/launchers/`. Conserver ses commentaires et messages en anglais ; mettre à jour ensemble les traductions et les documents français et anglais.

Décrire le problème concret, le comportement obtenu et les contrôles exécutés. Pour signaler une anomalie, fournir `jedi version`, la commande, le résultat observé et le résultat attendu. Utiliser des données fictives ou anonymisées, sans clé API ni base personnelle de trades.
