# Adapter ou terminer un trade

## Partir d'un état vérifié

Une adaptation change les règles ou les références utilisées pour les prochaines opérations. Elle ne doit pas remplacer les opérations réelles du passé.

Avant d'intervenir, vérifier le stock, les dernières opérations et les ordres actifs chez le courtier. Annuler les ordres que le changement rendra caducs et confirmer leur annulation. Sauvegarder la base selon le [chapitre 02](02_installer_et_preparer_jedi.md#sauvegarder-et-reprendre-les-données).

À l'exception du cas distinct de regroupement de 1 790 titres présenté plus bas, les exemples ci-dessous sont **des choix séparés**, chacun partant du trade fictif Exa_01 à la fin du [chapitre 08](08_suivre_un_trade.md) : 94 titres, investissement net de 934 €, position `0:0:+1`, barème `B_vr_01`. Ne pas exécuter toutes les variantes successivement sur ce même état. Pour les comparer, conserver une sauvegarde de cet état et la restaurer dans une base d'essai vide avant chaque variante.

## Choisir le changement nécessaire

| Besoin | Commande ou option |
|---|---|
| Poursuivre avec un autre barème | `settings create` avec ce barème, sans option spéciale. |
| Donner une nouvelle origine mécanique au stock conservé | `--reinit=reset,c0`. |
| Relier la nouvelle origine à une transaction réelle | `--reinit=merge,c0`, puis l'opération. |
| Prendre en compte un fractionnement ou regroupement | `--split=NOUVEAUX:ANCIENS`. |
| Reprendre exceptionnellement une position de type I | `--sync=x:y:e`. |
| Modifier le nom ou la gestion du capital | `trade update`. |
| Corriger les frais d'une opération, même ancienne | `operation fees ID MONTANT`, selon le chapitre 08. |
| Terminer le trade | Enregistrer la vente réelle de tout le stock restant. |

À partir de cette évolution de Jedi 1.1, **`--split` peut accompagner `--reinit=reset,prix` ou `--reinit=merge,prix` dans un seul paramétrage**. Le split s'applique d'abord au stock ; le prix fourni à `reinit` est exprimé dans la nouvelle unité du titre. `--sync` reste incompatible avec `--split` et avec `--reinit`. Un nouveau paramétrage doit respecter la chronologie globale rappelée au chapitre 07.

**Le dernier paramétrage du trade doit avoir été utilisé par une opération avant d'en créer un autre.** Cette condition concerne aussi un changement simple, un split ou un reset. Si le paramétrage inutilisé résulte d'une erreur de saisie, la correction de fin d'historique est expliquée plus bas ; ne pas inventer une opération pour satisfaire ce contrôle.

## Changer de barème en conservant la continuité

Dans cette variante, enregistrer un barème avec mouvements de 12 %, puis créer le nouveau paramétrage :

~~~console
jedidemo scale create --name=B_vr_02 \
  --comment="Exemple avec mouvements de 12 %" \
  --builder="vr:12%,np:3,nn:3,ki:10%,kb:1,kd:0"
jedidemo settings create Exa_01 --scale=B_vr_02 \
  --date=2026-09-23 --time=09:00:00
jedidemo settings list Exa_01
jedidemo trade status Exa_01
jedidemo trade orders Exa_01
~~~

Le stock reste 94. Le nouveau paramétrage conserve ici `q0=100` et `c0=10` ; ces références ne sont pas le stock et le cours courants. Il reprend l'échelon `+1`, avec une position `0:0:+1`.

Lors d'un changement simple, Jedi remet les compteurs de saut `x` et `y` à zéro et intègre leurs effets dans les coefficients cumulés. Il conserve donc la continuité des calculs sans recopier tous les compteurs. Les chapitres 12 et 16 expliquent cette mécanique.

Le nouveau barème doit pouvoir reprendre l'échelon conservé ; sinon Jedi refuse ce changement. Lire les nouveaux ordres avant de les placer.

## Repartir du stock courant avec reset

Cette variante conserve les 94 titres et choisit un cours de référence fictif de 11 € :

~~~console
jedidemo settings create Exa_01 --scale=B_vr_01 \
  --date=2026-09-23 --time=09:00:00 --reinit=reset,11
