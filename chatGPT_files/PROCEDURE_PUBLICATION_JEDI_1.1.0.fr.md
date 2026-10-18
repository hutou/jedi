# Publier Jedi CLI 1.1.0 depuis next-version

Procédure du 18 octobre 2026, pour le dépôt de travail `~/work/dev/jedi` et le dépôt public GitHub déjà utilisé pour la version 1.0.0.

La préparation se fait sur `next-version`. La fusion dans `main` précède la construction finale. Le binaire, les archives et le tag `v1.1.0` doivent correspondre au même commit de `main`.

Les commandes ci-dessous reprennent les scripts de publication de la 1.0 effectivement relus. Le contenu de votre répertoire actuel reste la référence ; les contrôles de préparation permettent de repérer les différences. Aucune commande de publication n'a été exécutée à votre place.

Exécuter les blocs dans l'ordre, dans le même terminal Bash. Attendre leur résultat avant de continuer. Si une commande échoue, rester à cette étape.

**1. Revenir dans le dépôt et vérifier les accès**

```bash
cd "$HOME/work/dev/jedi"
set -o pipefail
git branch --show-current
git status --short
git remote -v
gh auth status --hostname github.com
docker version
```

La branche doit être `next-version`. L'adresse `origin` doit désigner votre dépôt public `jedi`. `git status --short` doit être vide ; si des changements attendent encore leur enregistrement, les examiner et les commiter avant la synchronisation suivante. Docker doit afficher Client et Server sans erreur.

Retrouver le nom complet du dépôt et récupérer les branches distantes :

```bash
jedi_repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
printf '%s\n' "$jedi_repo"
git fetch origin --tags
if git show-ref --verify --quiet refs/remotes/origin/next-version; then
  git merge --ff-only origin/next-version
fi
```

Vérifier le compte et le nom affichés. Si `next-version` n'a encore jamais été envoyée sur GitHub, le bloc conditionnel passe simplement à la suite ; son premier envoi est prévu à l'étape 5.

**2. Vérifier la version et actualiser les contrôles de publication**

```bash
rg -n '^version:' shard.yml
```

Le résultat doit être `version: 1.1.0`. Corriger cette seule entrée dans `shard.yml` si nécessaire. La version du programme et les noms des archives sont tirés de cette entrée.

Votre dernière exécution complète confirme **617 exemples, sans échec, erreur ni attente**. Ce total est la référence pour la livraison 1.1.0. La construction finale de l'étape 7 rejouera la suite depuis `main`.

Dans les scripts de la 1.0, le nombre 493 était fixé dans `release/check.sh`, `release/build-info.py` et `release/package.py`. Le bloc suivant reprend le total 617, vérifie que les trois scripts sont cohérents, puis actualise leurs constantes et leurs messages. Il adapte aussi l'ancien scénario d'essai au nommage automatique des barèmes.

```bash
python3 - <<'PY'
from pathlib import Path
import re

count = "617"
paths = [Path("release/check.sh"), Path("release/build-info.py"), Path("release/package.py")]
texts = [path.read_text() for path in paths]
old_counts = []
for path, text in zip(paths, texts):
    found = re.findall(r"\b([0-9]+) examples, 0 failures, 0 errors, 0 pending", text)
    if len(found) != 1:
        raise SystemExit(f"Review the current spec check in {path} before continuing.")
    old_counts.extend(found)
if len(set(old_counts)) != 1:
    raise SystemExit("Release scripts disagree about the expected spec count.")
old = old_counts[0]
updates = {path: re.sub(r"\b" + old + r"\b", count, text)
           for path, text in zip(paths, texts)}
smoke = Path("release/smoke.py")
text = smoke.read_text()
text = text.replace('"--name=EXA-10", ', '')
text = text.replace('"--scale=EXA-10"', '"--scale=B_vr_01"')
text = text.replace('"--name=EXA01"', '"--name=T_exa_01"')
text = text.replace('"EXA01"', '"T_exa_01"')
if "EXA-10" in text:
    raise SystemExit("Review the scale creation and reference in release/smoke.py.")
updates[smoke] = text
for path, text in updates.items():
    if path.read_text() != text:
        path.write_text(text)
        print(f"Updated {path}")
print(f"Expected passing spec count: {count}")
PY
git diff -- release/check.sh release/build-info.py release/package.py release/smoke.py
```

