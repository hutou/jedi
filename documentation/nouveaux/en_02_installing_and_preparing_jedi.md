# Installing and preparing Jedi

## Choose your environment

Jedi runs in a terminal. The distribution format chosen for Jedi 1.1 is an archive containing a statically compiled Linux executable for **x86-64** processors. Users do not need to install Crystal or compile the sources to use that executable.

| Environment                        | Intended use for Jedi 1.1                                 |
| ---------------------------------- | --------------------------------------------------------- |
| Linux x86-64                       | Linux executable supplied in the release archive.         |
| Windows x86-64                     | The same executable in a Linux distribution under WSL 2.  |
| Native Windows, Linux ARM64, macOS | No executable distributed through this installation path. |

SQLite is included in the static binary. **gnuplot** remains an external program needed for graphical functions. Management, selection and simulation commands can be used without producing a chart.

## Install the executable on Linux

Check your computer's architecture:

```bash
uname -m
```

The executable described here requires `x86_64`. Download the binary archive and its checksum file from **Releases in the Jedi project repository**. The automatic “Source code” archive contains sources to compile; choose the executable archive.

The commands below use the convention `jedi-1.1.0-linux-x86_64.tar.gz`, with an extracted directory of the same name without `.tar.gz`. Adjust the version and names if your downloaded release specifies different ones. From the download directory:

```bash
jedi_version="1.1.0"
jedi_archive="jedi-${jedi_version}-linux-x86_64.tar.gz"
sha256sum -c "${jedi_archive}.sha256"
```

The check must report `OK`. If it fails, download again before proceeding.

Install the binary for your own account without administrator privileges:

```bash
tar -xzf "$jedi_archive"
mkdir -p "$HOME/.local/libexec" "$HOME/.local/bin"
install -m 0755 "jedi-${jedi_version}-linux-x86_64/jedi" \
  "$HOME/.local/libexec/jedi"
```

**Then install the three launchers**, supplied in [examples/launchers/](../../examples/launchers/jedi) in the documentation archive. From its `examples/` directory:

```bash
install -m 0755 launchers/jedi "$HOME/.local/bin/jedi"
install -m 0755 launchers/jedidemo "$HOME/.local/bin/jedidemo"
install -m 0755 launchers/jedidev "$HOME/.local/bin/jedidev"
export PATH="$HOME/.local/bin:$PATH"
hash -r
command -v jedi
command -v jedidemo
command -v jedidev
```

The displayed paths must identify the three files in `~/.local/bin/`. If `jedi` is already defined as an alias or function, remove that definition to use the installed launcher. `type -a jedi` shows the definitions found.

The compiled binary is in **`~/.local/libexec/jedi`**. The three small scripts in **`~/.local/bin/`** call it directly: `jedi` for your real portfolio, `jedidemo` for examples and `jedidev` for development. Run them as ordinary commands; they refuse to be sourced.

Launcher names, comments and messages are in English in both documentation editions. Two messages identify errors specific to these scripts:

| Message                                            | Action                                                                                    |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `Jedi binary missing or not executable`            | Check the binary's installation in `~/.local/libexec/jedi` and its executable permission. |
| `Run this launcher as a command; do not source it` | Call `jedi`, `jedidemo` or `jedidev` directly in the terminal.                            |

To keep the search path across Bash sessions, add `export PATH="$HOME/.local/bin:$PATH"` to `~/.bashrc`. Run everyday Jedi commands under your user account.

For graphical functions, check:

```bash
command -v gnuplot
gnuplot --version
```

Install the `gnuplot` package with your distribution's package manager if needed.

## On Windows, use the WSL Linux terminal

Jedi runs in Ubuntu under WSL 2. Keep the two terminals distinct:

| Terminal               | Commands in this chapter                                              |
| ---------------------- | --------------------------------------------------------------------- |
| PowerShell, on Windows | Installing and opening WSL; commands starting with `wsl`.             |
| Ubuntu, on Linux       | Installing Jedi, directories, configuration and every `jedi` command. |