jedidemo settings list Exa_01
jedidemo trade orders Exa_01
~~~

Le nouveau paramétrage possède `q0=94`, `c0=11` et une position `0:0:0`. Aucun achat ni aucune vente n'est créé. Les opérations anciennes et l'investissement déjà engagé restent dans l'historique.

Choisir le nouveau cours selon une règle explicite, par exemple le cours constaté au moment de l'intervention. Un reset peut changer les prochains ordres ; il ne corrige pas un stock erroné et n'efface pas les pertes anciennes. Conserver dans une note le motif, le cours retenu et les ordres annulés.

## Relier une réinitialisation à une opération avec merge

Cette autre variante suppose un achat manuel **réel** de 6 titres à 11 €. Créer le paramétrage, puis enregistrer cette exécution :

~~~console
jedidemo settings create Exa_01 --scale=B_vr_01 \
  --date=2026-09-23 --time=09:00:00 --reinit=merge,11
jedidemo operation create Exa_01 \
  --date=2026-09-23 --time=09:01:00 \
  --type=Buy --mode=Market --quantity=6 --price=11 --fees=0.23
jedidemo settings list Exa_01
jedidemo trade status Exa_01
~~~

Après la création du paramétrage, les nouvelles références restent en attente. L'opération suivante les établit à partir du stock conservé, du cours indiqué et de la transaction. Dans cet exemple, le stock et `q0` passent à 100, `c0` vaut 11 € et la position est `0:0:0`.

Utiliser `merge` lorsque la transaction fait partie de la décision de réinitialisation. Tant que cette opération n'est pas enregistrée, `q0` et `c0` restent à zéro et **Jedi ne propose aucun ordre automatique**. Enregistrer l'achat ou la vente réellement exécuté pour établir la nouvelle base. La note doit décrire le motif et la transaction attendue.

## Prendre en compte un split ou un regroupement

Un fractionnement modifie le nombre de titres et leur unité de prix sans achat ni vente. Pour deux titres nouveaux contre un ancien :

~~~console
jedidemo settings create Exa_01 --scale=B_vr_01 \
  --date=2026-09-23 --time=09:00:00 --split=2:1
jedidemo quote set FR4487601001 --price=5.50
jedidemo trade status Exa_01
jedidemo trade orders Exa_01
~~~

Le stock de suivi passe de 94 à **188 titres**. `q0` passe de 100 à 200 et `c0` de 10 à 5 €. La position conserve l'échelon `+1` ; l'investissement net reste 934 €. Le cours fictif de 5,50 € est saisi dans la nouvelle unité de prix.

L'ordre du ratio Jedi est toujours **nouveaux : anciens** :

| Événement | Option Jedi |
|---|---|
| 10 titres nouveaux pour 1 ancien | `--split=10:1` |
| 1 titre nouveau pour 10 anciens | `--split=1:10` |

Pour un regroupement de 101 titres anciens à raison de dix contre un, il reste 10 titres nouveaux entiers et un droit fractionnaire de 0,1 titre, ou **rompu**. Consulter les modalités de l'événement pour son traitement. Jedi ne gère ni ce rompu ni son éventuel règlement en espèces. Comparer le stock entier au relevé du courtier et noter tout montant reçu ; cette somme reste extérieure aux résultats calculés du trade. Ne pas la transformer en opération fictive d'achat ou de vente.

Après l'événement, vérifier aussi le pas de cotation et tous les ordres. Le ratio et sa date d'effet doivent correspondre à l'événement réel.

## Combiner un regroupement et une réinitialisation

Ce cas est **distinct des variantes portant sur les 94 titres d'Exa_01**. Supposons un trade fictif déjà enregistré, nommé `Exr_01`, qui conserve **1 790 titres** après sa dernière transaction. Le titre est regroupé à raison d'une action nouvelle pour dix anciennes, puis la reprise du suivi justifie une nouvelle référence. Le prix choisi après regroupement est de **12 €** ; il ne doit pas être divisé par dix dans la commande.

Pour l'illustration, le barème enregistré est `B_vr_03`, défini par `vr:10%,ks:0.8,1.2,ki:0%,kb:0`. Employer le barème réellement retenu pour votre trade et des dates respectant toute la base. Le [chapitre 19](19_verifier_avec_tools_calc_et_play.md#simuler-un-regroupement-avec-reset-ou-merge) reproduit ce cas en mémoire, sans devoir créer `Exr_01`.

