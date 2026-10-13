# Glossaire et notations Jedi

## Objets et parcours

| Terme | Sens dans Jedi |
|---|---|
| Titre | Instrument identifié par un ISIN, un nom et un ticker. |
| Barème | Règles qui associent un état mécanique à des prix et quantités cibles. |
| Constructeur | Paramètres permettant de fabriquer un barème ; le préfixe `I:` ou `II:` de `score` annonce son type. |
| Définition opérationnelle | Définition effectivement utilisée après construction et éventuelles transformations ; elle apparaît dans les rapports. |
| Trade | Parcours d'achats et de ventes sur un titre, avec ses paramétrages successifs. |
| Paramétrage | Barème applicable à partir d'une date et d'une heure, avec les éléments nécessaires à sa continuité. |
| Opération | Achat ou vente exécuté et enregistré. Un ordre proposé ne constitue pas une opération. |
| Stock | Nombre de titres détenus à un moment du parcours. |
| Allers-retours | Ventes et achats successifs suivant les déplacements du barème. |
| Opérabilité | Possibilité de produire les ordres contrôlés avec des quantités entières suffisantes. |
| Financement | Possibilité de couvrir l'ouverture et les besoins projetés, en tenant compte des autres trades. |
| Note | Entrée datée du journal ; elle décrit un choix ou un événement et ne modifie pas le trade. |

## Positions et coefficients

| Notation | Sens |
|---|---|
| `x:y:e` | Position : sauts haussiers, sauts baissiers et échelon dans le paramétrage actif. |
| Échelon | Étape locale du barème. |
| Palier | Niveau de référence pour une série d'échelons ; atteindre une borne provoque un saut. |
| `q0`, `c0` | Quantité et prix de référence du trade ; initialement ceux du premier achat. |
| `kc`, `ks` | Listes de coefficients de prix et de stock d'un barème de type I. |
| `vr` | Variation relative servant à construire le pas d'un barème. |
| `np`, `nn` | Nombre d'échelons vers les bornes positive et négative. |
| `sr` | Fraction de stock visée au dernier échelon intérieur haussier du constructeur de compatibilité. |
| `mi` | Paramètre de budget des achats baissiers de ce constructeur, rapporté au montant initial. |
| `ki` | Fraction d'investissement appliquée lors des changements de palier. |
| `kb` | Coefficient de déplacement des prix de palier. |
| `kd` | Paramètre du constructeur qui transforme les quantités ; il ne désigne pas un rendement. |
| `kcb`, `kcp`, `ksp` | Coefficients calculés de capital, de prix et de stock. |
| `cpe`, `spe` | Cours et stock théoriques à une position cible. |
| Type I | Échelle reposant sur des coefficients de référence ; `calc` en vérifie les calculs. |
| Type II | Barème recentré à partir des opérations réelles ; l'examiner avec `play`. |
| Optimisé | Variante de construction ou de continuité ; ce qualificatif ne prouve pas un meilleur gain. |

Les [chapitres 13 à 16](13_lire_la_structure_d_un_bareme.md) donnent le contexte des paramètres. `q0` et `c0` peuvent être redéfinis par une réinitialisation ; lire le paramétrage actif avant de les interpréter comme le tout premier achat historique.

## Split et nouvelle origine

| Notation | Sens |
|---|---|
| `split=NEW:OLD` | Nombre d'actions nouvelles pour les anciennes ; `1:10` est un regroupement de dix pour une. |
| Stock effectif | Stock à utiliser après conversion, même si la dernière opération historique conserve l'ancienne quantité. |
| `reinit=reset,prix` | Nouvelle origine mécanique immédiate ; position `0:0:0`, stock effectif comme `q0`, prix choisi comme `c0`. |
| `reinit=merge,prix` | Nouvelle origine établie par la transaction manuelle suivante ; références en attente jusque-là. |
| `split + reinit` | Combinaison de next-version / v1.1 ; convertir le stock avant reset ou merge, saisir les prix après split. |
| Rompu | Droit fractionnaire issu d'un regroupement ; sa gestion et son règlement ne sont pas comptabilisés par Jedi. |

Le [chapitre 09](09_adapter_ou_terminer_un_trade.md) détaille les effets et les restrictions. Une réinitialisation change les références mécaniques, pas les résultats financiers passés.

## Ordres et protection

| Terme | Sens |
|---|---|
| Limit | Achat à un prix maximal ou vente à un prix minimal. |
| Stop | Ordre déclenché au franchissement d'un niveau ; le prix d'exécution peut s'en écarter. |
| StopLoss | Ordre de protection : coupe-perte ou protection de gains, selon l'état du trade. |
| Pas de cotation, `tick` | Incrément de prix utilisé pour arrondir un ordre. |
| Gap | Écart entre la clôture précédente et l'ouverture suivante ; il peut franchir un niveau sans exécution à ce niveau. |
| `conservative` | Politique OHLC courante, avec priorité aux ordres exécutables à l'ouverture et traitement des gaps. |
| `next` | Ordres issus du premier achat actifs à la séance suivante ; défaut du backtest. |

Le Stop de fonctionnement du barème et la protection StopLoss répondent à des rôles distincts. Les règles détaillées figurent aux [chapitres 17](17_de_l_etat_du_trade_aux_ordres.md) et [22](22_simuler_avec_tools_backtest.md).

