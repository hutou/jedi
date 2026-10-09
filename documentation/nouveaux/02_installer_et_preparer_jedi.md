# Installer et préparer Jedi

## Choisir son environnement

Jedi s'utilise dans un terminal. Le mode de diffusion retenu pour Jedi 1.0 est une archive contenant un exécutable Linux pour processeur **x86-64**, compilé statiquement. L'utilisateur n'a pas besoin d'installer Crystal ni de compiler les sources pour employer cet exécutable.

| Environnement | Utilisation prévue pour Jedi 1.0 |
|---|---|
| Linux x86-64 | Exécutable Linux fourni dans l'archive de version. |
| Windows x86-64 | Même exécutable dans une distribution Linux sous WSL 2. |
| Windows natif, Linux ARM64, macOS | Aucun exécutable distribué dans ce parcours d'installation. |

La bibliothèque SQLite est intégrée au binaire statique. **gnuplot** reste un programme externe, nécessaire aux fonctions graphiques. Les commandes de gestion, de sélection et de simulation peuvent être utilisées sans produire de graphique.

## Installer l'exécutable sous Linux

Vérifier l'architecture du poste :

~~~bash
uname -m
~~~

L'exécutable décrit ici demande une sortie `x86_64`. Télécharger l'archive binaire et son fichier de contrôle depuis la rubrique **Releases du dépôt du projet Jedi**. L'archive automatique « Source code » contient le code à compiler ; choisir l'archive de l'exécutable.

Les commandes suivantes utilisent la convention `jedi-1.0.0-linux-x86_64.tar.gz`, avec un répertoire extrait de même nom sans `.tar.gz`. Adapter le numéro et les noms si la livraison téléchargée les précise autrement. Depuis le répertoire du téléchargement :

~~~bash
jedi_version="1.0.0"
jedi_archive="jedi-${jedi_version}-linux-x86_64.tar.gz"
sha256sum -c "${jedi_archive}.sha256"
~~~

Le contrôle doit indiquer `OK`. En cas d'échec, reprendre le téléchargement avant de poursuivre.

Installer le binaire pour son propre compte, sans droits d'administration :

~~~bash
tar -xzf "$jedi_archive"
mkdir -p "$HOME/.local/libexec" "$HOME/.local/bin"
install -m 0755 "jedi-${jedi_version}-linux-x86_64/jedi" \
  "$HOME/.local/libexec/jedi"
~~~

**Installer ensuite les trois lanceurs**, livrés dans [examples/launchers/](../../examples/launchers/jedi) de l'archive documentaire. Depuis son répertoire `examples/` :

~~~bash
install -m 0755 launchers/jedi "$HOME/.local/bin/jedi"
install -m 0755 launchers/jedidemo "$HOME/.local/bin/jedidemo"
install -m 0755 launchers/jedidev "$HOME/.local/bin/jedidev"
export PATH="$HOME/.local/bin:$PATH"
hash -r
command -v jedi
command -v jedidemo
command -v jedidev
~~~

Les chemins affichés doivent désigner les trois fichiers dans `~/.local/bin/`. Si `jedi` est déjà défini comme un alias ou une fonction, retirer cette définition pour employer le lanceur installé. `type -a jedi` permet de voir les définitions trouvées.

Le binaire compilé est dans **`~/.local/libexec/jedi`**. Les trois petits scripts dans **`~/.local/bin/`** l'appellent directement : `jedi` pour le portefeuille réel, `jedidemo` pour les exemples et `jedidev` pour le développement. Ils s'exécutent comme des commandes ordinaires et refusent une utilisation avec `source`.

Les noms, commentaires et messages des lanceurs sont en anglais dans les deux éditions de la documentation. Deux messages signalent les erreurs propres à ces scripts :

| Message | Action |
|---|---|
| `Jedi binary missing or not executable` | Vérifier l'installation du binaire dans `~/.local/libexec/jedi` et son droit d'exécution. |
| `Run this launcher as a command; do not source it` | Appeler `jedi`, `jedidemo` ou `jedidev` directement dans le terminal. |