Avec **reset**, créer un seul paramétrage :

~~~console
jedidemo settings create Exr_01 --scale=B_vr_03 \
  --date=2026-10-12 --time=09:00:00 \
  --split=1:10 --reinit=reset,12
jedidemo settings list Exr_01
jedidemo trade status Exr_01
jedidemo trade orders Exr_01
~~~

Le stock effectif et `q0` deviennent **179 titres**, `c0` vaut **12 €**, la position est `0:0:0` et les coefficients cumulés `kspc` et `kcpc` valent 1. Le regroupement ne crée aucune transaction et ne change pas les résultats financiers passés. Ordres et stops utilisent les 179 titres dès ce paramétrage ; le nouveau prix de reset sert immédiatement aux premiers calculs de type II.

Avec **merge**, choisir cette autre variante depuis le même état de départ :

~~~console
jedidemo settings create Exr_01 --scale=B_vr_03 \
  --date=2026-10-12 --time=09:00:00 \
  --split=1:10 --reinit=merge,12
~~~

Le stock effectif est déjà de 179 titres, mais la référence reste en attente : `q0=0`, `c0=0`, aucun ordre automatique. Si l'investisseur fait réellement acheter **21 actions nouvelles à 10 €**, enregistrer l'exécution dans les nouvelles unités :

~~~console
jedidemo operation create Exr_01 \
  --date=2026-10-12 --time=09:01:00 \
  --type=Buy --mode=Market --quantity=21 --price=10 --fees=0.74
jedidemo settings list Exr_01
jedidemo trade orders Exr_01
~~~

Le stock et `q0` deviennent **200**, et `c0=(179×12+21×10)/200`, soit **11,79 €**. Une vente réelle convient aussi : vendre 20 actions nouvelles à 14 € donnerait 159 titres et `c0=(179×12−20×14)/159`, soit **11,7484 €**. Ces références sont calculées hors frais ; les frais réellement payés sont enregistrés avec l'opération.

Le prix de référence, le prix d'exécution et la quantité négociée sont tous exprimés **après le split**. Jedi ne reconvertit pas ces prix. Dès qu'une transaction appartient au nouveau paramétrage, le split ne s'applique plus à son stock une seconde fois.

Les 1 790 actions ne produisent aucun rompu. Si le stock avait été de 1 793, la référence de reset ou merge aurait utilisé les **179 titres entiers** ; les droits fractionnaires et leur indemnisation éventuelle restent hors des résultats de Jedi, comme expliqué plus haut.

Cette combinaison ne permet pas deux paramétrages inutilisés successifs. Elle regroupe deux changements cohérents dans le même paramétrage, sans opération blanche ni conversion manuelle des ordres.

## Resynchroniser exceptionnellement une position

Une interruption du suivi ou un gap important peut conduire à reprendre la gestion à une autre position théorique. Les opérations qui n'ont pas eu lieu ne doivent pas être enregistrées.

`--sync` est réservé aux **barèmes de type I**. Voici une variante fictive utilisant explicitement un tel barème :

~~~console
jedidemo scale create --name=B_kc_02 \
  --comment="Exemple de type I pour sync" \
  --builder="kc:1.4,1.2,0.8,0.6,ki:10%,kb:1,kd:0"
jedidemo settings create Exa_01 --scale=B_kc_02 \
  --date=2026-09-23 --time=09:00:00 --sync=1:0:+1
jedidemo settings list Exa_01
jedidemo trade orders Exa_01
~~~

La position fournie `1:0:+1` décrit le raccord demandé. Jedi en intègre les effets et ouvre le paramétrage actif en `0:0:+1`. Il ne corrige pas le stock et n'ajoute aucune opération manquée.

Le choix de position demande de comprendre le barème et le cours de reprise ; il est approfondi dans la partie II. Avant cette intervention, résoudre les écarts de stock à partir des exécutions réelles. Noter la période d'interruption ou le gap, l'ancienne position, le cours et la position retenue.

## Modifier le nom ou la gestion du capital

