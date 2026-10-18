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