Pour conserver le chemin de recherche entre les sessions Bash, ajouter la ligne `export PATH="$HOME/.local/bin:$PATH"` à `~/.bashrc`. Les commandes d'usage courant de Jedi s'exécutent avec votre compte utilisateur.

Pour les fonctions graphiques, vérifier :

~~~bash
command -v gnuplot
gnuplot --version
~~~

Installer le paquet `gnuplot` avec le gestionnaire de paquets de la distribution si nécessaire.

## Sous Windows, utiliser le terminal Linux de WSL

Jedi s'exécute dans Ubuntu sous WSL 2. Garder les deux terminaux bien distincts :

| Terminal | Commandes de ce chapitre |
|---|---|
| PowerShell, côté Windows | Installation et ouverture de WSL ; commandes commençant par `wsl`. |
| Ubuntu, côté Linux | Installation de Jedi, répertoires, configuration et toutes les commandes `jedi`. |

### Installer Ubuntu et ouvrir le bon terminal

La procédure suivante concerne Windows 11 ou Windows 10 version 2004 et ultérieure. Elle comporte deux étapes : activer les composants Windows nécessaires à WSL, puis installer la distribution Linux Ubuntu.

Dans **PowerShell ouvert en administrateur**, commencer par activer WSL :

~~~powershell
wsl --install
~~~

Si Ubuntu s'ouvre directement, créer le compte Linux comme expliqué ci-dessous. Si Windows demande un redémarrage, redémarrer avant de poursuivre.

**Après le redémarrage, vérifier l'installation.** Rouvrir PowerShell avec le même compte Windows :

~~~powershell
wsl --list --verbose
~~~

Si Ubuntu apparaît dans la liste, passer à la création du compte et au contrôle de la version. Si le message indique qu'aucune distribution n'est installée, rouvrir PowerShell en administrateur et **relancer l'installation** :

~~~powershell
wsl --install -d Ubuntu
~~~

La première commande peut s'être arrêtée après l'activation de `VirtualMachinePlatform`, qui exige un redémarrage. Le message de réussite concerne alors cette activation ; il ne prouve pas qu'Ubuntu est installé. Attendre maintenant le téléchargement et l'installation de la distribution. Si un nouveau redémarrage est demandé, l'effectuer puis vérifier à nouveau la liste.

