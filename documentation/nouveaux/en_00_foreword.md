# Reading this documentation

This edition accompanies **`next-version`, in preparation for Jedi 1.1**. It includes `split + reinit=reset` and `split + reinit=merge`, together with trade and scale naming conventions. These combinations require the updated executable; the published Jedi 1.0.0 release still rejects them. Chapter 02's installation examples retain the published 1.0.0 distribution: adapt the version for a later release.

Jedi is intended for investors who want to apply and monitor a mechanical trading method. On first reading, start with [The philosophy of Jedi](en_philosophy_of_jedi.md), just before Part I: the method's principle, discipline, the investor's decisions and the limits of historical results.

## Three reading paths

**Part I**, chapters 01–10, covers practice: installing Jedi, choosing a security, studying a scale, evaluating an opening and monitoring the trade. On first use, read chapters 01 and 02, then reproduce the examples in the demonstration environment. Chapters 03–06 prepare a project; chapters 07–09 record operations. Chapter 10 explains market databases and prepares the Demo database used from chapter 04 onwards.

**Part II**, chapters 11–20, explains the rules: round trips, positions, scales, continuity, orders and capital. `tools calc` and `tools play` let you check the mechanics using chosen movements. Chapter 20 combines these ideas in a complete example.

**Part III**, chapters 21–24, organises historical studies: preparing data, backtesting, a chronological example and interpretation. It distinguishes searching for a scale, checking it on another period and monitoring dated decisions.

The appendices provide the command reference, provider configuration, the JEDI ProScreener script and a glossary. They let you find a detail without interrupting the main reading path.

## Example conventions

Commands are written for Bash on Linux or Ubuntu in WSL. Command and option names remain English whatever the language of messages. Example prices are in euros. `10%` and `0.10` express the same coefficient when a field accepts decimals or percentages.

A backslash at the end of a line continues a command on the next line. Inside quoted text, line breaks belong to the text. Where `$` and `>` are shown with input, they represent shell prompts and should not be copied.

Examples use **`jedidemo`**, the launcher installed in [chapter 02](en_02_installing_and_preparing_jedi.md). It keeps experiments in their own environment. With the supplied launchers, **`jedi` always selects production**; **`jedidev`** is for development. Copy the files from `examples/` to the demonstration directory as described in that chapter.

EXA, EXB, EXC and GAP, their identifiers and their quotations are **fictional**. The files use weekdays, including some public holidays. They help reproduce commands and amounts without representing actual investments.

Required settings appear before the examples: fees, simulation capital and main database state. An existing committed portfolio changes `candidate` reserves in particular. A creation command assumes that the object or database does not already exist.

## Finding information

Numbers identify files and cross-references. The PDF table of contents covers the three parts, 24 chapters and four appendices. French and English editions follow the same plan.

To discover the installed version's capabilities, run `jedi` without arguments, then request a subcommand's help, for example `jedi tools backtest --help`. `jedi version` shows the version; `jedi config --paths` shows the paths actually used.

Each study and trade remains understandable through its data, settings and operations. Keeping these elements lets you explain a result and resume work without having to guess earlier choices.