Le barème de l'essai est créé sans nom explicite et devient `B_vr_01` dans sa base vide. Son trade est nommé `T_exa_01`. Les règles de gestion et les données de votre portefeuille ne sont pas concernées.

Adapter également les libellés de `.github/workflows/ci.yml` à « Jedi 1.1 checks » et au nouveau total. Les commandes du workflow restent celles de la chaîne de construction existante. Les corrections de licences GC/PCRE2 déjà intégrées à la 1.0 restent dans les scripts.

**3. Finaliser les documents livrés et régénérer les deux PDF**

Avant la construction finale, vérifier les références à la version courante :

| Fichier | Valeur ou contenu à contrôler |
|---|---|
| `README.md`, `README.fr.md`, `INSTALL.md`, `INSTALL.fr.md` | Archives `jedi-1.1.0-…` et liens vers les PDF 1.1. |
| `BUILD.md`, `BUILD.fr.md` | Version 1.1.0, total réel des specs et dossier `dist/1.1.0`. |
| `CHANGELOG.md`, `CHANGELOG.fr.md` | Nouvelle entrée 1.1.0 ; conserver l'entrée historique 1.0.0. |
| `documentation/nouveaux/02_installer_et_preparer_jedi.md` et sa version anglaise | Commandes d'installation correspondant aux archives 1.1.0. |
| `pdf/fr.yaml` | `output-file: output/pdf/jedi-1.1-fr.pdf`, titre `Jedi 1.1`, ajout de `documentation/nouveaux/fr_annex05_configuration_par_defaut.md` à `input-files`. |
| `pdf/en.yaml` | `output-file: output/pdf/jedi-1.1-en.pdf`, titre `Jedi 1.1`, ajout de `documentation/nouveaux/en_annex05_default_configuration.md` à `input-files`. |
| `documentation/README.md`, `pdf/README.md` | Liens vers les nouveaux PDF et cinq annexes par langue. |

Dans chaque fichier YAML, placer l'annexe 05 après l'annexe 04. Conserver une seule occurrence de chaque fichier. Vérifier aussi les indications destinées au lecteur dans les guides de publication du dépôt.

Depuis la racine du dépôt, générer les PDF avec les chemins des figures :

```bash
mkdir -p output/pdf
pandoc --defaults=pdf/fr.yaml --resource-path=.:documentation/nouveaux
pandoc --defaults=pdf/en.yaml --resource-path=.:documentation/nouveaux
ls -lh output/pdf/jedi-1.1-fr.pdf output/pdf/jedi-1.1-en.pdf
```

Les commandes demandent Pandoc et XeLaTeX, comme pour la génération précédente. Ouvrir les deux PDF : contrôler le titre 1.1, les cinq annexes, les figures, les tableaux des fournisseurs Web et les derniers paragraphes sur le statut et `money`. Les PDF sont des entrées de la livraison : cette génération doit précéder le commit final et la construction du binaire.

**4. Préparer les notes de version bilingues**

Créer ou relire `release/notes-1.1.0.md`. Le texte suivant peut servir de contenu ; le bilan des plateformes doit correspondre aux essais réellement exécutés.

