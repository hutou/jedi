# Lire cette documentation

Jedi s'adresse à l'investisseur qui souhaite appliquer et suivre une méthode de trading mécanique. Pour une première lecture, commencer par [La philosophie de Jedi](philosophie_de_jedi.md), juste avant la partie I : principe de la méthode, discipline, décisions de l'investisseur et limites des résultats historiques.

## Trois parcours de lecture

La **partie I**, chapitres 01 à 10, accompagne la pratique : installer Jedi, choisir un titre, étudier un barème, évaluer une ouverture et suivre le trade. Pour une première utilisation, lire les chapitres 01 et 02, puis reproduire les exemples dans l'espace de démonstration. Les chapitres 03 à 06 préparent un projet ; les chapitres 07 à 09 enregistrent des opérations. Le chapitre 10 explique les bases de cotations et prépare la base Demo utilisée dès le chapitre 04.

La **partie II**, chapitres 11 à 20, explique les règles : allers-retours, positions, barèmes, continuité, ordres et capital. Les commandes `tools calc` et `tools play` permettent de vérifier la mécanique avec des mouvements choisis. Le chapitre 20 rassemble ces notions dans un parcours complet.

La **partie III**, chapitres 21 à 24, organise les études historiques : préparation des données, backtest, exemple chronologique et interprétation. Elle distingue la recherche d'un barème, sa vérification sur une autre période et le suivi de décisions datées.

Les annexes regroupent la référence des commandes, la configuration des fournisseurs, le script ProScreener JEDI et le glossaire. Elles permettent de retrouver un détail sans interrompre la lecture principale.

## Conventions des exemples

Les commandes sont écrites pour Bash sous Linux ou Ubuntu dans WSL. Les noms de commandes et d'options restent en anglais, quelle que soit la langue des messages. Les prix des exemples sont en euros. `10%` et `0.10` expriment un même coefficient lorsque le champ accepte une valeur décimale ou un pourcentage.

Une barre oblique inverse en fin de ligne prolonge une commande sur la ligne suivante. Dans un texte entre guillemets, les retours à la ligne font partie du texte. Les signes `$` et `>` montrés avec certaines saisies représentent les invites du terminal et ne sont pas à recopier.

Les exemples emploient **`jedidemo`**, le lanceur installé au [chapitre 02](02_installer_et_preparer_jedi.md). Il conserve les essais dans leur propre espace. Avec les lanceurs fournis, **`jedi` désigne toujours la production** ; **`jedidev`** sert aux développements. Les fichiers de `examples/` sont copiés dans le dossier de démonstration selon ce chapitre.

Les titres EXA, EXB, EXC et GAP, leurs identifiants et leurs cotations sont **fictifs**. Le calendrier des fichiers retient les jours de semaine, y compris certains jours fériés. Ils servent à reproduire les commandes et les montants, sans représenter un investissement réel.

Les réglages nécessaires sont indiqués avant les exemples : frais, capital de simulation et état de la base principale. Un portefeuille déjà engagé change notamment les réserves de `candidate`. Une commande de création suppose que l'objet ou la base n'existe pas encore.

## Retrouver une information

Les numéros identifient les fichiers et les renvois. Dans les PDF, le sommaire reprend les trois parties, les 24 chapitres et les quatre annexes. Les versions française et anglaise suivent le même plan.

Pour connaître les possibilités de la version installée, lancer `jedi` sans argument, puis demander l'aide d'une sous-commande, par exemple `jedi tools backtest --help`. `jedi version` affiche la version ; `jedi config --paths` affiche les chemins réellement utilisés.

Chaque étude et chaque trade restent lisibles grâce à leurs données, leurs paramètres et leurs opérations. Conserver ces éléments permet d'expliquer un résultat et de reprendre le travail sans devoir deviner les choix antérieurs.
