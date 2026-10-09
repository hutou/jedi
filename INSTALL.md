# Install Jedi 1.0

This guide uses the **binary** archive `jedi-1.0.0-linux-x86_64.tar.gz`. The source archive is intended for compilation and does not contain an already compiled executable.

## On Linux

Open a terminal and check your architecture:

```bash
uname -m
```

The output must be `x86_64`. Install and run Jedi with your usual user account.

Install gnuplot for charts. On Ubuntu:

```bash
sudo apt update
sudo apt install gnuplot
```

The static binary includes the SQLite library. The `sqlite3` command is not required to use Jedi. You can install it separately to inspect a database: `sudo apt install sqlite3`.

In the directory containing the archive and its checksum file downloaded from Releases:

```bash
sha256sum -c jedi-1.0.0-linux-x86_64.tar.gz.sha256
tar -xzf jedi-1.0.0-linux-x86_64.tar.gz
cd jedi-1.0.0-linux-x86_64
bash install.sh
export PATH="$HOME/.local/bin:$PATH"
hash -r
type -a jedi jedidemo jedidev
```

The checksum result must say `OK`. The commands found must point to the launchers in `~/.local/bin/`. If an alias or function is already named `jedi`, remove that definition from the shell file where it was created.

To keep the search path between Bash sessions, add this line once to `~/.bashrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

The installer places the binary at `~/.local/libexec/jedi`, the three launchers in `~/.local/bin/` and TXT examples in `~/jedi-examples/`. It preserves existing example files. To review an original example, read it in the archive's `examples/` directory.

## First demonstration

```bash
jedidemo config --paths
jedidemo version
```

On first start, Jedi asks to create its demonstration configuration, log and database. Answer **`Y`** to each English prompt. `LANG=C.UTF-8` selects English. If creation is declined, initialization stops; run the command again to resume it.

Check `environment : test` and paths under `~/jedi-examples/jedi/env_test/`. Then try:

```bash
jedidemo tools play -c o0,6-14,17 -- \
  scale=vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0,q0=100,c0=10,tick=0.01 \
  1 -1
```

This scenario explains the mechanics without recording an operation. To import fictional quotations into Demo, follow [the beginning of chapter 10](documentation/nouveaux/en_10_market_database.md). Run `market init demo` only once for a new database.

## Use your production portfolio

```bash
jedi config --paths
jedi version
```

`jedi` forces production and clears inherited `JEDI_*` path overrides. It respects XDG locations: by default `~/.config/jedi/`, `~/.local/state/jedi/` and `~/.local/share/jedi/`. On first start it offers to create its files. Check these locations before preparing real trades.

`jedidemo` uses separate demonstration data, including market databases. To prepare another space:

```bash
mkdir -p "$HOME/jedi-another-demo"
cp examples/*.txt "$HOME/jedi-another-demo/"
JEDI_DEMO_DIR="$HOME/jedi-another-demo" jedidemo config --paths
```

Use the same prefix for subsequent commands in that space. [Chapter 02](documentation/nouveaux/en_02_installing_and_preparing_jedi.md) describes `jedidev` and deliberately shared market locations.

## On Windows, use Ubuntu under WSL2

In an administrator PowerShell window:

```powershell
wsl --install
```

Restart Windows if requested. Then check from PowerShell:

```powershell
wsl --list --verbose
```

If Ubuntu is not installed, run `wsl --install -d Ubuntu` as administrator. Create the Linux account at Ubuntu's first start. The list must show Ubuntu with `2` in the `VERSION` column. If necessary, convert it using `wsl --set-version Ubuntu 2`, then open it with `wsl -d Ubuntu`.

Perform this guide's Linux steps **in the Ubuntu terminal**. [Chapter 02](documentation/nouveaux/en_02_installing_and_preparing_jedi.md) explains directories, locales and transferring the download from Windows. Microsoft's [WSL installation guide](https://learn.microsoft.com/en-us/windows/wsl/install) describes the Windows steps.

## Update or remove the programs

A new installation replaces the binary and launchers. It preserves configuration, databases, logs and existing examples. Back up databases using the manual's commands before an update.

To remove the installed programs:

```bash
rm -- "$HOME/.local/bin/jedi" "$HOME/.local/bin/jedidemo" \
  "$HOME/.local/bin/jedidev" "$HOME/.local/libexec/jedi"
```

This command preserves data. Keep release archives if you want to reinstall the same version.
