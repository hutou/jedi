# Comprendre la mécanique de Jedi

La première partie montrait comment préparer et suivre un trade. Cette partie explique comment un barème relie les mouvements de cours aux quantités de titres, aux ordres et au capital engagé.

Le prérequis est la connaissance du parcours pratique : titre choisi, barème, paramétrage, ordre et opération exécutée. Les notions plus précises sont définies au moment de leur emploi. Les formules viennent après une explication en mots courants.

Les chapitres 11 et 12 expliquent les flux, les positions, les échelons et les paliers. Les chapitres 13 à 15 présentent la structure des barèmes et leurs deux types. Le chapitre 16 traite la continuité lors d'un changement de paramétrage. Les chapitres 17 et 18 relient cet état aux ordres, au risque et au dimensionnement. Les chapitres 19 et 20 vérifient les calculs et suivent un exemple complet.

## Préparer les exemples de mécanique

La plupart des exemples partent de **100 titres fictifs à 10 €**, avec un barème de type I et un pas de cotation de 0,01 €. Ce barème diffère du type II d'Exa_01 dans la partie I. Au chapitre 15, la comparaison utilise un type II à 20 %. Les chapitres 18 et 20 emploient aussi 125 titres pour montrer le dimensionnement.

Les parcours se calculent avec `tools play` et, pour un type I, `tools calc`. Ils ne nécessitent ni téléchargement ni import des fichiers de cotations. Les mouvements sont choisis pour montrer le calcul, sans prétendre représenter un marché réel.

Utiliser [l'espace d'essai du chapitre 02](02_installer_et_preparer_jedi.md#préparer-un-espace-dessai-séparé). Les frais sont de **0,35 %, sans minimum**. Pour les protections du chapitre 18, ajouter dans la configuration de cet espace :

~~~yaml
simulation:
  capital: 20000
~~~

Ce capital concerne `play`. Le capital de `candidate` est fourni explicitement par `--capital=20000`. Ses évaluations supposent une base sans trade ouvert. Les créations de barèmes pédagogiques et les notes écrivent dans la base d'essai ; les parcours définis directement dans `play` restent en mémoire.

Le [guide des exemples](../../examples/README.md) rappelle ces conventions. Commencer par [les flux du chapitre 11](11_allers_retours_et_flux_du_trade.md), puis suivre les chapitres dans l'ordre.

À la fin de cette partie, le lecteur pourra expliquer une variation de stock, comprendre un ordre Limit ou Stop, distinguer le StopLoss de protection et lire l'effet de `r`, `o` et `n`. Comprendre ces calculs permet de vérifier le processus ; leur résultat historique sera étudié dans la partie III.
