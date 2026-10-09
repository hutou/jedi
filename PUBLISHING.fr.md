# Préparer puis publier Jedi 1.0

La mise en ligne est une étape distincte, à effectuer après examen des fichiers et des résultats. Les commandes de publication ci-dessous sont fournies pour ce moment ; la préparation des archives ne les exécute pas.

## Organisation proposée

| Emplacement du dépôt | Contenu |
|---|---|
| `README.md`, `README.fr.md` | Présentation anglaise et française, premier essai et liens vers le manuel. |
| `src/`, `spec/`, `shard.yml`, `shard.lock` | Sources et specs fournies ; deux assertions de lanceur alignées sur les messages anglais. |
| `launchers/`, `install.sh` | Lanceurs publics et installation pour le compte utilisateur. |
| `documentation/nouveaux/`, `documentation/README.md` | Les 66 textes actuels et leur index bilingue. |
| `output/pdf/`, `pdf/` | PDF validés dans le travail documentaire et fichiers de génération. |
| `examples/`, `reference/` | Exemples fictifs, copies documentaires des lanceurs et aides fournies. |
| `LICENSE`, `THIRD-PARTY.md`, `licenses/` | Licence MIT et mentions des dépendances. |
| `release/`, `.github/workflows/ci.yml` | Construction, vérification et assemblage ; CI sans mise en ligne automatique. |

Les anciens chapitres, les suivis éditoriaux et les anciennes rustines restent dans les archives originales. Ils n’entrent pas dans le dépôt public préparé. Les bases, configurations, journaux, caches et résultats de construction locaux sont exclus de Git et des archives de publication.

La licence préparée porte `Copyright (c) 2026 Hubert Toullec`, nom confirmé par les métadonnées du projet et de sa dépendance Tablo. La licence couvre les créations du projet ; les mentions des composants tiers sont conservées séparément.

## Enregistrer la version examinée localement

Depuis le dossier `repository/` livré :

```bash
git init -b main
git add .
git status --short
git commit -m "Prepare Jedi 1.0.0 public release"
```

Git utilise votre identité habituelle pour le commit. Si elle n’est pas configurée, renseigner votre nom et votre adresse de commit dans ce dépôt avant de reprendre `git commit`.

Construire ensuite selon [BUILD.fr.md](BUILD.fr.md) :

```bash
bash release/build-static.sh prepare
bash release/build-static.sh build
python3 release/smoke.py build/static/jedi \
  --graphics --log-dir build/smoke-target
python3 release/package.py --output dist/1.0.0
```

Le scénario de cible peut être refait sous WSL2 ; conserver alors ses journaux dans un autre dossier, par exemple `build/smoke-wsl2/`. La vérification graphique automatisée produit des SVG. Essayer aussi l’ouverture d’une fenêtre gnuplot dans l’environnement que l’on souhaite annoncer comme testé.

Vérifier les sommes :

```bash
cd dist/1.0.0
sha256sum -c SHA256SUMS
cd ../..
git status --short
```

Le dépôt doit être propre. Vérifier dans `build/static/BUILD-INFO.json` le commit réellement compilé, Crystal 1.21.1, le résultat des 493 specs et le caractère statique. Toute modification de fichier public après construction impose de reprendre la construction et l’assemblage.

## Fichiers de la release

| Fichier | Destinataire |
|---|---|
| `jedi-1.0.0-linux-x86_64.tar.gz` | Utilisateur Linux x86_64 ou Ubuntu sous WSL2 : binaire, lanceurs, installateur, manuel et exemples. |
| `jedi-1.0.0-source.tar.gz` | Personne qui veut compiler ou examiner les sources. |
| `jedi-1.0.0-documentation.zip` | Personne qui veut lire le manuel et reproduire les exemples. |
| `SHA256SUMS` et trois fichiers `.sha256` | Contrôle de l’intégrité des téléchargements. |

L’archive binaire inclut `BUILD-INFO.json`, `TARGET-TEST.json` et les licences des bibliothèques natives. Conserver les journaux détaillés et l’image de construction sur le poste de livraison. Les archives automatiques « Source code » de GitHub complètent ces fichiers ; elles ne remplacent pas l’archive d’exécutable.

Le dossier `release-assets/` du dossier de préparation peut ne contenir que les sources et la documentation si le compilateur n’était pas disponible. Le bilan joint indique ce cas. Ne pas annoncer une archive binaire tant qu’elle n’a pas été construite et vérifiée.

## Créer le dépôt public et le brouillon de release

Ce bloc met des fichiers en ligne. L’exécuter après examen et accord sur la publication. Installer GitHub CLI, puis choisir le compte et le nom réels du dépôt ; ces informations ne sont pas déduites du champ `authors` de `shard.yml`.

```bash
jedi_owner="YOUR_GITHUB_ACCOUNT"
jedi_repo="jedi"
gh auth login
gh repo create "$jedi_owner/$jedi_repo" --public --source=. --remote=origin \
  --description "Mechanical trade management in Crystal / Gestion mécanique de trades"
git push -u origin main
git tag -a v1.0.0 -m "Jedi 1.0.0"
git push origin v1.0.0
```

Si le dépôt existe déjà, utiliser son URL réelle au lieu de le recréer, puis ajouter `origin` avec `git remote add origin ...`. Ne pas forcer un envoi ni remplacer l’historique existant.

Créer une release en brouillon, avec les fichiers réellement vérifiés :

```bash
gh release create v1.0.0 --repo "$jedi_owner/$jedi_repo" \
  --verify-tag --draft --title "Jedi 1.0.0" \
  --notes-file release/notes-1.0.0.md \
  dist/1.0.0/jedi-1.0.0-linux-x86_64.tar.gz \
  dist/1.0.0/jedi-1.0.0-linux-x86_64.tar.gz.sha256 \
  dist/1.0.0/jedi-1.0.0-source.tar.gz \
  dist/1.0.0/jedi-1.0.0-source.tar.gz.sha256 \
  dist/1.0.0/jedi-1.0.0-documentation.zip \
  dist/1.0.0/jedi-1.0.0-documentation.zip.sha256 \
  dist/1.0.0/SHA256SUMS
gh release view v1.0.0 --repo "$jedi_owner/$jedi_repo" --web
```

Relire le brouillon, ouvrir les fichiers proposés et vérifier leurs noms. Après cette dernière lecture :

```bash
gh release edit v1.0.0 --repo "$jedi_owner/$jedi_repo" --draft=false --latest
```

Les [commandes de création de dépôt](https://cli.github.com/manual/gh_repo_create), [création de release](https://cli.github.com/manual/gh_release_create) et [modification de release](https://cli.github.com/manual/gh_release_edit) sont documentées par GitHub CLI. Le workflow préparé exécute les contrôles et assemble les fichiers ; il ne publie pas de release.