```markdown
# Jedi 1.1.0

## Français

Jedi est une application en ligne de commande pour gérer des trades selon des règles définies à l'avance.

Cette version ajoute ou améliore :

- la combinaison d'un split ou d'un regroupement avec une réinitialisation reset ou merge ;
- le nommage automatique des barèmes B_kc_NN / B_vr_NN et le refus des définitions opérationnelles équivalentes ;
- les statuts calculés des trades et leur filtrage par le champ status de la regex ;
- la saisie de money après le paramétrage initial et l'effacement de money et stop à la clôture ;
- la correction des frais d'une opération avec operation fees ID MONTANT ;
- le maximum investi et l'ordre chronologique des résultats du backtest ;
- les manuels français et anglais, notamment la sélection visuelle d'un titre et l'annexe sur la configuration.

Télécharger jedi-1.1.0-linux-x86_64.tar.gz et son fichier .sha256, vérifier l'archive puis suivre INSTALL.fr.md. Pour une mise à jour, sauvegarder ses données avant installation et consulter CHANGELOG.fr.md.

Le binaire vise Linux x86_64 et Ubuntu sous WSL2. SQLite est intégré ; les graphiques demandent gnuplot. Licence MIT.

## English

Jedi is a command-line application for managing trades according to predefined rules.

This release adds or improves:

- combining a split or consolidation with reset or merge reinitialisation;
- automatic B_kc_NN / B_vr_NN scale names and rejection of equivalent operational definitions;
- calculated trade statuses and filtering through the existing status regex field;
- money entry after initial settings, and clearing money and stop at closure;
- fee corrections on any recorded operation through operation fees ID AMOUNT;
- peak investment and chronological backtest results;
- French and English manuals, including visual security selection and default configuration.

Download jedi-1.1.0-linux-x86_64.tar.gz and its .sha256 file, verify the archive and follow INSTALL.md. Back up data before updating and read CHANGELOG.md.

The binary targets Linux x86_64 and Ubuntu under WSL2. SQLite is included; charts require gnuplot. MIT license.
```

Ajouter aux notes la date de publication et le bilan des essais après leur exécution. Si ces ajouts modifient le fichier suivi par Git après la construction, reprendre commit, construction et assemblage. On peut aussi préparer le bilan final de la page GitHub dans une copie extérieure au dépôt à l'étape 9.

**5. Enregistrer la préparation sur next-version**

```bash
git diff --check
git status --short
git diff --stat
git add -A
git diff --cached --stat
git diff --cached --name-only
```

Examiner la liste : elle doit correspondre aux fichiers destinés au projet. Les PDF nouvellement générés et `release/notes-1.1.0.md` doivent en faire partie. Puis :

```bash
git commit -m "Prepare Jedi 1.1.0 release"
git status --short
git push -u origin next-version
```

Si toute cette préparation était déjà commitée et que rien n'a changé, passer directement à l'envoi de la branche. La dernière vérification de statut doit être vide.

**6. Fusionner next-version dans main**

```bash
git switch main
git pull --ff-only origin main
git merge --no-ff next-version -m "Merge next-version for Jedi 1.1.0"
git status --short
jedi_release_commit="$(git rev-parse HEAD)"
printf '%s\n' "$jedi_release_commit"
```

La fusion doit se terminer sans conflit et le dépôt doit être propre. `--no-ff` crée un commit de fusion qui matérialise l'intégration de la 1.1. La construction suivante porte sur ce commit. Si Git signale un conflit, le résoudre et valider la fusion avant de poursuivre.

**7. Construire et contrôler la livraison statique depuis main**

Réutiliser l'image conservée si elle est disponible ; sinon, la préparer avec le script :

```bash
if [ -s build/static/builder-id.txt ] &&
   docker image inspect "$(cat build/static/builder-id.txt)" >/dev/null 2>&1; then
  printf '%s\n' 'Using the existing pinned builder.'
else
  bash release/build-static.sh prepare
fi
bash release/build-static.sh build
```

Le script collecte les licences natives, contrôle les dépendances et le formatage, exécute toutes les specs, compile le binaire statique puis l'essaie dans Alpine. Attendre sa réussite complète.

