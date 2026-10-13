# Mise à jour documentaire — préparation de Jedi 1.1

Cette édition part exclusivement de `jedi_documentation_20261012.zip`. Elle décrit
le correctif `split + reinit` intégré à `next-version`, avec les conventions de
nommage retenues pour les trades et les barèmes. Elle contient tous les Markdown
français et anglais ; elle accompagne une version en développement.

## Changements de fond

| Chapitres | Mise à jour |
|---|---|
| 00 et README | Périmètre de next-version, distinction avec la version publiée 1.0.0 et les anciens PDF. |
| 02 | Compilation rapide vers `bin/jedi-dev`, compilation optimisée vers `bin/jedi`, sélection par `jedidev`. |
| 07 et 13 | Conventions de nommage ; différence entre numéro de trade, version de barème et paramétrage. |
| 09 | Combinaisons autorisées et refusées ; prix après split ; cas de 1 790 → 179 actions ; reset et merge ; rompus. |
| 15 | Prix de référence utilisé immédiatement après un reset de type II. |
| 16 | Conversion du stock avant réinitialisation ; nouvelles références ; conservation de l'historique. |
| 17 et 18 | Stock et position effectifs pour ordres, projections et stops ; attente d'une opération manuelle avec merge. |
| 19 | Simulations complètes et reproductibles du regroupement avec reset ou merge. |
| Annexes 01 et 04 | Référence des options, restrictions et nouvelles définitions du glossaire. |
| Annexe 05 FR/EN | Configuration intégrée complète, valeur et usage de chaque entrée, champs non utilisés, distinction entre capital personnel et valeur intégrée. |

Les exemples des chapitres 08, 11, 14, 20 et de l'introduction de partie II reprennent
les nouveaux noms pour conserver la cohérence du parcours. Les 37 fichiers
existants modifiés comprennent 18 paires français/anglais et le README. La note
de mise à jour et les deux versions de l’annexe 05 sont ajoutées.

## Nouveaux noms des exemples

| Ancien nom | Nom dans cette édition |
|---|---|
| `EXA01` | `Exa_01` |
| `EXA_LONG` | `Exemplea_01` — variante de correction d'un repère |
| `EXA-10` | `B2_vr10_ki10_v01` |
| `EXA-12` | `B2_vr12_ki10_v01` |
| `EXA-I` | `B1_sync_v01` |
| `PEDA-I` | `B1_example_v01` |
| `PEDA-I-AUTO` | `B1_example_auto_v01` |
| `PEDA-II-AUTO` | `B2_example_auto_v01` |

Ces changements concernent les textes et les commandes du manuel. Une base
existante conserve ses noms enregistrés : utiliser ces noms réels ou effectuer
un renommage explicite. Les tickers EXA, EXB, EXC et GAP et les noms des fichiers
de cotations restent ceux des données fictives fournies.

Les conventions restent un choix de nommage : Jedi lit les paramètres du
constructeur, pas ceux qui semblent figurer dans le nom. Un split ou un reinit
conserve l'identité du trade. Une nouvelle définition d'un barème déjà utilisé
reçoit un autre nom ou une autre version.

## Vérifications

Les nouveaux scénarios de `tools play` sont exécutés avec le binaire du correctif :

- Reset : 179 titres et référence 12 €, vente de 36 à 13,20 €, puis achat de 36 à
  11,87 € ; le stock revient à 179.
- Merge avec achat : 21 nouvelles actions à 10 €, stock et `q0` de 200, `c0` de
  11,79 €, puis vente de 40 à 11 €, laissant 160 titres.
- Merge avec vente : 20 nouvelles actions à 14 €, stock et `q0` de 159, `c0` de
  11,7484 €.

Le parcours d'ouverture et de suivi des chapitres 07–08 est également rejoué
avec les nouveaux noms, ainsi que les variantes du chapitre 09 dans des copies
séparées d'une base fictive. Les contrôles comprennent **63 commandes CLI**, dont
la préparation des bases d'essai et dix commandes `play` distinctes des chapitres
16 et 19. Pandoc analyse les **70 fichiers Markdown et leurs 216 tableaux** ; les
nouveaux liens internes sont valides. Les dépendances extérieures à l'archive
(fichiers d'installation, exemples et fichiers de génération PDF du dépôt complet)
doivent être disponibles lors de l'utilisation de ces renvois.

Les tests du correctif sont validés dans le dépôt complet par **527 exemples,
0 échec, 0 erreur, 0 en attente**, résultat communiqué par l'auteur après intégration.

## Vérification de la configuration

L’annexe 05 couvre les **70 valeurs élémentaires** de la configuration intégrée,
y compris les éléments des listes. Le bloc YAML de chaque langue est comparé à
la configuration affichée par le binaire avec un fichier personnel vide. Les
usages sont suivis dans le code. Les valeurs intégrées de `trading.capital` et
`simulation.capital` sont toutes deux 20 000 ; le remplacement personnel à
50 000 pour les deux capitaux est montré séparément.

Les champs API `symbol_path`, `change_path` et les transformations Boursorama
placées sous `candidates[2].ops.ticker` sont signalés comme non utilisés.
Un parcours `play` confirme que modifier `simulation.distance` ou
`simulation.risk_rate` ne modifie pas la protection, tandis que modifier
`money.r` la modifie. L’exemple complet de l’annexe est exécuté avec 50 000 de
capital simulé ; les commandes de consultation et de style sont vérifiées.
Les fournisseurs externes ne sont pas interrogés pour cette vérification.

## PDF et publication

Les fichiers de cette archive sont les Markdown. Les PDF de Jedi 1.0 ne reflètent
pas ces modifications. Leur régénération utilise `pdf/build.sh` et les fichiers
de génération du dépôt complet, selon le README. Le numéro de version des
exemples d'installation devra être adapté à la publication effective de Jedi 1.1.

## English update summary

This edition updates both languages from the supplied Markdown archive for the
`next-version` preparation of Jedi 1.1. Chapters 09, 15–19 and appendices 01/04
cover combined split and reset/merge, prices in new units, effective holdings,
pending merge and fractional entitlements. Chapters 07/13 explain naming;
chapter 02 covers development and optimised compilation. Related examples use
the new names consistently.

The complete French/English Markdown set is included. Existing databases retain
their stored names until explicitly renamed. The published 1.0.0 executable
does not support combined split and reinitialisation; use the updated executable.
Rebuild PDFs from the full repository after these changes. Installation examples
retain 1.0.0 until the actual 1.1 publication.

Appendix 05 in both languages documents all built-in configuration entries, their actual uses and currently unused fields. It distinguishes the built-in capitals of 20,000 from personal overrides of 50,000, and explains why play uses money.r and the scale’s n-step projection rather than simulation.risk_rate or simulation.distance.
