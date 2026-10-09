# Jedi

[English](README.md)

**Jedi aide à gérer un trade selon des règles choisies à l’avance.** Il calcule les quantités et les niveaux de cours à envisager, conserve les opérations exécutées et aide à appliquer la même méthode au fil des fluctuations.

Vous choisissez le titre et les règles. Vous placez les ordres chez votre courtier, vérifiez leur exécution et enregistrez dans Jedi ce qui s’est réellement passé. L’application effectue les calculs ; elle ne transmet aucun ordre au courtier.

## Ce que permet Jedi

- Suivre les trades, leurs réglages, les opérations exécutées et les notes.
- Calculer les ordres proposés et les protections liées à la gestion du capital, lorsqu’elle est activée.
- Examiner des titres avec `tools profile`, rechercher un barème avec `tools score` et évaluer une ouverture avec `tools candidate`.
- Comprendre la mécanique avec `tools calc` et `tools play`, ou simuler un barème fixé sur un historique avec `tools backtest`.
- Importer des historiques de cours dans une base de marché distincte et produire des graphiques avec gnuplot.

La [philosophie de Jedi](documentation/nouveaux/philosophie_de_jedi.md) présente la méthode et les décisions qui vous appartiennent. Les résultats historiques permettent d’examiner les règles ; ils ne garantissent pas les résultats futurs. Toutes les cotations livrées pour les exemples sont fictives.

## Commencer avec les exemples

La première distribution binaire vise **Linux x86_64**, notamment Ubuntu sous **WSL2** pour les utilisateurs Windows. Le binaire statique intègre la bibliothèque SQLite. Bash exécute les lanceurs ; gnuplot est nécessaire aux graphiques. Crystal sert uniquement à compiler les sources.

Télécharger `jedi-1.0.0-linux-x86_64.tar.gz` et son fichier `.sha256` depuis la rubrique Releases du dépôt. Après contrôle et extraction, exécuter `bash install.sh` dans le dossier extrait. Le [guide d’installation](INSTALL.fr.md) donne les commandes exactes.

L’installateur copie les exemples fictifs dans `~/jedi-examples/` et conserve les fichiers d’exemple déjà présents. Dans le terminal :

```bash
export PATH="$HOME/.local/bin:$PATH"
hash -r
jedidemo config --paths
```

Au premier lancement en français, répondre `O` à chaque demande de création. Vérifier `environment : test`. Essayer ensuite une hausse suivie d’une baisse simulées :

```bash
jedidemo tools play -c o0,6-14,17 -- \
  scale=vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0,q0=100,c0=10,tick=0.01 \
  1 -1
```

| Commande | Usage |
|---|---|
| `jedi` | Le portefeuille réel, dans les emplacements XDG. |
| `jedidemo` | Les exemples fictifs, dans un espace de démonstration distinct. |
| `jedidev` | Le développement, dans un espace de projet distinct. |

Chaque environnement possède aussi ses propres bases de marché. Le binaire commun est installé dans `~/.local/libexec/jedi` ; les lanceurs sont dans `~/.local/bin/`.

## Documentation

Le manuel comprend un avant-propos, la philosophie de Jedi, trois parties, 24 chapitres et quatre annexes dans chaque langue.

- [PDF français](output/pdf/jedi-1.0-fr.pdf)
- [PDF anglais](output/pdf/jedi-1.0-en.pdf)
- [Index des chapitres dans les deux langues](documentation/README.md)
- [Fichiers des exemples et leur utilisation](examples/README.md)
- [Notes de version](CHANGELOG.fr.md)

## Compiler et contribuer

Jedi est écrit en Crystal. La procédure de livraison utilise Crystal **1.21.1**, `TZ=UTC` pour les specs et les fichiers fournis qui fixent les dépendances. Voir [la compilation](BUILD.fr.md), [les contributions](CONTRIBUTING.md) et [la préparation d’une release](PUBLISHING.fr.md).

Le code, la documentation, les scripts et les exemples fictifs de Jedi sont distribués sous [licence MIT](LICENSE), Copyright © 2026 Hubert Toullec. Les mentions des dépendances figurent dans [THIRD-PARTY.md](THIRD-PARTY.md).
