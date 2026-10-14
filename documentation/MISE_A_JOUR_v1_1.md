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
| 07 et 13 | Conventions de nommage ; différence entre numéro de trade, numéro de barème dans sa famille et paramétrage. |
| 09 | Combinaisons autorisées et refusées ; prix après split ; cas de 1 790 → 179 actions ; reset et merge ; rompus. |
| 15 | Prix de référence utilisé immédiatement après un reset de type II. |
| 16 | Conversion du stock avant réinitialisation ; nouvelles références ; conservation de l'historique. |
| 17 et 18 | Stock et position effectifs pour ordres, projections et stops ; attente d'une opération manuelle avec merge. |
| 19 | Simulations complètes et reproductibles du regroupement avec reset ou merge. |
| Annexes 01 et 04 | Référence des options, restrictions et nouvelles définitions du glossaire. |
| Annexe 05 FR/EN | Configuration intégrée complète, valeur et usage de chaque entrée, champs non utilisés, distinction entre capital personnel et valeur intégrée. |
| 05, 22–24 et annexe 04 | Maximum d’investissement des trades successifs, distinction avec le solde financier cumulé, résultats du backtest dans l’ordre de création. |
| 07–09, 24 et annexes 01/05 | Correction du total des frais de toute opération avec `operation fees`, effets sur les résultats nets, les exports et la reprise dans `play`. |
| Annexe 05 FR/EN | Tableaux Web avec cellules courtes, adresses et regex dans des blocs séparés, chemins de configuration décomposés. |
| 03 et 07 FR/EN | Choix externe du titre, lecture des tendances et canaux, indicateurs simples et préparation de l'achat initial sur un rebond près du support. |
| Annexe 04 et chapitre 16 FR/EN | Définitions de `kcpc`, `kspc`, `emax`, `emin` et PRU ; valeurs de départ des coefficients cumulés précisées à 1. |

Les exemples des chapitres 08, 11, 14, 20 et de l'introduction de partie II reprennent
les nouveaux noms pour conserver la cohérence du parcours. Les 47 fichiers
existants modifiés comprennent 23 paires français/anglais et le README. La note
de mise à jour et les deux versions de l’annexe 05 sont ajoutées.

## Nouveaux noms des exemples

| Ancien nom | Nom dans cette édition |
|---|---|
| `EXA01` | `T_exa_01` |
| `EXA_LONG` | `T_exa_01` — même repère fondé sur le ticker pour la variante de renommage |
| `EXA-10` | `B_vr_01` |
| `EXA-12` | `B_vr_02` |
| `EXA-I` | `B_kc_02` |
| `PEDA-I` | `B_kc_01` |
| `PEDA-I-AUTO` | `B_kc_02` |
| `PEDA-II-AUTO` | `B_vr_04` |

Ces changements concernent les textes et les commandes du manuel. Une base
existante conserve ses noms enregistrés : utiliser ces noms réels ou effectuer
un renommage explicite. Les tickers EXA, EXB, EXC et GAP et les noms des fichiers
de cotations restent ceux des données fictives fournies.

Le nom d'un barème indique son type et son numéro ; ses règles proviennent du
constructeur. Le nom est désormais calculé ou contrôlé par Jedi. Un split ou un
reinit conserve l'identité du trade. Créer un autre barème pour une nouvelle
définition déjà utilisée préserve les références des anciennes opérations.

## Nommage automatique et définitions uniques

La convention comporte désormais deux familles : `B_kc_NN` pour le type I et `B_vr_NN` pour le type II, Legacy compris. Le type du builder détermine le préfixe ; le plus grand numéro présent dans cette famille, augmenté de 1, détermine le suffixe quand `--name` est omis. Les noms explicitement fournis sont contrôlés et normalisés. Les exemples des variantes fixent certains numéros pour conserver leurs références dans des bases d'essai indépendantes ; le chapitre 07 utilise la création automatique dans une base vide.

Les créations et modifications refusent les définitions opérationnelles équivalentes, en comparant les règles consommées par le moteur, indépendamment du texte du builder. Le message identifie le barème à réutiliser. Le contrôle et l'écriture sont dans une même transaction ; `--force` ne contourne pas l'unicité. Les simulations réutilisent une définition déjà présente en mémoire.

