# Référence des commandes et options

Les valeurs intégrées et l’usage de chaque entrée sont détaillés dans l’[annexe 05](fr_annex05_configuration_par_defaut.md).

## Trouver l'aide de la version installée

Lancer `jedi` sans argument affiche les familles de commandes. Une famille seule, par exemple `jedi tools`, affiche ses sous-commandes. L'aide détaillée s'obtient au niveau de la sous-commande :

~~~console
jedidemo tools backtest --help
jedidemo market import --help
jedidemo note create --help
~~~

`version` et `config` se consultent directement : `jedi version`, `jedi config` et `jedi config --paths`. Ils n'ont pas de sous-commande d'aide. Le fichier livré [jedi-help-fr.txt](../../reference/jedi-help-fr.txt) rassemble les aides de la version de référence ; l'aide de votre exécutable reste celle de la version effectivement utilisée.

Les noms peuvent être abrégés jusqu'à un préfixe non ambigu. Les exemples gardent les noms complets. Les champs nommés et les champs positionnels constituent des formes alternatives : ne pas les mélanger pour les mêmes champs. Entourer de guillemets les noms avec espaces et les expressions contenant des caractères interprétés par le shell.

L'option globale `--border=PRESET` précède la famille de commande. Les styles sont `ascii`, `reducedascii`, `modern`, `reducedmodern`, `fancy`, `markdown`, `empty`, `blank`. `--` termine la lecture des options : il est utile avant des arguments négatifs, notamment dans `play`.

## Portefeuille et journal

| Famille | Sous-commandes | Usage |
|---|---|---|
| `security` | `create`, `update`, `delete`, `show`, `list` | Identité, ticker, pas d'achat et de vente, taxe d'achat du titre |
| `quote` | `get`, `set`, `update`, `refresh` | Interrogation externe, saisie manuelle ou enregistrement de cours courants |
| `scale` | `create`, `update`, `delete`, `show`, `list` | Barèmes de type I ou II enregistrés |
| `trade` | `create`, `update`, `delete`, `show`, `list` | Identité du trade et gestion du capital |
| `trade` | `orders`, `status`, `results`, `plot` | Ordres, situation, résultats et graphique |
| `settings` | `create`, `delete`, `show`, `list` | Barème applicable à une date et une heure, split, synchronisation, réinitialisation |
| `operation` | `create`, `fees`, `delete`, `list` | Exécutions réellement réalisées ; correction des frais par identifiant d'opération |
| `note` | `create`, `update`, `delete`, `show`, `list` | Journal et événements exceptionnels ; `--edit` pour l'éditeur |
| `database` | `dump`, `load`, `schema` | Sauvegarde, restauration et schéma de la base principale |

Les champs obligatoires sont décrits par chaque aide. La suppression d'une entité utilisée peut être refusée ; une suppression d'opération n'est pas son remplacement automatique. Les exemples de correction et d'adaptation figurent aux chapitres 08 et 09.

`quote get ISIN` affiche un cours externe sans enregistrer de titre ou de cotation. `quote set` enregistre un cours manuel. `quote update` actualise un titre enregistré ; `quote refresh` traite une sélection et, par défaut, les titres des trades en cours. `--mode=live|eod` s'applique à `update` et `refresh`, pas à `get`. `--force` appartient à `refresh` ; il permet de forcer la mise à jour selon son filtrage.

## Corriger les frais d'une opération

~~~console
jedidemo operation fees 42 3.50
jedidemo operation fees 42 0
jedidemo operation fees --help
~~~

