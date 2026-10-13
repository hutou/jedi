# Suivre un trade au quotidien

## Une boucle de suivi

Le suivi consiste à disposer d'un cours pertinent, lire l'état et les ordres, les maintenir chez le courtier, puis enregistrer seulement les exécutions réelles. Après une opération, recalculer les ordres.

Trois informations restent distinctes :

| Information | Ce qu'elle décrit |
|---|---|
| Cours enregistré | Une observation de prix utilisée pour le suivi. |
| Ordres calculés | Les prochaines opérations proposées à partir de l'état du trade. |
| Opérations enregistrées | Les achats et ventes réellement exécutés. |

Un changement de cours ne modifie pas le stock. Un ordre placé ou annulé chez le courtier ne modifie pas la base Jedi. Une exécution du courtier n'y apparaît qu'après votre enregistrement.

Ce chapitre continue **le trade fictif Exa_01 ouvert au [chapitre 07](07_ouvrir_un_trade.md)** : 100 titres achetés à 10 €, barème `B2_vr10_ki10_v01`. Les commandes d'enregistrement sont des essais à effectuer dans la base séparée du [chapitre 02](02_installer_et_preparer_jedi.md#préparer-un-espace-dessai-séparé).

## Disposer d'un cours pertinent

Pour les essais fictifs, saisir le prix voulu :

~~~console
jedidemo quote set FR4487601001 --price=11
~~~

`quote set` enregistre le prix avec l'heure de saisie, la source `manual` et sans variation mémorisée. Il ne sait pas de quand date votre observation : vérifier vous-même que le cours correspond à la séance et au moment voulus.

Avec des fournisseurs configurés, les commandes courantes sont :

~~~console
jedidemo quote update FR4487601001
jedidemo quote refresh
jedidemo quote refresh --mode=eod
~~~

`update` actualise un titre enregistré. `refresh` actualise, par défaut, les titres liés aux trades en cours. Pour employer la collecte sur un titre réel, remplacer l'ISIN fictif par celui de votre titre enregistré : EXA ne possède aucun cours auprès des fournisseurs de marché.

`--mode=eod` demande le mode de fin de journée ; `--mode=live` demande le mode de cours courant. Le contenu, les délais et la disponibilité dépendent du fournisseur. L'option de mode peut aussi être donnée à `quote update`.

Pour une consultation sans écrire le résultat dans la base principale :

~~~console
jedidemo quote get FR4487601001
~~~

La configuration détaillée des fournisseurs figure dans l'[annexe 02](fr_annex02_fournisseurs_de_donnees.md). La saisie manuelle permet de suivre le trade même si la collecte est indisponible. Les commandes `market update` du chapitre 10 entretiennent les historiques ; elles ne remplacent pas ces cours de suivi.

Les commandes de suivi peuvent tenter d'actualiser un cours dont la durée de conservation configurée est dépassée. En cas d'échec, un ancien cours peut être réutilisé avec une alerte. Lire cette alerte et contrôler la pertinence du cours avant d'utiliser les ordres.

## Lire l'état et les ordres

~~~console
jedidemo trade status Exa_01
jedidemo trade orders Exa_01
~~~

Comparer le stock affiché au stock du courtier. Lire pour chaque ordre son type `Buy` ou `Sell`, son mode, sa quantité, son prix et son montant. Avec le cours de 11 € et sans nouvelle opération, Exa_01 conserve encore 100 titres et propose les ordres du chapitre précédent.

| Mode | Sens pratique |
|---|---|
| Limit | Ordre à cours limité. |
| Stop | Ordre de fonctionnement déclenché au franchissement d'un seuil. |
| StopLoss | Ordre de protection issu de la gestion du capital `money`. |

Un Stop de fonctionnement et un StopLoss ont des rôles différents. Même si vous avez choisi un barème qualifié d'optimisé, lire le mode réellement proposé ; certains parcours peuvent produire un Stop de fonctionnement.

La marque **PRÊT** signale que le cours connu a franchi le prix de l'ordre dans le sens correspondant à son exécution. **À SUIVRE** signale une proximité selon le seuil configuré. Une égalité exacte de cours peut encore être marquée « à suivre ». Aucune de ces marques ne prouve une exécution chez le courtier.