Les anciens noms et doublons restent conservés. La restauration d'une sauvegarde historique dispose d'un chemin spécifique qui préserve ses noms, ses barèmes et ses références sans perte de données. Les nouveaux contrôles s'appliquent aux créations et changements ordinaires de définition. Aucun renommage global ni suppression de doublon existant n'est effectué.

Vingt-deux nouveaux exemples de régression couvrent l'identité opérationnelle,
les cinq constructeurs, la numérotation indépendante, les collisions de noms,
les modifications refusées sans écriture et la compatibilité des historiques.
La suite applicative compte désormais **559 exemples, 0 échec, 0 erreur,
0 en attente**, sous `TZ=UTC`. Les neuf tests des lanceurs restent exclus ici,
car leurs scripts ne figurent pas dans l'archive de sources. Le binaire est
recompilé ; **111 invocations CLI** sont vérifiées : 63 pour les parcours du
manuel et 48 pour les commandes de barèmes en français et en anglais, y compris
les refus attendus. Les 70 Markdown et leurs 220 tableaux sont analysés ; aucun
nouveau lien interne invalide n'est introduit. Les deux annexes 05 restent
identiques à l'édition précédente corrigée pour les tableaux Web.

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
16 et 19. Pandoc analyse les **70 fichiers Markdown et leurs 220 tableaux** ; les
nouveaux liens internes sont valides. Les dépendances extérieures à l'archive
(fichiers d'installation, exemples et fichiers de génération PDF du dépôt complet)
doivent être disponibles lors de l'utilisation de ces renvois.

Les tests du correctif split + reinit ont été validés dans le dépôt complet par **527 exemples,
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

## Maximum d’investissement du backtest

Le maximum utilise les pics individuels des trades qui se succèdent sans
chevauchement. Les gains et pertes passés restent dans le bilan cumulé, avec
les frais et les valorisations utilisés pour les résultats financiers. Le
rapport compact, le rapport technique et le total du tableau `f` partagent
le même maximum ; `f` suit l’ordre de création des trades. Le solde financier
est nommé « solde achats–ventes » dans ces rapports.

Les mesures dérivées du maximum changent également dans `score`, qui réutilise
le même moteur : Inv.max, rendements sur le maximum et critères liés à ce
montant. Les captures des études des chapitres 05 et 23 restent identifiées
comme références de l’édition 1.0 ; les fichiers de cotations correspondants
ne sont pas dans l’archive Markdown, et ces études doivent être relancées
avec le binaire corrigé pour obtenir leurs chiffres actualisés.

Trois nouveaux exemples de régression couvrent une perte avant réouverture,
un gain avant un trade plus important, la cohérence des rapports et le tri.
Avant correction, les vérifications correspondantes échouaient. La suite
applicative vérifiée sous `TZ=UTC` contient **521 exemples,
0 échec, 0 erreur, 0 en attente**. Les neuf tests des lanceurs ne sont pas
exécutés ici, car leurs scripts ne figurent pas dans l’archive de sources.

## Correction des frais enregistrés

`jedi operation fees <operation_id> <amount>` remplace le total des frais d'une
opération choisie par son identifiant numérique. La correction fonctionne sur
une opération ancienne et sur un trade clôturé. Un montant nul annule les frais ;
les valeurs sont arrondies au centime et les montants invalides sont refusés.
La configuration de frais et la taxe ne sont pas ajoutées au montant corrigé.

Les ordres, positions, stocks, références et investissements hors frais restent
identiques. Les listes, CSV et sauvegardes reprennent le nouveau montant.
`trade results` utilise les frais corrigés pour son bilan net. Une nouvelle
simulation `play` depuis une opération du même trade reprend les frais
historiques concernés ; ses nouvelles opérations continuent d'utiliser la
configuration. Les études `backtest` et `score` génèrent leur propre historique.

Seize nouveaux exemples de régression couvrent les corrections anciennes,
la clôture, les valeurs nulles, les arrondis, les identifiants sur 64 bits,
les limites de stockage, les refus sans écriture, les sorties et les ordres.
Les **20 exemples ciblés** et les **537 exemples de la suite applicative**
passent sous `TZ=UTC`, sans échec, erreur ni exemple en attente. Les neuf tests
des lanceurs restent exclus ici, leurs scripts étant absents de l'archive de
sources. Le binaire est recompilé et **34 commandes CLI** sont vérifiées en
français et en anglais dans des bases fictives séparées.

## Rendu des tableaux Web de l'annexe 05

Les tableaux conservent des indications courtes dans « Usage effectif ».
Les explications détaillées, adresses et regex sont placées dessous. Pour
Tradingsat, les entrées de `name_slug` possèdent leur propre tableau sous leur
préfixe complet ; les cellules ne répètent donc pas un long chemin.

Les chaînes YAML longues utilisent des continuations échappées : aucun
caractère n'est ajouté aux regex. Les six motifs des trois sites et toute la
configuration intégrée sont comparés à l'édition précédente. Les deux blocs
YAML complets sont aussi relus par Jedi et donnent les mêmes valeurs effectives.
Les extraits Web français et anglais sont rendus avec Pandoc et XeLaTeX, puis
leurs quatre pages sont contrôlées visuellement, sans débordement des colonnes
ou des marges. Le PDF complet sera régénéré avec les fichiers de génération
du dépôt, qui ne sont pas fournis dans l'archive Markdown.

## Sélection visuelle et entrée sur rebond

Les chapitres 03 et 07 des deux langues sont complétés. Le chapitre 03 présente
plusieurs voies de sélection et plusieurs sites boursiers : ProRealTime,
TradingView, Boursorama et Zonebourse. La méthode de lecture est indépendante
de la plateforme. Elle couvre les canaux latéraux ou haussiers avec oscillations,
les supports et résistances, la durée d'observation, les vues hebdomadaire et
journalière, la moyenne mobile, l'ATR et le RSI. Le chapitre 07 distingue le
titre retenu du moment de l'achat initial : retour près du support, puis premier
rebond reconnu selon un critère observable choisi à l'avance.

Le canal et les deux séances de l'exemple sont entièrement fictifs ; ils ne
proviennent pas du fichier historique EXA. Le cours d'exécution reste distinct
de la clôture qui a permis d'observer le signal. À 10 €, le barème déjà décrit
propose une première vente à 11 €, sous la résistance fictive de 12 €.
La poursuite d'une baisse sous le support doit rester financée. Les tracés de
la plateforme ne deviennent pas des règles d'ordres ou de protection dans Jedi.

Deux figures PNG, français et anglais, montrent le canal et la reprise ; elles
accompagnent les **70 fichiers Markdown**. L'archive comporte désormais
**228 tableaux**. Les chemins des images et les nouveaux renvois sont contrôlés.
Les exemples de commandes existants restent identiques. Un parcours `play`
vérifie les deux niveaux de vente à 11 € puis 12,11 € avec le pas de 0,01 € de
l'exemple. Les chapitres 03/07 sont rendus et contrôlés en PDF dans chaque langue ;
le PDF complet reste à régénérer avec les fichiers du dépôt. Le README indique
le chemin de ressources nécessaire aux figures dans Pandoc.

## Compléments du glossaire et nom de l'archive

L'annexe 04 française et anglaise définit désormais `kcpc`, `kspc`, `emax`,
`emin` et PRU. Les coefficients cumulés assurent la continuité entre
paramétrages ; ils valent 1 au départ et à la réinitialisation. Les bornes
déclenchent un saut de palier et un retour de `e` à zéro. Le PRU comptable
du courtier est distingué de `c0` et du solde achats moins ventes de Jedi.
Le chapitre 16 de chaque langue précise également le retour des coefficients
à 1, pour éviter de le confondre avec une remise à zéro.
Les entrées voisines `kc/ks` et `kb` sont alignées sur le code : `ks` concerne
les deux types de barème et `kb` choisit la convention de calcul du coefficient
de capital aux changements de palier.

L'archive complète porte maintenant le nom **`jedi_documentation_20261012_v7.zip`**
et remplace la v6 téléchargée précédemment. Elle conserve les 70 Markdown,
les 228 tableaux et les deux figures PNG de la sélection visuelle. Les cinq
définitions sont vérifiées dans le code, sauf PRU, notion extérieure à la
mécanique de Jedi dont la définition au comptant est sourcée chez BoursoBank.
Les renvois et le rendu des deux glossaires sont contrôlés.

## Convention des noms de trades — édition v8

Les noms des trades suivent désormais la convention **`T_<ticker>_<numéro>`**,
par exemple `T_erf_01`. Le chapitre 07 précise sa saisie manuelle, la
numérotation et la normalisation de la casse. Les exemples français et anglais
utilisent `T_exa_01` pour le titre fictif EXA et `T_exr_01` pour EXR. Le chapitre
09 illustre le renommage d'un ancien `Exa_01` en `T_exa_01`, dans une base qui
possède encore cet ancien nom. Ce renommage conserve l'identité du trade.

La convention concerne les textes et les exemples. Les noms déjà enregistrés
restent utilisables et l'ISIN du titre reste inchangé. La création automatique
des noms de barèmes `B_kc_NN` ou `B_vr_NN` conserve ses règles.

L'archive complète est **`jedi_documentation_20261012_v8.zip`**, en remplacement
de la v7. Elle contient toujours les 70 Markdown, les 228 tableaux et les deux
figures PNG. Les renvois sont vérifiés et les parcours de commandes des
chapitres 07 à 09 sont rejoués en français et en anglais avec les nouveaux noms.

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

Backtest maximum investment now equals the largest individual trade peak, because simulated trades do not overlap. Compact, technical and per-trade totals use it consistently. Financial trade rows follow creation order, and cumulative buy-sell balances remain separate from that maximum. Shared score metrics also use the correction; rerun historical studies to update investment figures, returns and rankings.

`operation fees OPERATION_ID AMOUNT` replaces total fees on any recorded operation, including an earlier operation or one in a closed trade. Zero cancels fees. Orders and investment excluding fees remain identical; net results, lists, exports and historical fees copied into a new play use the correction. Sixteen regression examples were added; 20 targeted and 537 application examples pass, excluding nine launcher examples whose scripts are absent from the source archive. The executable is built and 34 real CLI calls pass in both languages.

Appendix 05 Web-provider tables now use short cells, with detailed descriptions, addresses and regexes below them. Long configuration paths are split by their shared prefix. YAML line continuations preserve every regex and built-in value exactly, also verified through Jedi's configuration reader. French and English Web excerpts are rendered and visually checked on four PDF pages; rebuild the complete manuals using the full repository's PDF scripts.


New scale names are automatically assigned as B_kc_NN or B_vr_NN from the builder’s operational type. Equivalent effective definitions are refused at creation and update, even with force. Explicit names must match the type. Historical names, duplicates and backup references are preserved; simulations reuse equivalent memory scales.

Twenty-two regression examples are added for scale identity and automatic naming.
The application suite now passes 559 examples, excluding the nine launcher
examples whose scripts are absent from the source archive. The executable is
rebuilt; 111 CLI invocations are checked, including expected rejections, with
scale commands exercised in both languages. All 70 Markdown files and 220
tables parse successfully, with no new invalid internal link. Both corrected
Web-provider appendices remain byte-identical to the preceding edition.

Chapters 03 and 07 now cover external and visual selection, with ProRealTime,
TradingView, Boursorama and Zonebourse as examples of market websites. They
explain channels, support and resistance, simple indicators and entry on the
first observable rebound near support. The entry criterion is chosen beforehand;
the actual execution price sets the initial references. Both channel figures and
the two example sessions are entirely fictional. There are now 70 Markdown
files, 228 tables and two PNG figures. Existing CLI examples are preserved, the
scale's price levels are checked through play, and both chapter pairs are
rendered and visually checked in PDF. Rebuild the full manuals from the repository;
the README explains Pandoc's image resource path.

Archive `jedi_documentation_20261012_v7.zip` replaces v6 and adds `kcpc`, `kspc`,
`emax`, `emin` and PRU to both glossaries. Examples explain cumulative
coefficients, jump boundaries and the distinction between the broker's
accounting cost and Jedi's mechanical `c0`. Chapter 16 explicitly states that
cumulative coefficients return to 1 on reinitialisation. All 70 Markdown files,
228 tables and both channel figures are retained; glossary links and rendering
are checked.
The adjacent `kc/ks` and `kb` entries are also clarified: `ks` applies to both
scale types, and `kb` selects the capital-coefficient calculation convention
at level changes.

Archive `jedi_documentation_20261012_v8.zip` replaces v7 and applies the
`T_<ticker>_<number>` convention throughout the French and English examples.
Trade names and numbers are entered by the user. Chapter 09 demonstrates
renaming an old `Exa_01` to `T_exa_01` while retaining trade identity. Existing
stored names remain usable. All 70 Markdown files, 228 tables and both figures
are retained; links and both languages' chapter 07–09 command paths are checked.
