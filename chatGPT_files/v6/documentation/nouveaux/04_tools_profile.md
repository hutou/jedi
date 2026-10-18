# Présélectionner avec tools profile

## Ce que fournit la commande

`profile` décrit le comportement d'un titre et compare une population pour aider à établir une liste de choix. Il examine la qualité des cotations, applique des règles d'élimination et de vigilance, puis classe les titres conservés.

Le classement est transparent : il additionne des rangs, sans pondération. Le lecteur peut choisir combien de critères participent au total et consulter les valeurs qui expliquent les rangs.

## Préparer les exemples

Les exemples calculés de ce chapitre utilisent trois titres fictifs. Leurs fichiers sont dans **examples/**, à la racine de l'archive de documentation ; le [guide des exemples](../../examples/README.md) explique les réglages et le répertoire de travail.

Pour les commandes `--database=demo --dataset=Demo`, effectuer d'abord [la préparation de la base Demo au début du chapitre 10](10_base_de_cotations.md#la-base-demo-des-exemples), jusqu'à la mise à jour des trois titres au 2 octobre 2026. Cette étape crée la base ; `profile` ne la crée pas.

La commande utilisant [cotations_EXA.txt](../../examples/cotations_EXA.txt) lit directement ce fichier depuis `examples/` et ne demande aucun import. Les exemples `abcbourse` et `Euronext_A` ci-dessous supposent, eux, que ces données ont été préparées par l'utilisateur.

## Choisir la population

~~~console
jedidemo tools profile --database=abcbourse --dataset=Euronext_A --rank-criteria=4
~~~

`--database` choisit la source d'une base de marché. `--dataset` choisit un ensemble importé. L'univers utilisé dans le nom de la base vient de la configuration, ou de `--universe` s'il est précisé.

Autres choix possibles :

| Besoin | Options |
|---|---|
| Tous les membres d'un groupe | `--group=PEA` |
| Membres du groupe appartenant à un dataset | `--dataset=Euronext_A --group=PEA` |
| Un titre identifié dans la base | `--security=RNO` ou son ISIN |
| Plusieurs titres identifiés | Répéter `--security` |

Un fichier individuel peut aussi être examiné :

~~~console
jedidemo tools profile cotations_EXA.txt
~~~

Avec un fichier, le rapport décrit un titre ; il n'établit pas de classement transversal ni de référence de fraîcheur du dataset.

## Une fenêtre récente et un historique de contrôle

La tendance, la liquidité, l'oscillation, le recul maximal, les gaps et le pas suggéré utilisent les **252 dernières séances** du titre. La volatilité utilise un **ATR sur 20 séances**. L'ATR est une moyenne de l'amplitude réelle quotidienne, qui tient compte des écarts avec la clôture précédente ; il est exprimé en pourcentage de la dernière clôture.

252 séances correspondent approximativement à une année de bourse. Cette fenêtre décrit le comportement récent. Pour vérifier la qualité et la continuité des données, Jedi conserve toutefois l'historique plus long.

Les principaux contrôles de qualité demandent au moins **trois années d'historique** et une **densité minimale de 180 cotations par an en moyenne**, sur l'ensemble de cet historique. Pour calculer cette densité, Jedi divise le nombre de cotations disponibles par la durée entre la première et la dernière date, exprimée en années de 365,25 jours.

**180 est un seuil de contrôle fixé dans Jedi**, destiné à écarter un historique trop clairsemé. Il ne décrit pas le nombre habituel de séances d'une année de bourse et ne remplace pas la fenêtre récente de 252 séances. La moyenne porte sur toute la période ; elle ne garantit pas que chaque année est complète.

Des cotations OHLC incohérentes, trop de séances sans volume ou trop de clôtures inchangées peuvent également éliminer le titre. Ces exigences expliquent pourquoi un fichier limité à 252 lignes peut être insuffisant.

Les dates réellement étudiées figurent dans le rapport individuel. Les séances disponibles dans chaque historique déterminent la fenêtre : un titre en retard peut avoir une fenêtre décalée.

## Lire les statuts

| Statut | Sens pratique |
|---|---|
| Retenu | Aucune cause d'élimination ni de vigilance détectée par ces contrôles. |
| Vigilance | Le titre reste dans la liste classée, avec des points à examiner. |
| Écarté | Au moins une règle d'élimination est déclenchée. |

Les règles principales sont :

| Mesure | Élimination | Vigilance |
|---|---|---|
| Tendance annualisée | Inférieure ou égale à −12 % par an | Lire aussi le parcours et les autres mesures. |
| Médiane quotidienne de clôture × volume | Inférieure à 100 000 € pour les exemples en euros | Plus de 30 % des séances sont sous ce montant. |
| ATR20 | Inférieur à 1,5 % | Supérieur à 6 %. |
| Oscillations d'au moins 5 % | — | Moins de quatre par an. |
| Recul maximal | — | Supérieur à 45 %. |
| Gaps d'au moins 3 % | — | Présents sur plus de 3 % des séances. |
| Retard de cotation | Plus de deux séances | Une ou deux séances. |

La médiane est la valeur centrale des montants journaliers : elle réduit l'influence de quelques journées exceptionnelles. La tendance est une mesure calculée à partir de l'ensemble de la fenêtre, pas simplement la différence entre son premier et son dernier cours.

La liquidité est mesurée dans l'unité monétaire des prix importés. Le seuil numérique de 100 000 n'effectue aucune conversion de devise. Lorsqu'on utilise des données hors euro, leur unité doit être prise en compte.

## Les sept critères, dans leur ordre de classement

| Ordre | Critère | À regarder |
|---|---|---|
| 1 | Tendance, `Tend%/a` | Une orientation moins défavorable ou plus favorable reçoit un meilleur rang. |
| 2 | Liquidité, `Val.méd` | Un montant médian échangé plus élevé reçoit un meilleur rang. |
| 3 | Volatilité, `ATR%` | Jedi classe d'abord des plages de volatilité, puis départage les valeurs dans la même plage. |
| 4 | Oscillation, `Sw5/a` et `Range%` | Nombre d'oscillations et amplitude ; les classes tiennent compte des deux mesures. |
| 5 | Recul maximal, `DD%` | Un recul plus faible reçoit un meilleur rang. |
| 6 | Gaps, `Gap%` | Une fréquence plus faible reçoit un meilleur rang. |
| 7 | Pas suggéré, `Pas%` | Un pas plus faible reçoit un meilleur rang. |

Pour la volatilité, la plage 2 à 5 % est classée avant les plages 1,5 à moins de 2 % et plus de 5 à 6 %. Une volatilité encore plus élevée appelle de la vigilance. « Plus volatil » ne signifie donc pas systématiquement « mieux classé ».

L'oscillation privilégie des mouvements d'au moins 5 % assez fréquents, accompagnés d'une amplitude suffisante. `Sw5/a` compte le premier mouvement significatif puis les retournements, ramenés à une année ; il ne compte pas des allers-retours complets ni des opérations Jedi. Le rapport individuel et l'aide expliquent les plages utilisées :

~~~console
jedidemo tools profile --help
~~~

`Mouv/a` estime l'activité associée au pas suggéré. Il s'agit d'une information complémentaire ; ce n'est pas un huitième critère de classement. Le pas proposé est un point de départ pour examiner un barème.

## Commencer avec les quatre principaux critères

L'option `--rank-criteria=4` additionne les rangs de tendance, liquidité, volatilité et oscillation. C'est une lecture simple pour commencer.

Le défaut du programme reste **sept critères** :

~~~console
jedidemo tools profile --database=abcbourse --dataset=Euronext_A
~~~

`--rank-criteria=N` accepte un nombre de 1 à 7. Il utilise les **N premiers critères dans l'ordre ci-dessus**. Les critères suivants restent affichés et leurs alertes restent actives.

Dans la colonne `Rangs`, la barre verticale sépare les rangs retenus des rangs seulement informatifs. Par exemple, `1/2/3/2 | 4/3/2` donne un total de 8 avec quatre critères. Cet exemple de somme est illustratif.

Deux valeurs identiques reçoivent le même rang. Le total le plus faible vient en premier ; en cas d'égalité, les rangs retenus sont comparés dans leur ordre, puis le ticker. Modifier la population peut modifier les rangs et les totaux.

## Lire un exemple calculé

Après [la création et la mise à jour de la base Demo décrites au début du chapitre 10](10_base_de_cotations.md#la-base-demo-des-exemples), lancer depuis `examples/` :

~~~console
jedidemo tools profile --database=demo --dataset=Demo \
  --rank-criteria=4 --include-rejected
~~~

Voici une sélection de colonnes de la sortie obtenue ; la table est abrégée pour la lecture :

| Ticker | Total | Tendance/an | Valeur médiane | ATR20 | Oscillations/an | Statut |
|---|---:|---:|---:|---:|---:|---|
| EXA | 4 | 3,7 % | 774 k€ | 3,4 % | 8,3 | retenu |
| EXB | — | −27,4 % | 377 k€ | 3,1 % | 11,4 | écarté |
| EXC | — | −0,5 % | 12 k€ | 1,1 % | 0,0 | écarté |

EXB possède de la liquidité et des oscillations, mais sa tendance suffit à l'écarter. EXC est écarté pour liquidité et volatilité insuffisantes. EXA est le seul titre classé ; il reçoit donc le rang 1 sur chacun des quatre critères.

`--include-rejected` affiche les titres écartés avec un tiret pour le total et les rangs. Leur présence ne change pas le classement des autres titres. Les lignes portant « vigilance » restent, elles, dans le classement.

Pour comprendre les motifs, consulter le titre individuellement :

~~~console
jedidemo tools profile --database=demo --security=EXA
~~~

## Comprendre la fraîcheur

Jedi utilise la date de fraîcheur globale du dataset : la dernière date atteinte par **au moins 95 % de ses titres**. Cette date est recalculée à partir des cotations présentes après import ou mise à jour.

Le retard est compté en séances présentes dans la base du dataset, jusqu'à cette référence. Il vaut zéro si le titre a atteint ou dépassé la référence, une ou deux séances pour la vigilance, plus de deux pour l'élimination.

Cette mesure compare les titres du dataset entre eux. Elle ne mesure pas l'écart avec la date du jour : si tout le dataset a arrêté de recevoir des cours, vérifier la date affichée dans `market info`.

Le contrôle de fraîcheur est indisponible avec un fichier ou une sélection historique `--date` ou `--select`. Il est aussi indisponible si la référence du dataset manque, ou si un titre appartient à plusieurs datasets sans qu'un `--dataset` explicite lève l'ambiguïté. Un tiret dans `Ret.` signifie « non évalué », pas « à jour ».

## Choisir quelques titres

Commencer par les quatre critères principaux, puis lire les alertes et les trois critères complémentaires. Examiner un recul important ou des gaps fréquents avant de retenir une ligne bien classée.

Pour privilégier une lecture particulière, employer un tri nommé :

~~~console
jedidemo tools profile --database=demo --dataset=Demo --sort=liquidity
jedidemo tools profile --database=demo --dataset=Demo --sort=oscillation
~~~

Les noms d'options restent en anglais dans les deux langues. `--limit=20` limite les lignes affichées ; il ne réduit pas la population analysée pour calculer les rangs.

Retenir quelques titres compréhensibles, puis examiner leurs barèmes avec `score` et leurs projets avec `candidate`. Le classement aide à organiser ce choix ; le prix d'entrée, les quantités et le financement sont étudiés séparément.