Conserver normalement le nom choisi au chapitre 07 pendant toute la vie du trade. Pour corriger un repère mal choisi, par exemple remplacer la forme courte `Exa_01` par `Exemplea_01` :

~~~console
jedidemo trade update Exa_01 --name=Exemplea_01
~~~

Pour activer ou modifier `money` :

~~~console
jedidemo trade update Exemplea_01 --money="r:1%,o:1,n:2"
jedidemo trade orders Exemplea_01
~~~

Ces valeurs utilisent le capital configuré, ici 5 000 €. Elles sont des choix d'illustration ; elles modifient les règles de protection et ne changent pas les opérations passées.

Si un stop mémorisé existe et que `money` change, Jedi exige sa réinitialisation explicite :

~~~console
jedidemo trade update Exemplea_01 --money="r:1.5%,o:1,n:2" --reset-stop
jedidemo trade orders Exemplea_01
~~~

Lire la demande de confirmation. Cette option efface le stop mémorisé dans Jedi ; elle n'annule aucun ordre chez le courtier. Vérifier les ordres de protection avant et après le changement. Augmenter le risque pour rendre une perte acceptable à l'affichage ne répare pas le trade.

## Corriger la fin de l'historique

Pour une erreur portant uniquement sur les frais, utiliser `operation fees ID MONTANT` : cette correction est possible sur toute opération, même d'un trade clôturé, sans remonter l'historique. Le [chapitre 08](08_suivre_un_trade.md#corriger-les-frais-dune-opération-enregistrée) décrit la procédure.

Pour corriger les autres données d'une opération, il n'existe pas de modification libre d'un ancien enregistrement. La correction remonte la fin de l'historique global dans l'ordre inverse, puis recrée les enregistrements corrects.

~~~console
jedidemo operation delete
~~~

Cette commande propose de supprimer **la dernière opération de toute la base**, pas une opération choisie dans Exa_01. Lire sa confirmation. Si un paramétrage plus récent existe, l'opération ne peut pas être supprimée avant lui.

Si ce dernier paramétrage n'a servi à aucune opération, la séquence devient :

~~~console
jedidemo settings delete
jedidemo operation delete
~~~

Après contrôle des confirmations, recréer les éléments corrigés dans leur chronologie réelle et vérifier les ordres. Une suppression peut annuler un état de clôture ; elle doit servir à corriger une saisie, pas à réécrire une exécution. Consigner le motif et les valeurs corrigées dans une note.

## Terminer le trade par sa vente réelle

Cette dernière variante repart des 94 titres à la fin du chapitre 08, sans appliquer les adaptations précédentes. Annuler les ordres incompatibles avec la sortie, faire vendre le stock chez le courtier et enregistrer l'exécution confirmée :

~~~console
jedidemo operation create Exa_01 \
  --date=2026-09-23 --time=15:00:00 \
  --type=Sell --mode=Market --quantity=94 --price=11.20 --fees=3.68
jedidemo operation list Exa_01 -c 0,6-14,17
jedidemo trade list
jedidemo trade results Exa_01
~~~

Le stock devient **zéro** : le trade est clôturé. Il n'y a pas de commande administrative `trade close`. Selon l'ordre réellement exécuté, reporter le mode `Market`, `Limit`, `Stop` ou `StopLoss` approprié.

Les valeurs utiles de notre exemple sont :

| Information | Valeur |
|---|---:|
| Achats enregistrés hors frais | 1 000,00 € |
| Ventes enregistrées hors frais | 1 118,80 € |
| Gains hors frais | 118,80 € |
| Frais cumulés | 7,41 € |
| Stock final | 0 |

Après déduction des frais, le gain de cet exemple est 111,39 €. Le taux annualisé affiché sur un parcours aussi court est une extrapolation ; il ne remplace pas ce bilan monétaire.

Si la vente finale reste partielle, appliquer la consolidation et l'annulation du reliquat expliquées au chapitre 08. Le trade reste ouvert tant qu'il possède des titres.

Une fois le stock nul, Jedi refuse une nouvelle opération sur ce trade. Pour une nouvelle gestion du même titre, créer un autre trade. Conserver le trade terminé : ses opérations, ses réglages, ses notes de contexte et ses résultats servent au contrôle ultérieur. `trade delete` refuse la suppression d'un trade possédant un historique.
