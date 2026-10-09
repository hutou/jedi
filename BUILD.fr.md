# Compiler Jedi 1.0

Ce guide s’adresse à la personne qui prépare la livraison ou souhaite compiler les sources. Pour utiliser le binaire déjà compilé, suivre [l’installation](INSTALL.fr.md).

## Entrées fixées

| Élément | Choix pour la livraison 1.0 |
|---|---|
| Version Jedi | `1.0.0`, déjà déclarée dans `shard.yml`. |
| Compilateur de livraison | Crystal `1.21.1`. Le projet déclare `>= 1.21.0, < 2.0`. |
| Dépendances Crystal | Versions de `shard.lock`, révisions et fichiers de `release/dependencies.json`. |
| Specs | `TZ=UTC`, résultat attendu : 493 exemples sans échec ni erreur. |
| Binaire public | Linux x86_64, statique avec musl, construit dans Alpine. |
| PDF | Fichiers fournis conservés ; Pandoc n’est pas nécessaire à la compilation de Jedi. |

Le guide décrit une procédure préparée. Le compte rendu joint à la préparation précise les contrôles exécutés. Il faut confirmer la compilation et les specs sur une machine disposant du compilateur avant de créer la release binaire.

## Compilation locale sous Ubuntu

Installer **Crystal 1.21.1 et Shards** depuis les [distributions officielles de Crystal](https://crystal-lang.org/releases/). Vérifier `crystal --version` et `shards --version`. Le paquet Crystal proposé par une ancienne version d’Ubuntu peut être trop ancien ; vérifier la version avant de poursuivre.

Préparer les bibliothèques de compilation :

```bash
sudo apt update
sudo apt install build-essential git python3 pkg-config \
  libgc-dev libevent-dev libpcre2-dev libyaml-dev libssl-dev \
  libsqlite3-dev zlib1g-dev gnuplot-nox
```

Depuis la racine des sources extraites ou clonées :

```bash
bash release/build-local.sh
```

Le script installe les dépendances verrouillées, contrôle leur contenu, vérifie le formatage, exécute les 493 specs, compile le point d’entrée `src/jedi_cli.cr`, puis crée `build/jedi` en mode release. Il exécute ensuite les essais d’installation et de premier usage dans des répertoires temporaires.

Les journaux sont dans `build/check/` et `build/smoke-local/`. Pour installer ce binaire local :

```bash
bash install.sh
```

Le binaire local utilise les bibliothèques de sa distribution. Pour l’archive publique portable, employer la construction statique ci-dessous.

## Pourquoi ignorer les scripts postinstall

La commande préparée est :

```bash
shards install --frozen --skip-postinstall
python3 release/verify-dependencies.py
```

Les versions verrouillées de `textseg` et `uniwidth` contiennent déjà leurs tables Unicode, et `cryplot` ses palettes générées. Leurs scripts postinstall peuvent les régénérer depuis Internet ; l’un utilise notamment une adresse `latest`. La livraison conserve les fichiers présents dans les révisions consignées, puis compare leurs sommes de contrôle. Cela fixe les données employées sans modifier les dépendances.

Ces choix doivent être conservés dans les essais de la livraison. Si un fichier de dépendance diffère, le contrôle s’arrête ; examiner la différence avant de modifier le manifeste.

## Construire le binaire statique

Installer Docker sur le poste de construction et vérifier `docker version`. La [documentation Crystal sur le lien statique](https://crystal-lang.org/reference/1.21/guides/static_linking.html) recommande musl et les images Alpine.

Après examen, enregistrer les fichiers du dépôt dans un commit. Depuis sa racine :

```bash
bash release/build-static.sh prepare
bash release/build-static.sh build
```

`prepare` récupère l’image officielle `crystallang/crystal:1.21.1-alpine`, fixe son digest, puis ajoute les bibliothèques SQLite statiques et les outils d’essai. `build` utilise l’identifiant exact de cette image préparée ; il ne la reconstruit pas. Il vérifie Crystal 1.21.1, exécute les contrôles des sources, compile avec `--release --static --no-debug`, vérifie l’ELF, puis exerce le vrai binaire dans Alpine avec gnuplot en sortie SVG. Les mentions des bibliothèques natives sont récupérées dans les versions amont correspondant aux paquets Alpine.

Les résultats sont `build/static/jedi`, `build/static/BUILD-INFO.json`, les journaux et `build/static/licenses/native/`. Le binaire doit être un ELF x86_64 sans interpréteur ni segment dynamique. Un simple succès de `--static` ne suffit pas à l’affirmer.

### Garder la même image pour reconstruire

La première préparation télécharge des paquets ; elle demande un accès à Internet. Pour refaire la construction avec les mêmes paquets, conserver l’image préparée et ses deux fichiers d’identité :

```bash
docker image save "$(cat build/static/builder-id.txt)" | \
  gzip -n > build/jedi-builder-1.0.0.tar.gz
```

Sur un autre poste de construction :

```bash
gzip -dc build/jedi-builder-1.0.0.tar.gz | docker image load
bash release/build-static.sh build
```

Copier aussi `build/static/builder-id.txt` et `build/static/base-image.txt`. Le manifeste des dépendances fixe leurs fichiers ; le manifeste de construction fixe l’image et les versions des paquets. Les métadonnées des archives sont normalisées, ce qui rend l’assemblage identique pour les mêmes fichiers d’entrée. Le guide ne promet pas que deux compilations produiront des binaires identiques octet pour octet.

## Essayer le binaire sur la cible

Sur Linux x86_64, avec Python 3 et gnuplot disponibles, depuis les sources préparées :

```bash
python3 release/smoke.py build/static/jedi \
  --graphics --log-dir build/smoke-target
```

Le scénario installe dans un emplacement temporaire, adapte uniquement ses copies privées des lanceurs et ne change pas `HOME`. Il contrôle les chemins de production via des variables XDG privées, les environnements test/dev, les locales, l’aide, `calc`, `play`, les imports Demo, `profile`, `score`, `candidate`, `backtest` et un premier achat fictif. Il vérifie aussi que cet achat n’apparaît pas dans les autres bases.

Dans Ubuntu sous WSL2, refaire cette commande après transfert du binaire et des sources. Ce scénario produit des SVG sans fenêtre ; vérifier séparément l’affichage interactif des graphiques avec `jedidemo tools plot cotations_EXA.txt`. Les collectes API/Web doivent aussi être essayées séparément avec les réglages de l’utilisateur et les fournisseurs qu’il emploie.

## Assembler les livraisons

Après réussite des contrôles :

```bash
python3 release/package.py --output dist/1.0.0
cd dist/1.0.0
sha256sum -c SHA256SUMS
```

Le dossier de sortie doit être neuf ou vide. Le script exige les preuves de construction et d’essai qui correspondent à la somme de contrôle du binaire et aux fichiers sources actuels. Il produit les archives binaire, source et documentaire, `SHA256SUMS` et un fichier `.sha256` par archive.

Pour préparer seulement les sources et la documentation lorsqu’aucun binaire n’a été vérifié :

```bash
python3 release/package.py --without-binary --output dist/preparation
```

Cette commande ne crée aucune archive d’exécutable. La publication est décrite dans [PUBLISHING.fr.md](PUBLISHING.fr.md).