```bash
cat build/check/specs.txt
python3 -m json.tool build/static/BUILD-INFO.json
python3 - <<'PY'
import json
import subprocess
from pathlib import Path
info = json.loads(Path("build/static/BUILD-INFO.json").read_text())
commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
if info.get("version") != "1.1.0" or info.get("commit") != commit:
    raise SystemExit("Build version or commit does not match the release.")
if info.get("linking") != "static-musl":
    raise SystemExit("A static-musl release binary is required.")
print("Build version and commit match:", commit)
PY
```

Le binaire est `build/static/jedi`. `BUILD-INFO.json` est produit à la fin du script ; son absence indique que la construction complète n'est pas terminée avec succès.

**8. Essayer le binaire sur le poste hôte**

```bash
python3 release/smoke.py build/static/jedi --graphics --log-dir build/smoke-target
python3 -m json.tool build/smoke-target/result.json
```

Le résultat doit contenir `"success": true` et `"graphics": true`. Ce scénario installe et utilise Jedi dans un espace temporaire, avec ses propres bases.

**9. Assembler les archives et finaliser le texte GitHub**

Le dossier `dist/1.1.0` doit être neuf ou vide. S'il contient une précédente tentative, le renommer avant de recommencer, par exemple `mv dist/1.1.0 dist/1.1.0-essai-1`, en choisissant un nom libre.

```bash
SOURCE_DATE_EPOCH="$(git show -s --format=%ct HEAD)" \
  python3 release/package.py --output dist/1.1.0
(cd dist/1.1.0 && sha256sum -c SHA256SUMS)
ls -lh dist/1.1.0
git status --short
```

Les trois contrôles doivent être `OK`, et le dépôt doit rester propre. Les sept pièces jointes sont les trois archives binaire/source/documentation, leurs trois fichiers `.sha256` et `SHA256SUMS`.

Pour vérifier spécifiquement Ubuntu sous WSL2, copier ces sept fichiers dans un dossier d'essai de cette distribution, puis exécuter :

```bash
sha256sum -c SHA256SUMS
mkdir "$HOME/jedi-verification-1.1.0"
tar -xzf jedi-1.1.0-source.tar.gz -C "$HOME/jedi-verification-1.1.0"
tar -xzf jedi-1.1.0-linux-x86_64.tar.gz -C "$HOME/jedi-verification-1.1.0"
cd "$HOME/jedi-verification-1.1.0/jedi-1.1.0-source"
python3 release/smoke.py ../jedi-1.1.0-linux-x86_64/jedi \
  --graphics --log-dir build/smoke-wsl2
```

Ce dossier d'essai doit être neuf. Si le poste de construction est déjà Ubuntu sous WSL2, l'essai de l'étape 8 a directement exercé cette plateforme. Le scénario SVG ne vérifie pas à lui seul l'ouverture d'une fenêtre gnuplot, ni les fournisseurs Web externes.

Revenir au terminal du dépôt et créer une copie des notes pour la page GitHub :

```bash
cd "$HOME/work/dev/jedi"
cp release/notes-1.1.0.md ../NOTES_RELEASE_1.1.0.md
```

Ajouter dans cette copie la date et les validations réelles, en français et en anglais. Cette copie extérieure peut être ajustée sans modifier les sources compilées.

**10. Envoyer main et attendre les contrôles GitHub**

```bash
git status --short
jedi_release_commit="$(git rev-parse HEAD)"
git push origin main
gh run list --repo "$jedi_repo" --branch main --commit "$jedi_release_commit" --limit 5
```

Le push rend les sources 1.1 visibles sur `main`. La page de release sera publiée séparément à l'étape 13. Dans l'onglet Actions du dépôt, attendre le succès du workflow pour ce commit exact. La liste peut mettre quelques secondes à apparaître ; relancer la dernière commande si elle est encore vide.

On peut suivre une exécution dans le terminal avec `gh run watch NUMERO --repo "$jedi_repo" --exit-status`, en remplaçant NUMERO par son identifiant. Continuer après sa réussite. Toute correction touchant les fichiers livrés impose un nouveau commit, une nouvelle construction, un nouvel essai et un nouvel assemblage avant le tag.

**11. Créer et envoyer le tag de la 1.1**

