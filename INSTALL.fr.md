# Installer Jedi 1.0

Ce guide utilise l’archive **binaire** `jedi-1.0.0-linux-x86_64.tar.gz`. L’archive contenant les sources sert à la compilation ; elle ne contient pas l’exécutable déjà compilé.

## Sous Linux

Ouvrir un terminal et vérifier l’architecture :

```bash
uname -m
```

La sortie doit être `x86_64`. Utiliser son compte habituel pour installer et lancer Jedi.

Pour les graphiques, installer gnuplot. Sous Ubuntu :

```bash
sudo apt update
sudo apt install gnuplot
```

La bibliothèque SQLite est intégrée au binaire statique. Le programme `sqlite3` n’est pas nécessaire pour utiliser Jedi. Il peut être installé séparément pour examiner une base : `sudo apt install sqlite3`.

Depuis le dossier contenant l’archive et son fichier de contrôle téléchargés dans Releases :

```bash
sha256sum -c jedi-1.0.0-linux-x86_64.tar.gz.sha256
tar -xzf jedi-1.0.0-linux-x86_64.tar.gz
cd jedi-1.0.0-linux-x86_64
bash install.sh
export PATH="$HOME/.local/bin:$PATH"
hash -r
type -a jedi jedidemo jedidev
```

Le contrôle doit indiquer `OK`. Les commandes trouvées doivent désigner les lanceurs dans `~/.local/bin/`. Si un alias ou une fonction porte déjà le nom `jedi`, retirer cette définition dans le fichier du shell où elle a été créée.

Pour conserver le chemin entre les sessions Bash, ajouter une fois cette ligne à `~/.bashrc` :

```bash
export PATH="$HOME/.local/bin:$PATH"
```

L’installateur place le binaire dans `~/.local/libexec/jedi`, les trois lanceurs dans `~/.local/bin/` et les fichiers TXT d’exemple dans `~/jedi-examples/`. Un fichier d’exemple déjà présent est conservé. Pour revoir une version originale, la lire dans le dossier `examples/` de l’archive.

## Premier essai

Pour suivre le parcours français, utiliser une locale française déjà disponible sur le système :

```bash
export LANG=fr_FR.UTF-8
jedidemo config --paths
jedidemo version
```

Au premier lancement, Jedi demande de créer sa configuration, son journal et sa base de démonstration. Répondre **`O`** à chaque demande en français. Avec `LANG=C.UTF-8`, l’interface utilise l’anglais : répondre **`Y`**. Si une création est refusée, l’initialisation s’arrête ; relancer la commande pour la reprendre.

Vérifier `environment : test` et des chemins situés sous `~/jedi-examples/jedi/env_test/`. Puis :

```bash
jedidemo tools play -c o0,6-14,17 -- \
  scale=vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0,q0=100,c0=10,tick=0.01 \
  1 -1
```

Ce scénario explique la mécanique sans enregistrer d’opération. Pour importer les cotations fictives dans la base Demo, suivre [le début du chapitre 10](documentation/nouveaux/10_base_de_cotations.md). `market init demo` s’exécute une seule fois pour une nouvelle base.

## Passer au portefeuille réel

```bash
jedi config --paths
jedi version
```

`jedi` impose la production et retire les anciens réglages de chemins `JEDI_*` hérités du terminal. Il respecte les emplacements XDG : par défaut `~/.config/jedi/`, `~/.local/state/jedi/` et `~/.local/share/jedi/`. Il propose de créer ses fichiers au premier lancement. Vérifier ces chemins avant de préparer des trades réels.

`jedidemo` utilise ses données d’essai, y compris ses bases de marché. Pour un deuxième espace :

```bash
mkdir -p "$HOME/jedi-autre-essai"
cp examples/*.txt "$HOME/jedi-autre-essai/"
JEDI_DEMO_DIR="$HOME/jedi-autre-essai" jedidemo config --paths
```

Employer ce même préfixe pour les commandes suivantes de cet espace. Les détails de `jedidev` et des bases de marché explicitement partagées sont dans [le chapitre 02](documentation/nouveaux/02_installer_et_preparer_jedi.md).

## Sous Windows, avec Ubuntu sous WSL2

Dans PowerShell ouvert en administrateur :

```powershell
wsl --install
```

Redémarrer Windows si cela est demandé. Dans PowerShell, contrôler ensuite :

```powershell
wsl --list --verbose
```

Si Ubuntu n’est pas installé, relancer en administrateur `wsl --install -d Ubuntu`. Au premier lancement d’Ubuntu, créer le compte Linux. La liste doit montrer Ubuntu avec `2` dans la colonne `VERSION`. Si nécessaire, convertir la distribution avec `wsl --set-version Ubuntu 2`, puis l’ouvrir avec `wsl -d Ubuntu`.

Effectuer ensuite les étapes Linux de ce guide **dans le terminal Ubuntu**. Pour les répertoires, les locales et le transfert du téléchargement depuis Windows, suivre [le chapitre 02](documentation/nouveaux/02_installer_et_preparer_jedi.md). La [procédure Microsoft en français](https://learn.microsoft.com/fr-fr/windows/wsl/install) décrit l’installation de WSL.

## Mise à jour et retrait

Une nouvelle installation remplace le binaire et les lanceurs. Elle conserve les fichiers de configuration, les bases, les journaux et les exemples déjà présents. Sauvegarder les bases avec les commandes du manuel avant une mise à jour.

Pour retirer les programmes installés :

```bash
rm -- "$HOME/.local/bin/jedi" "$HOME/.local/bin/jedidemo" \
  "$HOME/.local/bin/jedidev" "$HOME/.local/libexec/jedi"
```

Cette commande conserve les données. Les archives de livraison peuvent être gardées pour réinstaller la même version.
