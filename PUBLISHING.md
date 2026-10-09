# Prepare and publish Jedi 1.0

Publication is a separate step after review of files and results. The publication commands below are provided for that stage; archive preparation does not execute them.

## Proposed repository

| Location | Content |
|---|---|
| `README.md`, `README.fr.md` | English and French overview, first demonstration and manual links. |
| `src/`, `spec/`, `shard.yml`, `shard.lock` | Supplied sources and specs; two launcher assertions aligned with English messages. |
| `launchers/`, `install.sh` | Public launchers and per-user installation. |
| `documentation/nouveaux/`, `documentation/README.md` | 66 current texts and bilingual chapter index. |
| `output/pdf/`, `pdf/` | Supplied manuals and their generation files. |
| `examples/`, `reference/` | Fictional examples, documentary launcher copies and supplied command help. |
| `LICENSE`, `THIRD-PARTY.md`, `licenses/` | MIT license and dependency notices. |
| `release/`, `.github/workflows/ci.yml` | Build, verification and packaging; CI without automatic publication. |

Old chapters, editorial tracking and old patches remain in the original archives and are excluded from this public tree. Local databases, configurations, logs, caches and build outputs are excluded from Git and release packages.

The prepared license says `Copyright (c) 2026 Hubert Toullec`, whose name is confirmed by project and Tablo metadata. It covers project work; third-party notices are preserved separately.

## Record the reviewed version locally

From the supplied `repository/` directory:

```bash
git init -b main
git add .
git status --short
git commit -m "Prepare Jedi 1.0.0 public release"
```

Git uses your configured commit identity. If none is configured, set your name and commit email in this repository before retrying `git commit`.

Build according to [BUILD.md](BUILD.md):

```bash
bash release/build-static.sh prepare
bash release/build-static.sh build
python3 release/smoke.py build/static/jedi \
  --graphics --log-dir build/smoke-target
python3 release/package.py --output dist/1.0.0
```

Repeat the target scenario under WSL2 if desired, keeping its logs separately, for example in `build/smoke-wsl2/`. Automated graphics checks produce SVG files. Also test an interactive gnuplot window in any environment you intend to describe as tested.

Check the archives:

```bash
cd dist/1.0.0
sha256sum -c SHA256SUMS
cd ../..
git status --short
```

The repository must be clean. In `build/static/BUILD-INFO.json`, check the compiled commit, Crystal 1.21.1, passing 493-spec result and static linking. Changing any public input file after building requires a new build and packaging run.

## Release files

| File | Audience |
|---|---|
| `jedi-1.0.0-linux-x86_64.tar.gz` | Linux x86_64 or Ubuntu/WSL2 users: binary, launchers, installer, manual and examples. |
| `jedi-1.0.0-source.tar.gz` | People who want to compile or inspect the source. |
| `jedi-1.0.0-documentation.zip` | Readers who want the manual and fictional examples. |
| `SHA256SUMS` and three `.sha256` files | Download integrity checks. |

The binary archive includes `BUILD-INFO.json`, `TARGET-TEST.json` and native-library licenses. Preserve detailed logs and the builder image on the release machine. GitHub's automatic source archives complement these files; they are not executable archives.

The preparation bundle's `release-assets/` may contain only source and documentation if the compiler was unavailable. Its accompanying report identifies this case. Do not announce a binary archive before it has been built and checked.

## Create the public repository and draft release

This block puts files online. Execute it after review and agreement to publish. Install GitHub CLI, then supply the actual account and repository name; these are not inferred from `shard.yml` authors.

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

If the repository already exists, use its real URL rather than recreating it, and add `origin` with `git remote add origin ...`. Do not force-push or replace existing history.

Create a draft with verified assets:

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

Review the draft, open the proposed files and check their names. Then publish:

```bash
gh release edit v1.0.0 --repo "$jedi_owner/$jedi_repo" --draft=false --latest
```

GitHub CLI documents [repository creation](https://cli.github.com/manual/gh_repo_create), [release creation](https://cli.github.com/manual/gh_release_create) and [release editing](https://cli.github.com/manual/gh_release_edit). The prepared workflow runs checks and packages files; it does not publish releases.