```bash
git status --short
git rev-parse HEAD
python3 -m json.tool build/static/BUILD-INFO.json
git tag -l v1.1.0
```

Le dépôt doit être propre, le commit doit correspondre à `BUILD-INFO.json` et la dernière commande ne doit rien afficher. Si le tag existe déjà, examiner cette situation avant de poursuivre. Puis :

```bash
git tag -a v1.1.0 -m "Jedi 1.1.0"
git push origin v1.1.0
git rev-list -n 1 v1.1.0
```

Le dernier résultat doit être le commit compilé.

**12. Créer la release en brouillon et la relire**

```bash
gh release create v1.1.0 --repo "$jedi_repo" \
  --verify-tag --draft --title "Jedi 1.1.0" \
  --notes-file ../NOTES_RELEASE_1.1.0.md \
  dist/1.1.0/jedi-1.1.0-linux-x86_64.tar.gz \
  dist/1.1.0/jedi-1.1.0-linux-x86_64.tar.gz.sha256 \
  dist/1.1.0/jedi-1.1.0-source.tar.gz \
  dist/1.1.0/jedi-1.1.0-source.tar.gz.sha256 \
  dist/1.1.0/jedi-1.1.0-documentation.zip \
  dist/1.1.0/jedi-1.1.0-documentation.zip.sha256 \
  dist/1.1.0/SHA256SUMS
gh release view v1.1.0 --repo "$jedi_repo"
gh release view v1.1.0 --repo "$jedi_repo" --json url --jq .url
```

Ouvrir l'adresse affichée dans le navigateur. Contrôler le statut Draft/Brouillon, le tag, le texte bilingue et les sept fichiers. Les deux liens Source code générés automatiquement par GitHub s'ajoutent à ces pièces jointes.

`--verify-tag` impose l'existence préalable du tag distant ; `--draft` laisse la page en brouillon pour cette relecture.

**13. Publier la release**

Après la relecture :

```bash
gh release edit v1.1.0 --repo "$jedi_repo" --draft=false --latest
gh release view v1.1.0 --repo "$jedi_repo" --json url --jq .url
```

Cette commande publie la page de release et marque 1.1.0 comme version Latest. Vérifier l'adresse dans une fenêtre de navigation privée.

**14. Contrôler les téléchargements et reprendre le développement**

```bash
mkdir ../controle-telechargement-1.1.0
gh release download v1.1.0 --repo "$jedi_repo" \
  --pattern '*' --dir ../controle-telechargement-1.1.0
(cd ../controle-telechargement-1.1.0 && sha256sum -c SHA256SUMS)
tar -xzf ../controle-telechargement-1.1.0/jedi-1.1.0-linux-x86_64.tar.gz \
  -C ../controle-telechargement-1.1.0
python3 release/smoke.py \
  ../controle-telechargement-1.1.0/jedi-1.1.0-linux-x86_64/jedi \
  --graphics --log-dir build/smoke-download-1.1.0
```

Les sommes et le scénario d'essai doivent réussir sur les fichiers réellement téléchargés. Le dossier de contrôle doit être neuf.

Puis remettre la branche de développement au niveau de la publication :

```bash
git switch next-version
git merge --ff-only main
git push origin next-version
git status --short
```

À cet instant, `main` et `next-version` désignent le commit publié. Les développements suivants reprennent sur `next-version` et feront avancer cette branche indépendamment du tag stable `v1.1.0`.

Si vous rouvrez un terminal, rétablir les variables avec :

```bash
cd "$HOME/work/dev/jedi"
set -o pipefail
jedi_repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
jedi_release_commit="$(git rev-parse HEAD)"
```

Références des commandes : [fusion Git](https://git-scm.com/docs/git-merge), [création d'une release](https://cli.github.com/manual/gh_release_create), [publication du brouillon](https://cli.github.com/manual/gh_release_edit), [contrôles GitHub Actions](https://cli.github.com/manual/gh_run_list).