La syntaxe est `jedi operation fees <operation_id> <amount>`. L'identifiant numérique est celui de l'opération, à lire avec `operation list`, et non celui du trade. Le montant remplace le **total** des frais, taxe éventuelle comprise ; un montant nul les annule. Utiliser un point décimal et une valeur positive ou nulle, arrondie au centime. Une opération ancienne ou d'un trade clôturé peut être corrigée. Les résultats nets, listes et exports reprennent la nouvelle valeur. Les frais historiques sont aussi repris lors d'un nouveau `play` depuis une opération du même trade. Le [chapitre 08](08_suivre_un_trade.md#corriger-les-frais-dune-opération-enregistrée) donne la procédure complète.

## Adapter un paramétrage : split, reinit et sync

Un nouveau paramétrage demande `--scale`, `--date` et `--time`. Il doit suivre les derniers paramétrages et opérations de toute la base ; le paramétrage précédent du trade doit déjà avoir été utilisé par une opération.

| Option ou combinaison | Effet |
|---|---|
| `--split=NEW:OLD` | Convertir les unités ; `1:10` signifie une nouvelle action pour dix anciennes. |
| `--reinit=reset,PRICE` | Stock courant comme `q0`, prix choisi comme `c0`, position `0:0:0`. |
| `--reinit=merge,PRICE` | Référence en attente ; une transaction manuelle réelle définit ensuite `q0` et `c0`. |
| `--split` + `--reinit=reset,PRICE` | Accepté dans next-version / v1.1 ; reset sur le stock entier converti. |
| `--split` + `--reinit=merge,PRICE` | Accepté dans next-version / v1.1 ; merge sur le stock entier converti. |
| `--sync=POSITION` | Synchronisation réservée aux barèmes de type I. |
| `--sync` + `--split` ou `--reinit` | Refusé. |

Avec split + reinit, `PRICE` et les valeurs de l'opération suivante sont exprimés **après le split**. Tant que merge attend son opération, Jedi ne propose aucun ordre automatique. Les droits fractionnaires ne sont pas comptabilisés. Le chapitre 09 fournit les cas pratiques et le chapitre 19 les simulations.

## Bases de marché

| Sous-commande | Arguments principaux | Usage |
|---|---|---|
| `market init` | `SOURCE` | Créer une base de marché |
| `market import` | `SOURCE DATASET QUOTES LABELS` | Importer un dataset complet |
| `market replace` | `SOURCE DATASET QUOTES LABELS` | Remplacer le contenu d'un dataset |
| `market update` | `SOURCE DATASET QUOTES LABELS` | Fusionner sans suppression ; ignorer les doublons et signaler les conflits |
| `market sync-group` | `SOURCE GROUP FILE` | Créer ou synchroniser les membres d'un groupe |
| `market group` | `SOURCE GROUP ISIN` | Ajouter ou retirer un membre avec `--add` ou `--remove` |
| `market info` | `SOURCE` | Métadonnées et contrôles ; `--dataset=CODE` facultatif |
| `market list` | `SOURCE [REGEX]` | Liste ; `--dataset=CODE`, `--last-quote` |
| `market quote` | `SOURCE ISIN` | Historique ; `--date`, `--select` |

`--universe=NAME` sélectionne l'univers, `france` dans la configuration d'origine. Les arguments QUOTES, LABELS et FILE sont des chemins de fichiers. Les formats et les effets des imports, remplacements et mises à jour sont expliqués au chapitre 10.

`import`, `replace` et `update` acceptent `--date-order=auto|ymd|dmy|mdy`, `--year-pivot=NN` et `--from=DATE`. Un update refuse une extension à plus de sept jours calendaires de la fin actuelle, sauf avec `--allow-gap`. Une cotation conflictuelle n'est pas écrasée par update ; reprendre un corpus corrigé avec `replace`. `sync-group` accepte `--as-of=DATE` et `--reference-source=NAME` pour décrire sa composition.

`market list` accepte des expressions regex par champ, dont `group` et `dataset`, avec `&&` et `||`. Cela ne fournit pas une option multi-groupes à `profile`. Jedi expose un seul `--group=CODE` dans `profile` ; aucune commande dédiée ne supprime un groupe. `market quote` affiche un tableau OHLCV et ne propose pas d'export CSV.

## Options communes de consultation

Les filtres regex des listes qui les acceptent sont insensibles à la casse. `champ=motif` cible un champ ; `&&` signifie ET, `||` signifie OU, avec priorité de ET. Les parenthèses ne regroupent pas les conditions logiques, mais restent utilisables dans un motif regex. La liste des champs varie selon la commande : consulter son aide.

Pour `trade list`, le champ `status` reconnaît les codes `created`, `configured`, `opened`, `running`, `closed`, ainsi que les libellés de la langue active. Par exemple, `jedidemo trade list "status=^(opened|running)$"` retient les trades ouverts ou en cours ; `jedidemo trade list "status=^closed$ && name=^T_erf"` retient les trades clôturés dont le nom commence par `T_erf`. Le statut reste calculé à partir de l'historique.

`--running` limite certaines listes aux trades détenant des titres ; pour `trade list`, il conserve les statuts ouvert et en cours et se cumule avec la regex. `--select` choisit des enregistrements après les filtres ; ses indices commencent à 1, les indices négatifs partent de la fin. `fN` et `lN` désignent les premières et dernières lignes ; `I:J` une plage ; la virgule combine les sélections.

Les listes qui proposent `--csv` peuvent ajouter les entêtes avec `--headers`. `--extended` n'a pas un effet universel : pour `operation list` en CSV, il ajoute notamment les noms associés. `--column-indexes` sélectionne des colonnes d'affichage et ne se combine pas avec CSV.

Pour une liste d'opérations lisible :

~~~console
jedidemo operation list -c 0,6-14,17
~~~

Le `o` de `play -c o0,6-14,17` désigne une section ; il ne précède pas les indices dans `operation list`.

## Outils historiques : source et sélection

`profile`, `score`, `backtest`, `plot` et `stats` acceptent un fichier individuel ou `--database=SOURCE --security=IDENT`, avec `--universe` facultatif. IDENT est un ISIN ou un ticker. `profile` ajoute les sélections collectives `--dataset`, `--group` et les `--security` répétés.

Un seul `--date=OP:YYYY-MM-DD` est accepté par commande, avec `ge`, `gt`, `le`, `lt`. Le filtre de date précède `--select`. Répéter `--date` remplace la valeur précédente. Pour isoler une année avec une borne inférieure, figer la source à sa borne supérieure, selon le chapitre 21.

## tools profile

| Option | Rôle |
|---|---|
| `--dataset=CODE` | Sélectionner un dataset |
| `--group=CODE` | Filtrer par un groupe |
| `--include-rejected` | Afficher les écartés sans les classer |
| `--rank-criteria=N` | Additionner les N premiers rangs, de 1 à 7 ; défaut 7 |
| `--sort=KEY` | `global`, `ticker`, `trend`, `liquidity`, `volatility`, `oscillation`, `drawdown`, `gap`, `step` |
| `--limit=COUNT` | Limiter les lignes affichées |

L'ordre des sept critères est tendance, liquidité, volatilité, oscillation, drawdown, gap, pas. Les quatre premiers guident la présélection ; le chapitre 04 explique les choix pratiques et les statuts. Les critères récents utilisent 252 séances, l'ATR 20 ; la profondeur et la fraîcheur sont des contrôles distincts.

## tools score

| Option | Valeurs et défaut |
|---|---|
| `--sort` | `fitness` par défaut ; `activity`, `investment` ; alias 1, 2, 3 |
| `--ranking` | `raw` par défaut ; `jedi`, `both` |
| `--search` | `adaptive` par défaut ; `grid` |
| `--budget` | 500 backtests de recherche par défaut en adaptive |
| `--display` | `compact` par défaut ; `study`, `technical` |

Sans constructeur explicite, la recherche explore les trois familles internes. Les constructeurs positionnels `P1`, `P2`, `P3` sélectionnent une famille pour les usages experts. Par défaut, la sélection retient les 750 dernières séances après filtrage de date.

`raw` trie directement fitness, activité et investissement maximal. `compact` en affiche les 20 premiers avec le constructeur typé. `study` ajoute la lecture économique nette et les frais. `technical` expose les diagnostics et l'influence des paramètres en recherche adaptative.

Le classement expert `jedi` ajoute une préférence fondée sur les contrôles du moteur, notamment l'opérabilité, l'activité et les diagnostics de robustesse ; `both` affiche les deux lectures. Les diagnostics de robustesse examinent les résultats sur des variantes ou découpages ; ils ne garantissent pas le comportement futur. Conserver le classement, l'affichage et la stratégie de recherche avec les résultats. Le chapitre 05 présente le parcours courant en `raw`.

## tools backtest

| Option | Rôle et défaut |
|---|---|
| `--scale=DEF` | Définition littérale ou nom enregistré, requis |
| `--money=DEF` | Gestion du capital ; requise avec `--capital` |
| `--capital=AMOUNT` | Dimensionnement par capital, risque et opérabilité |
| `--distance=COEFFICIENT` | Calcul du montant fixe ; incompatible avec `--capital` |
| `--minimum-quantity=COUNT` | Minimum par ordre contrôlé, défaut 2 ; mode capital |
| `--operability-steps=COUNT` | Échelons contrôlés, défaut 3 ; mode capital |
| `--execution=MODE` | `conservative` par défaut ; `legacy` |
| `--opening-day-orders=WHEN` | `next` par défaut ; `same` |
| `--display=MODE` | `compact` par défaut ; `technical` |
| `-c`, `--command=COMMANDS` | Sections `r`, `f`, `o`, `t`, `d`, `p` |

Sans `--capital`, le montant est calculé à partir de la configuration de simulation ; il n'existe pas d'option `--amount` pour `backtest`. Le rapport compact utilise `r` par défaut, le technique `rf`. Les sections `T`, `K`, `S` conservent les listes étendues de compatibilité. Voir le chapitre 22 pour les prix de gap, réouvertures et valorisations finales.

## tools candidate

L'ISIN est positionnel et `--scale` est requis. `--price` remplace le cours enregistré et permet d'examiner un titre non enregistré. Choisir soit `--amount`, soit `--money` ; ces deux options sont incompatibles. `--capital` fournit K pour le financement et, avec `money`, le dimensionnement ; sinon K vient du capital dédié configuré.

`--minimum-quantity` vaut 2 par défaut ; `--operability-steps` vaut `diagnostic_steps`, soit **3 dans la configuration d'origine**. L'aide affiche sa valeur effective. `--extended` expose le détail du dimensionnement. L'opérabilité et le financement sont expliqués séparément au chapitre 06.

## Définitions des barèmes

Les signatures reconnues par `scale create --builder=...` et par les outils sont :

| Champs | Forme |
|---|---|
| `kc,ks,ki,kb` | Type I avec listes de prix et de stocks explicites |
| `kc,ki,kb,kd` | Type I avec construction optimisée de `ks` |
| `vr,ks,ki,kb` | Type II avec liste de stocks explicite |
| `vr,np,nn,ki,kb,kd` | Type II avec construction optimisée de `ks` |
| `vr,np,sr,nn,mi,ki,kb` | Type II, constructeur de compatibilité |

Sans `--name`, `scale create --comment=... --builder=...` attribue `B_kc_NN` pour le type I ou `B_vr_NN` pour le type II, Legacy compris. Le numéro suivant est calculé séparément dans chaque famille. Un nom explicite doit être conforme au type et avoir un numéro positif d’au moins deux chiffres. Les définitions opérationnelles équivalentes sont refusées à la création et à la modification, même avec `--force`. Le [chapitre 13](13_lire_la_structure_d_un_bareme.md#nommer-et-numéroter-un-barème) détaille les règles et la conservation des anciennes données.

`kc` et `ks` sont des listes décimales ; `np`, `nn`, `kb` sont des entiers. `vr`, `sr`, `mi` et `ki` acceptent un coefficient décimal ou un pourcentage ; `kd` est décimal. Employer le point décimal : `kc:1.4,1.2,0.8,0.6`. Les virgules séparent les valeurs et les champs.

Dans le constructeur de compatibilité, `sr` définit la fraction de stock visée au dernier échelon intérieur haussier ; `mi` règle le budget des achats intérieurs baissiers rapporté au montant initial. Les compteurs `np` et `nn` comprennent les bornes ; il reste `np-1` et `nn-1` échelons intérieurs. Cette forme a ses propres règles : examiner la définition opérationnelle et les ordres avec `scale show` et `play` avant de la comparer aux autres.

## tools calc, play, plot et stats

`calc` accepte les fonctions `kcb`, `kcp`, `ksp`, `cpe`, `spe`, `quantity`, `price`, avec les paramètres `clé=valeur` nécessaires. Il calcule la mécanique du **type I**. `play` convient aux types I et II, à un état créé ou à un identifiant d'opération existante. Ses arguments décrivent les déplacements, prix cibles, transactions ou changements de paramètres.

Dans `play`, `-c o0,6-14,17` choisit les colonnes d'opérations ; ajouter `16` pour les frais. Les sections sont `t`, `k`, `s`, `c`, `o`, `r`, `f`, `d` ; `--verbose` développe les messages. Le chapitre 19 fournit des commandes complètes. Des arguments aléatoires, comme le déplacement `0`, demandent une attention particulière à la reproductibilité.

`plot` trace le cours et sa régression ; `--legend=tl|tr|bl|br` choisit le coin de la légende, sinon automatique. `stats` affiche les indicateurs statistiques de l'historique sélectionné. Ces deux outils complètent l'inspection des données ; leurs sorties ne choisissent pas un investissement à votre place.