### Install Ubuntu and open the right terminal

The following procedure applies to Windows 11 or Windows 10 version 2004 and later. It has two stages: enable the Windows components WSL needs, then install the Ubuntu Linux distribution.

In **PowerShell opened as administrator**, first enable WSL:

```powershell
wsl --install
```

If Ubuntu opens directly, create the Linux account as explained below. If Windows requests a restart, restart before continuing.

**After restarting, check the installation.** Reopen PowerShell under the same Windows account:

```powershell
wsl --list --verbose
```

If Ubuntu appears in the list, continue with account creation and the version check. If the message says that no distribution is installed, reopen PowerShell as administrator and **run the installation again**:

```powershell
wsl --install -d Ubuntu
```

The first command may have stopped after enabling `VirtualMachinePlatform`, which requires a restart. Its success message then concerns that activation; it does not prove that Ubuntu is installed. Now wait for the distribution download and installation. If another restart is requested, restart and check the list again.

Until Ubuntu is installed, `wsl -d Ubuntu` cannot open it and returns `WSL_E_DISTRO_NOT_FOUND`. This command opens an existing distribution; it does not install one. The [Microsoft procedure](https://learn.microsoft.com/en-us/windows/wsl/install) describes distribution installation.

**Create the Linux account on first launch.** Ubuntu may open automatically when installation finishes. Create a Linux username and password. This account is separate from the Windows account; the typed password is not displayed. [Linux account setup](https://learn.microsoft.com/en-us/windows/wsl/setup/environment) details this step.

Once the account is created, Ubuntu's prompt may look like `user@computer:~$`. Commands entered there are Linux commands. To return to PowerShell and check the installation, enter this in Ubuntu:

```bash
exit
```

In PowerShell, check the list:

```powershell
wsl --list --verbose
```

An **Ubuntu** row must now appear, with **2** in the `VERSION` column. Its state may be `Running` or `Stopped`; both indicate an installed distribution. For a newly installed Ubuntu distribution still on version 1, run `wsl --set-version Ubuntu 2` from PowerShell to convert it.

Then open Ubuntu from PowerShell:

```powershell
wsl -d Ubuntu
```

If the Linux account has not yet been created, create it on this first launch. If the name shown in the list differs from Ubuntu, use that name in commands. The [WSL reference](https://learn.microsoft.com/en-us/windows/wsl/basic-commands) describes listing and opening distributions.

All following steps take place **in Ubuntu**, using the Linux account created. Return to its home directory:

```bash
cd ~
echo "$HOME"
```

A path such as `/home/user` identifies this Linux home directory. It differs from `C:\Users\...` on Windows.

### Prepare the language in Ubuntu

A fresh Ubuntu installation may use `LANG=C.UTF-8`. This locale is a neutral system setting with UTF-8. To choose French or English and prepare the examples, install the locales in **the Ubuntu terminal**:

```bash
sudo apt update
sudo apt install locales
sudo dpkg-reconfigure locales
```

In the displayed list, select these entries with **Space**:

| Locale to generate  | Use                     |
| ------------------- | ----------------------- |
| `fr_FR.UTF-8 UTF-8` | French, France.         |
| `en_US.UTF-8 UTF-8` | English, United States. |

Use **Tab** to reach the confirmation button, then **Enter**. When asked for the default locale, choose **en_US.UTF-8** for the English reading path, or **fr_FR.UTF-8** for the French path. Wait for generation to finish.

Check the available locales:

```bash
locale -a
```

Their names may appear as `fr_FR.utf8` and `en_US.utf8`. Generation makes these locales available; it does not necessarily change the language of the terminal already open. To use English in this session:

```bash
export LANG=en_US.UTF-8
locale
```

For French, use `export LANG=fr_FR.UTF-8`. Check the `LANG` line in the `locale` output. Jedi uses this variable with its system language setting; installing locales and choosing `LANG` are separate operations.

The **Find the program and editor in future sessions** section below preserves this choice in `~/.bashrc`. Ubuntu's references on [locale generation](https://manpages.ubuntu.com/manpages/noble/man8/locale-gen.8.html) and [inspection](https://manpages.ubuntu.com/manpages/noble/man1/locale.1.html) describe these commands.

### Prepare Jedi's directories in Ubuntu

A fresh Ubuntu installation may not yet contain the XDG directories Jedi uses. Creating them explicitly makes its file locations clear:

```bash
mkdir -p "$HOME/.config/jedi"
mkdir -p "$HOME/.local/state/jedi"
mkdir -p "$HOME/.local/share/jedi/market"
mkdir -p "$HOME/.local/bin" "$HOME/.local/libexec"
mkdir -p "$HOME/jedi-examples"
```

| Directory                     | Jedi file or use                                          |
| ----------------------------- | --------------------------------------------------------- |
| `~/.config/jedi/`             | Configuration `jedi.conf`.                                |
| `~/.local/state/jedi/`        | Log `jedi.log`.                                           |
| `~/.local/share/jedi/`        | Main database `jedi.db`.                                  |
| `~/.local/share/jedi/market/` | Historical market databases.                              |
| `~/.local/bin/`               | Public launchers `jedi`, `jedidemo`, `jedidev`.           |
| `~/.local/libexec/`           | Compiled `jedi` binary called by the launchers.           |
| `~/jedi-examples/`            | Suggested working directory for tests and supplied files. |

You do not need to define `XDG_CONFIG_HOME`, `XDG_STATE_HOME` or `XDG_DATA_HOME`. When absent, Jedi uses `~/.config`, `~/.local/state` and `~/.local/share` respectively, followed by their `jedi` subdirectory. It can also create missing parent directories during initialisation.

If XDG variables are already defined, paths may differ. The public `jedi` launcher uses these production paths and clears inherited `JEDI_*` path overrides. Check the effective locations with `jedi config --paths` after installation. `jedidemo` and `jedidev` select their own local environments, explained below.

### Install the program and useful tools

Create a Linux directory for the downloaded binary archive and its checksum file:

```bash
mkdir -p "$HOME/telechargements-jedi"
cd "$HOME/telechargements-jedi"
explorer.exe .
```

Windows Explorer opens this Linux directory. Copy both files downloaded on Windows into it. Return to Ubuntu and follow **Install the executable on Linux**, above, starting with the `sha256sum` check. Keep databases and experiments in the Linux filesystem, following [Microsoft's guidance](https://learn.microsoft.com/en-us/windows/wsl/filesystems).

Also install an editor and the graphics program in Ubuntu:

```bash
sudo apt update
sudo apt install gnuplot nano
```

The requested password is the Linux account's password. Run subsequent Jedi commands using that account.

### Find the program and editor in future sessions

In Ubuntu, open the terminal's startup file:

```bash
nano "$HOME/.bashrc"
```

Append these four lines. The last one selects English for this terminal:

```bash
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nano
export VISUAL=nano
export LANG=en_US.UTF-8
```

In nano, save with **Ctrl+O**, confirm the filename with **Enter**, then exit with **Ctrl+X**. Reload the settings in the current terminal and check:

```bash
source "$HOME/.bashrc"
command -v jedi
command -v nano
jedi version
jedi config --paths
```

At Jedi's first launch, explicitly accept file creation as explained in the next section. The editor will serve `note create --edit` and `note update --edit`, described in [chapter 08](en_08_monitoring_a_trade.md#write-with-an-editor).

### Find files from Windows

To open the configuration directory in Explorer:

```bash
cd "$HOME/.config/jedi"
explorer.exe .
```

Explorer also provides access through `\\wsl$`, then the distribution and its `home` directory. Paths displayed by `jedi config --paths` remain Linux paths for the Ubuntu terminal. Copy the documentation archive's `examples/` files to `~/jedi-examples/` for tests; the [example guide](../../examples/README.md#english) identifies the databases to prepare.

## Run Jedi for the first time

```console
jedi version
```

This command displays the Jedi version and compilation information. At first launch it asks to create the configuration, log and main database in that order. **Explicitly answer `Y`** to each English prompt, or `O` in French.

The main database starts empty. It will hold securities, scales, trades, settings, operations and notes. Historical market databases are prepared separately in [chapter 10](en_10_market_database.md).

Display the locations actually used:

```console
jedi config --paths
```

| Item             | Usual Linux location           |
| ---------------- | ------------------------------ |
| Configuration    | `~/.config/jedi/jedi.conf`     |
| Log              | `~/.local/state/jedi/jedi.log` |
| Main database    | `~/.local/share/jedi/jedi.db`  |
| Market databases | `~/.local/share/jedi/market/`  |

System XDG variables can change these locations. Use the paths shown by `config --paths` for your backups.

## Choose language and settings

With its default system language setting, Jedi uses French when `LANG` specifies French and English for other supported language values. To choose a command's language:

```bash
LANG=fr_FR.UTF-8 jedi version
LANG=en_US.UTF-8 jedi version
```

The `jedi.conf` file can remain empty: the program includes default settings. Add only the values you need to change. View the effective configuration with:

```console
jedi config
```

It can contain access keys for providers you have configured. Check its contents before sharing it.

These **fictional** settings are used for the trade in chapters 07–09. Put them in the experiment environment's `jedi_test.conf`, described below, to reproduce the walkthrough:

```yaml
fees:
  rate: 0.0035
  min: 0.0
trading:
  capital: 5000.0
market_data:
  default_universe: france
```

Here `fees.rate` means 0.35% and `fees.min` is the minimum per operation. `trading.capital` is the reference capital dedicated to trades. For actual use, enter your own amounts and fees. Simulation settings are separate from capital used for real trade management.

Command options override the settings they address: for example, `candidate --capital=...` uses that capital for the evaluation; it does not change `trading.capital`. File changes are read at the next launch.

## Prepare a separate experiment environment

With the launchers installed above, **the command name selects the environment**:

| Command    | Use                                      | Default location                                                                      |
| ---------- | ---------------------------------------- | ------------------------------------------------------------------------------------- |
| `jedi`     | Real portfolio.                          | `jedi.conf`, `jedi.log`, `jedi.db` and market databases at the XDG locations.         |
| `jedidemo` | Documentation exercises.                 | Configuration, log, `jedi_test.db` and market under `~/jedi-examples/jedi/env_test/`. |
| `jedidev`  | Development and contributor experiments. | `jedi_dev.*` files and market in the project's `env_dev` environment.                 |

The first two commands are enough to use Jedi and learn with the examples. Commands behave as usual; their files are separate.

There is no terminal environment to switch. You can call `jedi`, then `jedidemo`, then `jedi` again. **`jedi` always uses production**; its launcher forces that choice and removes inherited `JEDI_*` path settings in its own process. XDG paths remain those of the system.

### Copy the example files

From the documentation archive's `examples/` directory:

```bash
mkdir -p "$HOME/jedi-examples"
cp *.txt "$HOME/jedi-examples/"
jedidemo config --paths
```

At first launch, explicitly accept creation of the configuration, log and main database: `Y` in English, `O` in French. Check that `environment` shows **`test`** and record the paths:

| Experiment item  | Default location                                    |
| ---------------- | --------------------------------------------------- |
| Configuration    | `~/jedi-examples/jedi/env_test/conf/jedi_test.conf` |
| Log              | `~/jedi-examples/jedi/env_test/log/jedi_test.log`   |
| Main database    | `~/jedi-examples/jedi/env_test/data/jedi_test.db`   |
| Market databases | `~/jedi-examples/jedi/env_test/market/`             |

Add the fictional settings from the previous section to **`jedi_test.conf`** at the displayed path. Example commands in the following chapters use **`jedidemo`**. For commands studying an actual source, first prepare its histories in this environment's market directory.

```console
jedidemo trade list
```

The launcher opens `~/jedi-examples/` for Jedi, so filenames such as `cotations_EXA.txt` work from any terminal directory. Relative paths passed to `jedidemo` are read from that directory, including files to import or export. Use an absolute path for a file elsewhere. Redirections such as `> backup.txt` are performed by the terminal in its own directory; an absolute path avoids ambiguity.

The script's `cd` affects only the launcher and Jedi process. **The calling terminal keeps its directory and variables.** The launchers also retain its language, editor and time zone. To reproduce a calculation explicitly in UTC for one command:

```bash
TZ=UTC jedidemo version
```

### Alternate between portfolio and demonstration

```console
jedi trade list
jedidemo trade list
jedi config --paths
jedidemo config --paths
```

The first list concerns your real portfolio; the second concerns fictional trades. The last two commands show each environment's paths. Databases remain in place: `jedidemo` resumes the same examples at the next launch.

### Keep several experiment environments

Each directory can have its own test database and market. For example, keep chapters 03–06's evaluations without trades in the usual environment, then create another one for chapters 07–09's openings:

```bash
mkdir -p "$HOME/jedi-examples-trades"
cp "$HOME/jedi-examples/"*.txt "$HOME/jedi-examples-trades/"
JEDI_DEMO_DIR="$HOME/jedi-examples-trades" jedidemo config --paths
```

This first Jedi command initialises the other environment after your confirmations. Use the same **`JEDI_DEMO_DIR=...`** prefix for every command using it:

```bash
JEDI_DEMO_DIR="$HOME/jedi-examples-trades" jedidemo trade list
jedidemo trade list
```

The first line uses the second environment; the next resumes the usual one. To choose another demonstration directory permanently, add `export JEDI_DEMO_DIR="..."` to `~/.bashrc`. It customises `jedidemo`; `jedi` remains production.

From an experiment directory you have already created, you can also run:

```bash
JEDI_DEMO_DIR="$PWD" jedidemo config --paths
```

In a directory called `experiment`, files are under `experiment/jedi/env_test/`. If the directory is already named `jedi`, they are under `jedi/env_test/`, without repeating that name.

### Optionally choose another market

The demonstration market is local to the environment by default. To deliberately use an existing market directory:

```bash
JEDI_DEMO_MARKET_DIR="/path/to/market" \
  jedidemo market info abcbourse
```

Replace the path and source with those of your data. Only market databases are then shared; the main test database remains in the selected environment. `market import`, `update`, `replace` and `group` act on the selected market, so use a separate market for exercises that modify data.

A relative `JEDI_DEMO_MARKET_DIR` is read from the demonstration directory. Launchers clear the general `JEDI_MARKET_DIR` variable; deliberate selection uses `JEDI_DEMO_MARKET_DIR` or `JEDI_DEV_MARKET_DIR`.

## For developers: use jedidev

This section is optional for users of the supplied binary. Contributors install **Crystal 1.21.1** and **Shards** following the [official Crystal instructions](https://crystal-lang.org/install/), then work from the source root.

The `jedidev` launcher uses the current directory as its project, or the one supplied in `JEDI_DEV_DIR`. It selects `dev` mode and keeps configuration, log, main database and market databases separate:

```console
jedidev config --paths
```

If the project is named `jedi`, its database is `<project>/env_dev/data/jedi_dev.db` and market `<project>/env_dev/market/`. With another directory name, they are under `<project>/jedi/env_dev/`.

To install dependencies, check sources and compile a working binary:

```bash
shards install
crystal tool format --check src spec
TZ=UTC crystal spec
mkdir -p bin
crystal build src/jedi_cli.cr --error-trace -o bin/jedi-dev
chmod +x bin/jedi-dev
JEDI_DEV_BINARY="./bin/jedi-dev" jedidev config --paths
```

Compilation also requires the dependencies' development libraries, including SQLite. Package names depend on the distribution. Tests run in UTC to reproduce the validation dates.

`JEDI_DEV_BINARY` selects the compiled binary for that command. Without it, `jedidev` calls the binary installed in `~/.local/libexec/jedi`. Its relative path is read from the selected project. To call from another directory, supply both paths:

```bash
JEDI_DEV_DIR="/path/to/project" \
  JEDI_DEV_BINARY="./bin/jedi-dev" jedidev version
```

`JEDI_DEV_MARKET_DIR` deliberately selects another market, as for demonstration. For real portfolio monitoring, use the `jedi` launcher.

## Compile quickly during development

Compile without `--release` for everyday changes. For performance measurements and final checks, compile with `--release`. Both commands use `src/jedi_cli.cr`; the database environment is selected when running through `jedi`, `jedidemo` or `jedidev`.

```bash
mkdir -p bin
crystal build src/jedi_cli.cr --error-trace -o bin/jedi-dev
crystal build src/jedi_cli.cr --release --error-trace -o bin/jedi
```

Two small Bash scripts, `build-dev` and `build-release`, can wrap these commands. They produce separate files under `bin/`. Keep generated binaries outside versioned source files.

From the project root, select the development binary for this terminal:

```bash
export JEDI_DEV_BINARY=./bin/jedi-dev
jedidev config --paths
jedidev trade list
```

Rerun the quick compilation after a source change. Before final validation, also run `TZ=UTC crystal spec --release`, then build the optimised executable. Local compilation follows the host's libraries; the distributable static binary is built by the publication procedure.

## Back up and recover data

Between Jedi commands, with none running, back up the configuration and databases listed by `config --paths` for every environment you need. Copying configuration and data directories retains the main database and market databases. Also retain original files and lists needed to rebuild them. The log can help investigate an incident.

Jedi additionally provides an export of the **main database**, including notes and recorded quotations. Here the production file is written to the chosen absolute path:

```bash
jedi database dump > "$HOME/jedi-sauvegarde.txt"
```

This export contains neither `jedi.conf` nor market databases. To test restoration, create a new directory and initialise its main database:

```bash
mkdir -p "$HOME/jedi-restauration"
JEDI_DEMO_DIR="$HOME/jedi-restauration" jedidemo config --paths
JEDI_DEMO_DIR="$HOME/jedi-restauration" \
  jedidemo database load "$HOME/jedi-sauvegarde.txt"
JEDI_DEMO_DIR="$HOME/jedi-restauration" jedidemo trade list
JEDI_DEMO_DIR="$HOME/jedi-restauration" jedidemo note list
```

**`load` requires a completely empty database**, including notes. It does not merge the export into an existing portfolio. Check trades, operations, notes and settings before resuming. The `jedi` launcher resumes your real portfolio; `jedidemo` without this prefix resumes the usual demonstration. To restore copied files, return each file to its intended location with no Jedi command running.

Under WSL, you can also create a complete distribution copy from PowerShell:

```powershell
wsl --shutdown
wsl --export Ubuntu jedi-wsl-backup.tar
```

Adjust the distribution name. The [Microsoft reference](https://learn.microsoft.com/en-us/windows/wsl/basic-commands) describes distribution export and import.

## Update Jedi

Back up data, read release notes, then verify and install the new executable using the procedure above. Replacing the program retains your environment files. After installation, check `jedi version`, `jedi config --paths` and a few known records.

You can now [choose a security](en_03_choosing_a_security.md), or go directly to [EXA's fictional opening](en_07_opening_a_trade.md).
