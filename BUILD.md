# Build Jedi 1.1

This guide is for the person preparing a release or building from source. To use an already compiled binary, follow [installation](INSTALL.md).

## Fixed inputs

| Item                 | Choice for the 1.1 release                                                       |
| -------------------- | -------------------------------------------------------------------------------- |
| Jedi version         | `1.1.0`, already declared in `shard.yml`.                                        |
| Release compiler     | Crystal `1.21.1`. The project declares `>= 1.21.0, < 2.0`.                       |
| Crystal dependencies | `shard.lock` versions; revisions and file hashes in `release/dependencies.json`. |
| Specs                | `TZ=UTC`; expected result: 493 examples, no failures or errors.                  |
| Public binary        | Linux x86_64, statically linked with musl, built in Alpine.                      |
| PDFs                 | Preserve supplied files; building Jedi does not require Pandoc.                  |

This is a prepared procedure. The accompanying preparation report identifies executed checks. Confirm compilation and specs on a machine with the compiler before creating the binary release.

## Local build on Ubuntu

Install **Crystal 1.21.1 and Shards** from the [official Crystal distributions](https://crystal-lang.org/releases/). Check `crystal --version` and `shards --version`. An older Ubuntu release may provide a Crystal package that is too old; check the version before continuing.

Install build dependencies:

```bash
sudo apt update
sudo apt install build-essential git python3 pkg-config \
  libgc-dev libevent-dev libpcre2-dev libyaml-dev libssl-dev \
  libsqlite3-dev zlib1g-dev gnuplot-nox
```

From the extracted or cloned source root:

```bash
bash release/build-local.sh
```

This installs locked dependencies, checks their contents and source formatting, runs all 493 specs, compiles `src/jedi_cli.cr`, then creates the release-mode `build/jedi`. It exercises installation and first use in temporary directories.

Logs are in `build/check/` and `build/smoke-local/`. Install the local binary with:

```bash
bash install.sh
```

The local binary uses its distribution's libraries. For a portable public archive, use the static build below.

## Why postinstall scripts are skipped

The prepared command is:

```bash
shards install --frozen --skip-postinstall
python3 release/verify-dependencies.py
```

The locked `textseg` and `uniwidth` releases already contain their Unicode tables, and `cryplot` contains its generated palettes. Their postinstall scripts can regenerate these from the Internet; one uses a `latest` URL. The release preserves files in the recorded revisions and compares their hashes. This fixes the input data without modifying dependencies.

Use these same inputs for release tests. Verification stops if a dependency file differs; inspect the difference before changing the manifest.

## Build the static binary

Install Docker on the build machine and check `docker version`. Crystal's [static-linking guide](https://crystal-lang.org/reference/1.21/guides/static_linking.html) recommends musl and Alpine images.

Commit the reviewed repository files. From the repository root:

```bash
bash release/build-static.sh prepare
bash release/build-static.sh build
```

`prepare` retrieves the official `crystallang/crystal:1.21.1-alpine` image, resolves its digest and adds static SQLite libraries and test tools. `build` uses the exact prepared image ID without rebuilding it. It first retrieves native-library notices from upstream versions matching the Alpine packages, so collection failures stop before specs and compilation. It then checks Crystal 1.21.1, runs source checks, compiles with `--release --static --no-debug`, inspects the ELF and exercises the real binary in Alpine with SVG gnuplot output.

The collector prefers versions of packages containing the static libraries; it does not require matching tools, such as the OpenSSL command, to be installed. The license manifest records the selected package names and versions.

Outputs include `build/static/jedi`, `build/static/BUILD-INFO.json`, logs and `build/static/licenses/native/`. The executable must be an x86_64 ELF without an interpreter or dynamic segment. A successful `--static` command alone does not establish this.

### Keep the same builder for rebuilding

First preparation downloads packages and requires Internet access. To rebuild using the same packages, preserve the prepared image and its two identity files:

```bash
docker image save "$(cat build/static/builder-id.txt)" | \
  gzip -n > build/jedi-builder-1.1.0.tar.gz
```

On another build machine:

```bash
gzip -dc build/jedi-builder-1.1.0.tar.gz | docker image load
bash release/build-static.sh build
```

Also transfer `build/static/builder-id.txt` and `build/static/base-image.txt`. The dependency manifest fixes input files; build metadata records the image and package versions. Normalized archive metadata makes packaging byte-identical for the same input files. This guide does not promise byte-identical binaries from separate compiler runs.

## Exercise the binary on the target

On Linux x86_64, with Python 3 and gnuplot available, from the prepared source tree:

```bash
python3 release/smoke.py build/static/jedi \
  --graphics --log-dir build/smoke-target
```

The scenario stages installation, adapts private launcher copies and leaves `HOME` unchanged. It uses private XDG production paths and separate test/dev paths; checks locales, help, `calc`, `play`, Demo imports, `profile`, `score`, `candidate`, `backtest` and a first fictional buy. It verifies that the buy does not appear in other databases.

Repeat this on Ubuntu under WSL2 after transferring the binary and source tree. The scenario creates SVG files without opening windows; check interactive chart display separately with `jedidemo tools plot cotations_EXA.txt`. Test API/Web collection separately with the user's settings and providers.

## Assemble releases

After checks pass:

```bash
python3 release/package.py --output dist/1.1.0
cd dist/1.1.0
sha256sum -c SHA256SUMS
```

Use an empty or new output directory. The packager requires build and smoke-test evidence matching the binary hash and current source files. It creates binary, source and documentation archives, `SHA256SUMS` and one `.sha256` file per archive.

To prepare source and documentation while no binary has been verified:

```bash
python3 release/package.py --without-binary --output dist/preparation
```

This creates no executable archive. See [PUBLISHING.md](PUBLISHING.md) for publication.