Tant qu'Ubuntu n'est pas installé, `wsl -d Ubuntu` ne peut pas l'ouvrir et renvoie `WSL_E_DISTRO_NOT_FOUND`. Cette commande ouvre une distribution existante ; elle ne l'installe pas. La [procédure Microsoft en français](https://learn.microsoft.com/fr-fr/windows/wsl/install) décrit l'installation d'une distribution.

**Créer le compte Linux au premier lancement.** Ubuntu peut s'ouvrir automatiquement à la fin de son installation. Créer alors un nom d'utilisateur et un mot de passe Linux. Ce compte est distinct du compte Windows ; le mot de passe saisi ne s'affiche pas. La [création du compte Linux](https://learn.microsoft.com/fr-fr/windows/wsl/setup/environment) détaille cette étape.

Une fois le compte créé, l'invite d'Ubuntu peut ressembler à `user@ordinateur:~$`. Les commandes saisies à cet endroit sont des commandes Linux. Pour revenir à PowerShell et vérifier l'installation, saisir dans Ubuntu :

~~~bash
exit
~~~

Dans PowerShell, contrôler la liste :

~~~powershell
wsl --list --verbose
~~~

Une ligne **Ubuntu** doit maintenant apparaître, avec **2** dans la colonne `VERSION`. L'état peut être `Running` ou `Stopped` ; les deux indiquent que la distribution est installée. Pour une distribution Ubuntu nouvellement installée qui serait encore en version 1, la conversion s'effectue depuis PowerShell avec `wsl --set-version Ubuntu 2`.

Ouvrir ensuite Ubuntu depuis PowerShell :

~~~powershell
wsl -d Ubuntu
~~~

Si le compte Linux n'avait pas encore été créé, le créer à ce premier lancement. Si le nom affiché dans la liste diffère d'Ubuntu, employer ce nom dans les commandes. La [référence WSL en français](https://learn.microsoft.com/fr-fr/windows/wsl/basic-commands) décrit la consultation et l'ouverture des distributions.

Toutes les étapes suivantes se font **dans Ubuntu**, avec le compte Linux créé. Revenir dans son répertoire personnel :

~~~bash
cd ~
echo "$HOME"
~~~

Un chemin comme `/home/user` désigne ce répertoire Linux. Il diffère de `C:\Users\...` côté Windows.

### Préparer la langue dans Ubuntu

Une installation neuve d'Ubuntu peut utiliser `LANG=C.UTF-8`. Cette locale est un réglage système neutre avec UTF-8. Pour choisir le français ou l'anglais et préparer les exemples, installer les locales dans **le terminal Ubuntu** :

~~~bash
sudo apt update
sudo apt install locales
sudo dpkg-reconfigure locales
~~~

Dans la liste proposée, sélectionner avec **Espace** :

| Locale à générer | Usage |
|---|---|
| `fr_FR.UTF-8 UTF-8` | Français, France. |
| `en_US.UTF-8 UTF-8` | Anglais, États-Unis. |

Utiliser **Tabulation** pour atteindre le bouton de validation, puis **Entrée**. À la question sur la locale par défaut, choisir **fr_FR.UTF-8** pour suivre le parcours français, ou **en_US.UTF-8** pour le parcours anglais. Attendre la fin de la génération.

Vérifier les locales disponibles :

~~~bash
locale -a
~~~

Les noms peuvent apparaître sous les formes `fr_FR.utf8` et `en_US.utf8`. La génération rend ces locales disponibles ; elle ne change pas nécessairement la langue du terminal déjà ouvert. Pour utiliser le français dès cette session :

~~~bash
export LANG=fr_FR.UTF-8
locale
~~~

Pour l'anglais, utiliser `export LANG=en_US.UTF-8`. Dans la sortie de `locale`, vérifier la ligne `LANG`. Jedi s'appuie sur cette variable avec son réglage de langue système ; installer les locales et choisir `LANG` sont deux opérations distinctes.

La section **Retrouver le programme et l'éditeur dans les prochaines sessions**, ci-dessous, conserve ce choix dans `~/.bashrc`. Les [références Ubuntu sur la génération des locales](https://manpages.ubuntu.com/manpages/noble/man8/locale-gen.8.html) et [leur consultation](https://manpages.ubuntu.com/manpages/noble/man1/locale.1.html) détaillent ces commandes.

### Préparer les répertoires de Jedi dans Ubuntu

Une installation neuve d'Ubuntu peut ne pas encore contenir les répertoires XDG employés par Jedi. Les créer explicitement permet de savoir où seront placés ses fichiers :

~~~bash
mkdir -p "$HOME/.config/jedi"
mkdir -p "$HOME/.local/state/jedi"
mkdir -p "$HOME/.local/share/jedi/market"
mkdir -p "$HOME/.local/bin" "$HOME/.local/libexec"
mkdir -p "$HOME/jedi-examples"
~~~

| Répertoire | Fichier ou usage Jedi |
|---|---|
| `~/.config/jedi/` | Configuration `jedi.conf`. |
| `~/.local/state/jedi/` | Journal `jedi.log`. |
| `~/.local/share/jedi/` | Base principale `jedi.db`. |
| `~/.local/share/jedi/market/` | Bases d'historiques de marché. |
| `~/.local/bin/` | Lanceurs publics `jedi`, `jedidemo`, `jedidev`. |
| `~/.local/libexec/` | Binaire `jedi` compilé, appelé par les lanceurs. |
| `~/jedi-examples/` | Dossier de travail proposé pour les essais et fichiers livrés. |

Il n'est pas nécessaire de définir `XDG_CONFIG_HOME`, `XDG_STATE_HOME` ou `XDG_DATA_HOME`. Lorsque ces variables sont absentes, Jedi utilise respectivement `~/.config`, `~/.local/state` et `~/.local/share`, puis leur sous-répertoire `jedi`. Il sait aussi créer les répertoires parents manquants lors de l'initialisation.

Si des variables XDG sont déjà définies, les chemins peuvent différer. Le lanceur public `jedi` emploie ces chemins de production et retire les anciens réglages `JEDI_*` de chemins hérités du terminal. Vérifier les emplacements effectifs avec `jedi config --paths` après installation. `jedidemo` et `jedidev` choisissent leurs propres espaces locaux, expliqués plus bas.

### Installer le programme et les outils utiles

Créer un dossier Linux pour recevoir l'archive binaire téléchargée et son fichier de contrôle :

~~~bash
mkdir -p "$HOME/telechargements-jedi"
cd "$HOME/telechargements-jedi"
explorer.exe .
~~~

L'Explorateur Windows s'ouvre sur ce dossier Linux. Y copier les deux fichiers téléchargés côté Windows. Revenir au terminal Ubuntu et suivre **Installer l'exécutable sous Linux**, plus haut, à partir du contrôle `sha256sum`. Garder les bases et les essais dans le système de fichiers Linux, selon [les indications Microsoft](https://learn.microsoft.com/fr-fr/windows/wsl/filesystems).

Installer également un éditeur et le programme graphique dans Ubuntu :

~~~bash
sudo apt update
sudo apt install gnuplot nano
~~~

Le mot de passe demandé est celui du compte Linux. Les commandes Jedi suivantes s'exécutent avec ce compte.

### Retrouver le programme et l'éditeur dans les prochaines sessions

Dans Ubuntu, ouvrir le fichier d'initialisation du terminal :

~~~bash
nano "$HOME/.bashrc"
~~~

Ajouter à la fin les quatre lignes suivantes. La dernière choisit le français pour ce terminal :

~~~bash
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nano
export VISUAL=nano
export LANG=fr_FR.UTF-8
~~~

Dans nano, enregistrer avec **Ctrl+O**, confirmer le nom avec **Entrée**, puis quitter avec **Ctrl+X**. Relire les réglages dans le terminal courant et contrôler :

~~~bash
source "$HOME/.bashrc"
command -v jedi
command -v nano
jedi version
jedi config --paths
~~~

Au premier lancement de Jedi, accepter explicitement la création des fichiers, comme indiqué dans la section suivante. L'éditeur servira notamment à `note create --edit` et `note update --edit`, expliqués au [chapitre 08](08_suivre_un_trade.md#rédiger-avec-un-éditeur).

### Retrouver les fichiers depuis Windows

Pour ouvrir le répertoire de configuration dans l'Explorateur :

~~~bash
cd "$HOME/.config/jedi"
explorer.exe .
~~~

L'accès depuis l'Explorateur est également possible par `\\wsl$`, puis la distribution et son répertoire `home`. Les chemins affichés par `jedi config --paths` restent des chemins Linux à utiliser dans le terminal Ubuntu. Copier les fichiers `examples/` de l'archive documentaire dans `~/jedi-examples/` pour les essais ; le [guide des exemples](../../examples/README.md) précise les bases à préparer.

## Effectuer le premier lancement

~~~console
jedi version
~~~

Cette commande affiche la version de Jedi et les informations de compilation. Au premier lancement, elle demande de créer successivement la configuration, le journal et la base principale. **Répondre explicitement `O`** à chaque demande en français, ou `Y` en anglais.

La base principale commence vide. Elle recevra les titres, barèmes, trades, paramétrages, opérations et notes. Les bases d'historiques de marché sont préparées séparément au [chapitre 10](10_base_de_cotations.md).

Afficher les emplacements effectivement utilisés :

~~~console
jedi config --paths
~~~

| Élément | Emplacement Linux habituel |
|---|---|
| Configuration | `~/.config/jedi/jedi.conf` |
| Journal | `~/.local/state/jedi/jedi.log` |
| Base principale | `~/.local/share/jedi/jedi.db` |
| Bases de marché | `~/.local/share/jedi/market/` |

Les variables XDG du système peuvent modifier ces emplacements. La sortie de `config --paths` donne les chemins à employer pour vos sauvegardes.

## Choisir la langue et les réglages

Avec son réglage de langue système par défaut, Jedi utilise le français lorsque `LANG` désigne cette langue, et l'anglais pour les autres valeurs de langue reconnues. Pour choisir la langue d'une commande :

~~~bash
LANG=fr_FR.UTF-8 jedi version
LANG=en_US.UTF-8 jedi version
~~~

Le fichier `jedi.conf` peut rester vide : le programme contient ses réglages par défaut. Ajouter seulement les valeurs à modifier. La configuration effective se consulte avec :

~~~console
jedi config
~~~

Elle peut contenir les clés d'accès de fournisseurs que vous avez configurées. Vérifier son contenu avant de la transmettre.

Voici les réglages **fictifs** utilisés pour le trade des chapitres 07 à 09, à placer dans le `jedi_test.conf` de l'espace d'essai décrit ci-dessous pour reproduire ce parcours :

~~~yaml
fees:
  rate: 0.0035
  min: 0.0
trading:
  capital: 5000.0
market_data:
  default_universe: france
~~~

`fees.rate` vaut ici 0,35 % et `fees.min` est le minimum par opération. `trading.capital` est le capital de référence consacré aux trades. Pour un usage réel, employer vos propres montants et frais. Les paramètres de simulation sont distincts du capital de suivi réel.

Les options d'une commande remplacent les réglages qu'elles désignent : par exemple, `candidate --capital=...` utilise le capital fourni pour cette évaluation ; il ne modifie pas `trading.capital`. Une modification du fichier est relue au lancement suivant.

## Préparer un espace d'essai séparé

Avec les lanceurs installés plus haut, **le nom de la commande choisit l'espace** :

| Commande | Usage | Emplacement par défaut |
|---|---|---|
| `jedi` | Portefeuille réel. | Fichiers `jedi.conf`, `jedi.log`, `jedi.db` et bases de marché aux chemins XDG. |
| `jedidemo` | Exercices de la documentation. | Configuration, journal, base `jedi_test.db` et marché dans `~/jedi-examples/jedi/env_test/`. |
| `jedidev` | Développement et essais d'un contributeur. | Fichiers `jedi_dev.*` et marché dans l'espace `env_dev` du projet. |

Les deux premières commandes suffisent pour utiliser Jedi et apprendre avec les exemples. Le fonctionnement des commandes reste le même ; leurs fichiers sont séparés.

Il n'y a pas de bascule à effectuer dans le terminal. Vous pouvez appeler `jedi`, puis `jedidemo`, puis `jedi` à nouveau. **`jedi` utilise toujours la production** ; son lanceur force ce choix et retire les anciens réglages `JEDI_*` de chemins dans son propre processus. Les chemins XDG restent ceux du système.

### Copier les fichiers d'exemple

Depuis le répertoire `examples/` de l'archive documentaire :

~~~bash
mkdir -p "$HOME/jedi-examples"
cp *.txt "$HOME/jedi-examples/"
jedidemo config --paths
~~~

Au premier lancement, accepter explicitement la création de la configuration, du journal et de la base principale : `O` en français, `Y` en anglais. Vérifier que `environment` indique **`test`** et relever les chemins :

| Élément d'essai | Emplacement par défaut |
|---|---|
| Configuration | `~/jedi-examples/jedi/env_test/conf/jedi_test.conf` |
| Journal | `~/jedi-examples/jedi/env_test/log/jedi_test.log` |
| Base principale | `~/jedi-examples/jedi/env_test/data/jedi_test.db` |
| Bases de marché | `~/jedi-examples/jedi/env_test/market/` |

Ajouter les réglages fictifs de la section précédente dans **`jedi_test.conf`** au chemin affiché. Les commandes d'exemple des chapitres suivants utilisent **`jedidemo`**. Pour les commandes sur une source réelle, préparer les historiques dans le marché de cet espace avant de les étudier.

~~~console
jedidemo trade list
~~~

Le lanceur ouvre `~/jedi-examples/` pour Jedi : les noms comme `cotations_EXA.txt` sont donc utilisables depuis n'importe quel répertoire du terminal. Les chemins relatifs fournis à `jedidemo` se lisent depuis ce dossier, y compris ceux d'un fichier à importer ou à exporter. Employer un chemin absolu pour un fichier situé ailleurs. Les redirections comme `> sauvegarde.txt` sont effectuées par le terminal dans son propre dossier ; un chemin absolu évite toute ambiguïté.

Le `cd` du script concerne seulement le processus du lanceur et de Jedi. **Le terminal appelant conserve son répertoire et ses variables.** Les lanceurs conservent aussi la langue, l'éditeur et le fuseau du terminal. Pour reproduire un calcul explicitement en UTC sur une commande :

~~~bash
TZ=UTC jedidemo version
~~~

### Alterner entre portefeuille et démonstration

~~~console
jedi trade list
jedidemo trade list
jedi config --paths
jedidemo config --paths
~~~

La première liste concerne le portefeuille réel, la deuxième les trades fictifs. Les deux dernières commandes montrent les chemins propres à chaque espace. Les bases restent en place : `jedidemo` retrouve les mêmes exemples au lancement suivant.

### Conserver plusieurs espaces d'essai

Chaque répertoire peut avoir sa propre base de test et son propre marché. Par exemple, conserver les évaluations sans trade des chapitres 03 à 06 dans l'espace habituel, puis créer un autre espace pour les ouvertures des chapitres 07 à 09 :

~~~bash
mkdir -p "$HOME/jedi-examples-trades"
cp "$HOME/jedi-examples/"*.txt "$HOME/jedi-examples-trades/"
JEDI_DEMO_DIR="$HOME/jedi-examples-trades" jedidemo config --paths
~~~

Cette première commande Jedi initialise l'autre espace après vos confirmations. Utiliser le même préfixe **`JEDI_DEMO_DIR=...`** pour chacune de ses commandes :

~~~bash
JEDI_DEMO_DIR="$HOME/jedi-examples-trades" jedidemo trade list
jedidemo trade list
~~~

La première ligne utilise le second espace ; la suivante retrouve l'espace habituel. Pour choisir durablement un autre dossier de démonstration, la ligne `export JEDI_DEMO_DIR="..."` peut être ajoutée à `~/.bashrc`. Elle personnalise `jedidemo` ; `jedi` reste la production.

Depuis un répertoire d'essai déjà créé, on peut aussi lancer :

~~~bash
JEDI_DEMO_DIR="$PWD" jedidemo config --paths
~~~

Dans un dossier `essai`, les fichiers sont sous `essai/jedi/env_test/`. Si le dossier s'appelle déjà `jedi`, ils sont sous `jedi/env_test/`, sans répéter ce nom.

### Choisir éventuellement un autre marché

Le marché de démonstration est local à l'espace par défaut. Pour utiliser volontairement un répertoire de marché existant :

~~~bash
JEDI_DEMO_MARKET_DIR="/chemin/vers/market" \
  jedidemo market info abcbourse
~~~

Remplacer le chemin et la source par ceux de vos données. Seules les bases de marché sont alors partagées ; la base principale de test reste dans l'espace choisi. Les commandes `market import`, `update`, `replace` et `group` agissent sur le marché sélectionné : choisir un marché séparé pour les exercices qui modifient les données.

Un chemin relatif de `JEDI_DEMO_MARKET_DIR` est lu depuis le dossier de démonstration. La variable générale `JEDI_MARKET_DIR` est effacée par les lanceurs ; leur sélection volontaire utilise `JEDI_DEMO_MARKET_DIR` ou `JEDI_DEV_MARKET_DIR`.

## Pour les développeurs : utiliser jedidev

Cette section est facultative pour l'utilisateur du binaire fourni. Un contributeur installe **Crystal 1.21.1** et **Shards**, selon les [instructions officielles Crystal](https://crystal-lang.org/install/), puis travaille depuis la racine des sources.

Le lanceur `jedidev` utilise le répertoire courant comme projet, ou celui fourni par `JEDI_DEV_DIR`. Il sélectionne le mode `dev` et conserve séparément configuration, journal, base principale et bases de marché :

~~~console
jedidev config --paths
~~~

Si le projet s'appelle `jedi`, la base est `<projet>/env_dev/data/jedi_dev.db` et le marché `<projet>/env_dev/market/`. Pour un autre nom de dossier, ils sont sous `<projet>/jedi/env_dev/`.

Pour installer les dépendances, vérifier les sources et compiler un binaire de travail :

~~~bash
shards install
crystal tool format --check src spec
TZ=UTC crystal spec
mkdir -p build
crystal build src/jedi_cli.cr -o build/jedi-dev-core
chmod +x build/jedi-dev-core
JEDI_DEV_BINARY="./build/jedi-dev-core" jedidev config --paths
~~~

La compilation demande aussi les bibliothèques de développement des dépendances, notamment SQLite. Les noms des paquets dépendent de la distribution. Les tests sont lancés en UTC pour reproduire les dates des vérifications.

`JEDI_DEV_BINARY` choisit le binaire compilé pour cette commande. Sans cette variable, `jedidev` appelle le binaire installé dans `~/.local/libexec/jedi`. Le chemin relatif du binaire se lit depuis le projet sélectionné. Pour un appel depuis un autre dossier, fournir les deux chemins :

~~~bash
JEDI_DEV_DIR="/chemin/du/projet" \
  JEDI_DEV_BINARY="./build/jedi-dev-core" jedidev version
~~~

`JEDI_DEV_MARKET_DIR` permet de choisir volontairement un autre marché, comme pour la démonstration. Pour le suivi réel, employer le lanceur `jedi`.

## Sauvegarder et reprendre les données

Entre deux commandes Jedi, lorsque aucune n'est en cours, sauvegarder la configuration et les bases indiquées par `config --paths`, pour chaque espace utile. Une copie des répertoires de configuration et de données conserve notamment la base principale et les bases de marché. Garder également les fichiers d'origine et les listes nécessaires à leur reconstitution. Le journal peut aider à comprendre un incident.

Jedi fournit en complément un export de la **base principale**, y compris les notes et les cours enregistrés. Ici, le fichier de production est écrit au chemin absolu choisi :

~~~bash
jedi database dump > "$HOME/jedi-sauvegarde.txt"
~~~

Cet export ne contient ni `jedi.conf` ni les bases de marché. Pour vérifier une restauration, créer un dossier neuf et initialiser sa base principale :

~~~bash
mkdir -p "$HOME/jedi-restauration"
JEDI_DEMO_DIR="$HOME/jedi-restauration" jedidemo config --paths
JEDI_DEMO_DIR="$HOME/jedi-restauration" \
  jedidemo database load "$HOME/jedi-sauvegarde.txt"
JEDI_DEMO_DIR="$HOME/jedi-restauration" jedidemo trade list
JEDI_DEMO_DIR="$HOME/jedi-restauration" jedidemo note list
~~~

**`load` exige une base entièrement vide**, notes comprises. Il ne fusionne pas l'export avec un portefeuille existant. Contrôler les trades, opérations, notes et réglages avant de reprendre le suivi. Le lanceur `jedi` retrouve le portefeuille réel ; `jedidemo` sans ce préfixe retrouve la démonstration habituelle. Pour restaurer une copie des fichiers, remettre chaque fichier au chemin prévu, sans commande Jedi en cours.

Sous WSL, une copie complète de la distribution peut aussi être créée depuis PowerShell :

~~~powershell
wsl --shutdown
wsl --export Ubuntu jedi-wsl-backup.tar
~~~

Adapter le nom de la distribution. La [référence Microsoft](https://learn.microsoft.com/fr-fr/windows/wsl/basic-commands) décrit l'export et l'import d'une distribution.

## Mettre à jour Jedi

Sauvegarder les données, lire les notes de version, puis vérifier et installer le nouvel exécutable avec la procédure précédente. Le remplacement du programme conserve les fichiers de votre environnement. Après installation, contrôler `jedi version`, `jedi config --paths` et quelques données connues.

Vous pouvez maintenant suivre [le choix d'un titre](03_choisir_un_titre_support.md), ou reprendre directement [l'ouverture fictive d'EXA](07_ouvrir_un_trade.md).