Si Jedi signale des quantités insuffisantes, un cours trop ancien ou une gestion du capital inapplicable, examiner le motif avant de continuer. Le [chapitre 06](06_tools_candidate.md#quand-des-trades-ont-déjà-dépassé-r) précise le cas d'une perte supérieure à R.

## Maintenir les ordres chez le courtier

Après le calcul, comparer les lignes de Jedi aux ordres réellement actifs. Annuler les ordres devenus caducs, puis modifier ou replacer ceux qui doivent l'être. Vérifier le récapitulatif du courtier : sens, mode, quantité, prix et durée de validité.

Une vente peut réduire le stock disponible pour un autre ordre de vente. Le courtier et Jedi ne coordonnent pas automatiquement les ordres entre eux. Après une exécution, vérifier les ordres restants avant de les conserver.

Lorsqu'un StopLoss et une vente Limit doivent coexister, `trade orders --net-stop` peut afficher une quantité de StopLoss diminuée de la quantité de la vente à la hausse. Cette option ne crée aucun lien d'annulation entre les ordres chez le courtier ; leur coordination reste à votre charge.

## Enregistrer une vente réelle

Notre exemple suppose la vente confirmée de 6 titres à 11 €, avec 0,23 € de frais. L'enregistrer :

~~~console
jedidemo operation create Exa_01 \
  --date=2026-09-22 --time=10:15:00 \
  --type=Sell --mode=Limit --quantity=6 --price=11 --fees=0.23
jedidemo operation list Exa_01 -c 0,6-14,17
jedidemo trade status Exa_01
jedidemo trade orders Exa_01
~~~

Le stock passe à **94 titres**. L'investissement net hors frais passe de 1 000 € à **934 €**, puisque la vente a rapporté 66 €. La position devient `0:0:+1`.

Voici les ordres recalculés, avec les arrondis au pas de cotation de notre exemple :

| Type | Mode | Quantité | Cours | Montant hors frais |
|---|---|---:|---:|---:|
| Buy | Limit | 6 | 9,90 € | 59,40 € |
| Sell | Limit | 6 | 12,11 € | 72,66 € |

Reprendre ces nouvelles valeurs chez le courtier. Un ordre seulement expiré, annulé ou non exécuté ne crée aucune opération Jedi.

## Traiter une exécution partielle

Plusieurs fragments d'un même ordre doivent être regroupés dans **une seule opération consolidée**. Chaque enregistrement d'opération peut faire avancer la position mécanique ; enregistrer les fragments comme des étapes successives fausserait le parcours de cet ordre.

Dans la vente de notre exemple, le courtier peut avoir exécuté :

| Fragment | Quantité | Prix | Heure | Frais |
|---|---:|---:|---|---:|
| Premier | 2 | 11,00 € | 10:14:00 | 0,10 € |
| Second | 4 | 11,00 € | 10:15:00 | 0,13 € |
| À enregistrer | 6 | 11,00 € | 10:15:00 | 0,23 € |

La commande de vente ci-dessus enregistre cette consolidation. Si les prix diffèrent, utiliser leur moyenne pondérée par les quantités, le total des frais et l'heure du dernier fragment.

Tant que le solde peut encore être exécuté, attendre que la situation se stabilise avant l'enregistrement. Pendant cette attente, l'état Jedi est provisoirement en retard : ne pas s'en servir pour lancer une autre série d'ordres.

Si vous décidez de conserver et d'enregistrer seulement la partie exécutée, **annuler immédiatement le reliquat chez le courtier et vérifier l'annulation avant de replacer des ordres recalculés**. Reprendre uniquement la quantité effectivement exécutée. Le trade continue avec son stock réel.

Un prix moyen de plusieurs exécutions peut ne pas respecter le pas de cotation. Jedi contrôle normalement ce pas. Pour enregistrer un prix moyen attesté par le courtier sans l'arrondir artificiellement, le préfixe `+` désactive ce contrôle pour cette saisie : par exemple `--price=+11.013333`. Il ne majore pas le prix. Cette forme sert à reporter une exécution réelle, pas à contourner le contrôle des prix d'ordre.

## Garder une trace avec note

Les opérations donnent les mouvements du stock et de trésorerie. `note` permet de conserver le contexte d'un événement exceptionnel : exécution partielle, annulation, interruption du suivi, incident ou décision particulière.

Pour écrire plusieurs lignes, ouvrir les guillemets du contenu et les fermer seulement après la dernière ligne :

~~~console
$ jedidemo note create 2026-09-22 "Exa_01 - vente partielle" "Vente de 6 titres :
> 2 puis 4 titres à 11 EUR. Exécution terminée à 10:15.
> Frais totaux : 0,23 EUR. Une seule opération consolidée enregistrée."
~~~

`$` et `>` représentent les invites du terminal : ne pas les saisir. Tant que les guillemets restent ouverts, le terminal continue la même commande ; les retours à la ligne sont conservés dans la note. Cette syntaxe convient aussi aux textes longs qui seraient coupés à l'impression sur une seule ligne.

~~~console
jedidemo note list Exa_01
~~~

Dans une base sans note préalable, cette note porte le numéro 1. Utiliser le numéro réellement affiché pour la consulter ou la compléter :

~~~console
jedidemo note show 1
jedidemo note update 1 --edit
~~~

`--contents` reste disponible et remplace tout le contenu, qui peut aussi être saisi sur plusieurs lignes. Conserver le texte précédent lorsque vous le complétez.

### Rédiger avec un éditeur

L'option **`--edit`** facilite la création ou la modification d'une note. Jedi utilise le programme indiqué par `VISUAL`, ou par `EDITOR` si `VISUAL` est absente. Ces variables doivent contenir le nom ou le chemin de l'exécutable, par exemple `nano`.

Dans le terminal Ubuntu ou Linux, si ce réglage n'a pas encore été fait au chapitre 02 :

~~~bash
export EDITOR=nano
export VISUAL=nano
~~~

Puis créer une note :

~~~console
jedidemo note create --edit
~~~

L'éditeur ouvre un modèle contenant trois repères, à conserver dans cet ordre. Voici un exemple rempli ; les noms des repères restent en anglais, même pour une note française :

~~~text
# Date
2026-09-22

# Summary
Exa_01 - vente partielle

# Contents
Vente de 6 titres : 2 puis 4 titres à 11 EUR.
Exécution terminée à 10:15 ; frais totaux 0,23 EUR.
Une seule opération consolidée enregistrée.
~~~

Dans nano, enregistrer avec **Ctrl+O**, confirmer le nom avec **Entrée**, puis quitter avec **Ctrl+X**. Quitter le modèle sans le modifier annule la création. Pour reprendre une note existante, `jedidemo note update 1 --edit` ouvre son contenu actuel : remplacer 1 par son identifiant. Ne pas combiner `--edit` avec les options de champs `--date`, `--summary` ou `--contents`.

Les notes constituent un journal général ; indiquer le nom du trade dans le résumé ou le texte permet de les retrouver. Il n'existe pas de rattachement automatique au trade. Une note ne remplace ni l'opération exécutée ni son enregistrement.

Après ce suivi, l'exemple Exa_01 possède 94 titres. Le [chapitre 09](09_adapter_ou_terminer_un_trade.md) part de cet état pour présenter les adaptations possibles et la clôture.
