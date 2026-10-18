# Jedi

[Français](README.fr.md)

**Jedi helps you manage a trade using rules chosen in advance.** It calculates the quantities and price levels to consider, keeps a record of executed operations and helps you apply the same method as prices fluctuate.

You choose the security and the rules. You place orders with your broker, check their execution and record what actually happened in Jedi. The application performs the calculations; it does not send orders to a broker.

## What you can do

- Follow trades, their settings, executed operations and notes.
- Calculate proposed orders and optional capital-management protections.
- Examine securities with `tools profile`, search for a scale with `tools score` and assess an opening with `tools candidate`.
- Explore the mechanics with `tools calc` and `tools play`, or simulate a fixed scale on historical data with `tools backtest`.
- Import OHLCV price histories into a separate market database and produce charts with gnuplot.

The [philosophy of Jedi](documentation/nouveaux/en_philosophy_of_jedi.md) explains the method and the decisions that remain yours. Historical results help you examine rules; they do not guarantee future results. All supplied example quotations are fictional.

## Start with the examples

The initial binary distribution targets **Linux x86_64**, including Ubuntu under **WSL2** on Windows. A static binary includes the SQLite library. Bash runs the launchers; gnuplot is required for charts. Crystal is needed only to build from source.

Download `jedi-1.1.0-linux-x86_64.tar.gz` and its `.sha256` file from the project's Releases page. After verifying and extracting the archive, run `bash install.sh` inside its directory. Follow [the installation guide](INSTALL.md) for the exact commands.

The installer copies fictional examples to `~/jedi-examples/` and preserves existing example files. In your terminal:

```bash
export PATH="$HOME/.local/bin:$PATH"
hash -r
jedidemo config --paths
```

At the first English-language start, answer `Y` to each creation request. Check `environment : test`. Then try a simulated rise followed by a fall:

```bash
jedidemo tools play -c o0,6-14,17 -- \
  scale=vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0,q0=100,c0=10,tick=0.01 \
  1 -1
```

| Command    | Use                                                       |
| ---------- | --------------------------------------------------------- |
| `jedi`     | Your production portfolio, using XDG locations.           |
| `jedidemo` | Fictional examples in a separate demonstration directory. |
| `jedidev`  | Development in a separate project directory.              |

Each environment also has its own market databases. The shared binary is installed at `~/.local/libexec/jedi`; launchers are at `~/.local/bin/`.

## Documentation

The manual contains a foreword, Jedi's philosophy, three parts, 24 chapters and four appendices in each language.

- [English PDF](output/pdf/jedi-1.1-en.pdf)
- [French PDF](output/pdf/jedi-1.1-fr.pdf)
- [Chapter index in both languages](documentation/README.md)
- [Example files and their use](examples/README.md)
- [Release notes](CHANGELOG.md)

## Build and contribute

Jedi is written in Crystal. The release procedure uses Crystal **1.21.1**, `TZ=UTC` for the specs and the supplied dependency lockfiles. See [building from source](BUILD.md), [contributing](CONTRIBUTING.md) and [preparing a release](PUBLISHING.md).

Jedi's code, documentation, scripts and fictional examples are distributed under the [MIT license](LICENSE), Copyright © 2026 Hubert Toullec. Dependency notices are listed in [THIRD-PARTY.md](THIRD-PARTY.md).