## Capital

| Notation | Sens |
|---|---|
| `K` | Capital affecté au trading ; référence monétaire du dimensionnement et du financement. |
| `r` | Fraction de K correspondant au risque nominal d'un trade. |
| `R` | Risque monétaire : `K × r`. |
| `o` | Coefficient d'objectif ; seuil monétaire `O = o × R` avant protection des gains. |
| `n` | Nombre d'échelons baissiers utilisé pour le trajet de risque. |
| `T` | Montant demandé à l'ouverture, hors frais. |
| `money` | Définition `r:...,o:...,n:...` ; les trois champs sont nécessaires. |
| Réserve future | Besoin d'achats supplémentaires projeté sur l'horizon affiché. |
| Marge après candidat | Capital restant après les besoins des trades engagés et du candidat. |
| `diagnostic_steps` | Réglage des contrôles opérationnels, 3 à l'origine ; sa valeur effective apparaît dans l'aide concernée. |

Le risque nominal n'est pas un plafond garanti de perte. La réserve de `candidate` est une projection hors frais sur un horizon ; elle n'est pas la preuve que tous les parcours ultérieurs seraient financés. Voir les [chapitres 06](06_tools_candidate.md) et [18](18_capital_risque_et_dimensionnement.md).

## Données et fraîcheur

| Terme | Sens |
|---|---|
| OHLCV | Ouverture, plus haut, plus bas, clôture et volume d'une séance. |
| Fichier préparé | Cotations identifiées, converties dans le format Jedi et contrôlées avant utilisation. |
| Source | Nom d'une base de marché, par exemple `demo`. |
| Univers | Périmètre général entrant dans le nom de la base, `france` par défaut. |
| Dataset | Ensemble importé, avec ses appartenances, fichiers et métadonnées. |
| Groupe | Liste nommée de titres, indépendante de l'appartenance aux datasets. |
| Dernier import complet | Date et périmètre du dernier import ou remplacement complet ; historique de l'import. |
| Dernière cotation disponible | Date la plus récente présente ; elle peut concerner très peu de titres. |
| Fraîcheur globale | Date atteinte par au moins 95 % des titres du dataset, calculée sur la base réelle après import ou update. |
| Retard individuel | Écart en séances de marché avec cette référence : 0 normal, 1–2 vigilance, plus de 2 écarté. |

La fraîcheur n'est pas calculée par rapport à la date du jour. Un fichier, une sélection historique ou une référence de dataset ambiguë peut ne pas permettre son évaluation. Les [chapitres 04](04_tools_profile.md) et [10](10_base_de_cotations.md) expliquent les cas.

## Critères de profile

| Critère | Lecture |
|---|---|
| Tendance | Direction estimée des clôtures sur 252 séances, exprimée en taux annuel. |
| Liquidité | Médiane de Close × Volume ; montant échangé par séance, en euros si les prix le sont. |
| ATR20 | Moyenne des amplitudes réelles sur 20 séances, incluant les écarts avec la clôture précédente ; exprimée en pourcentage du cours. |
| Oscillation | Amplitude du parcours et mouvements de retournement ; `Sw5/a` compte les mouvements d'au moins 5 % et les annualise. |
| Drawdown | Plus grande baisse depuis un sommet antérieur sur la fenêtre étudiée. |
| Gap% | Fréquence des gaps d'au moins 3 % sur la fenêtre récente. |
| Pas% | Pas de barème suggéré à partir des caractéristiques du titre ; ce n'est pas un ordre imposé. |
| Total | Somme sans pondération des N premiers rangs ; plus faible signifie mieux classé dans la sélection courante. |
| Statut | Retenu, vigilance ou écarté selon les contrôles ; un écarté ne participe pas au classement. |

## Résultats et étude

| Terme | Définition |
|---|---|
| Gain brut | Ventes − achats + stock final valorisé à la dernière clôture, hors frais. |
| Gain net | Gain brut − frais imputés. |
| Investissement courant | Achats − ventes cumulés, hors frais. |
| Investissement maximal | Pic de l'investissement courant sur le parcours. |
| Fitness | Dans `score`, gain brut / montant du premier achat ; couvre toute la période. |
| Inv.max | Dans `score`, investissement maximal / premier achat, hors frais. |
| Op/mois | Toutes les opérations, ouvertures comprises, ramenées à 21 séances à partir de la première opération. |
| Rnet% | Résultat net rapporté à l'investissement maximal dans l'affichage économique. |
| Rann% | Annualisation de ce rapport selon la durée ; elle ne constitue pas une prévision. |
| Recherche adaptive | Exploration puis approfondissement de zones choisies ; le budget limite les barèmes évalués. |
| Recherche grid | Évaluation exhaustive des candidats disponibles selon le constructeur. |
| Classement raw | Tri direct des mesures affichées. |
| Classement jedi | Lecture experte ajoutant des préférences et diagnostics du moteur. |
| Vérification séparée | Test d'un barème fixé sur des données qui n'ont pas servi à le choisir. |
| Suivi daté | Conservation d'une décision à sa date réelle, puis de ses observations ultérieures. |

Voir le [chapitre 24](24_interpreter_comparer_et_suivre.md) pour interpréter ces résultats.
