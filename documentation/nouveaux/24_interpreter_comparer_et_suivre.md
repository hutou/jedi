# Interpréter, comparer et suivre les résultats

## Expliquer les euros avant de classer

Un résultat se lit avec ses dates, son barème, son premier achat et ses conventions. Les mesures compactes répondent à des questions différentes :

| Mesure | Question |
|---|---|
| Gain brut | Quel est le solde ventes − achats + valeur finale des titres ? |
| Frais | Quel coût de courtage a été imputé aux opérations ? |
| Gain net | Que reste-t-il après ces frais ? |
| Investissement maximal | Quel pic des achats moins les ventes le parcours a-t-il demandé, hors frais ? |
| Gain net / investissement maximal | Quel résultat net représente ce pic de financement ? |
| Activité | Combien d'opérations et d'interventions le parcours entraîne-t-il ? |
| Stock final | Quelle part du résultat dépend encore de titres détenus ? |

Les ventes ne sont pas toutes du bénéfice, et un titre encore détenu n'est pas une somme encaissée. Le rapport valorise le stock restant à la dernière clôture ; il n'ajoute pas une vente finale fictive.

La fitness de `score` divise le gain **brut** par le premier achat. Le rendement compact de `backtest` divise le gain **net** par l'investissement maximal. Comparer les deux pourcentages sans rapprocher leurs numérateurs, leurs dénominateurs et leurs périodes donne une lecture trompeuse. L'[annexe 04](fr_annex04_glossaire_et_notations.md) rassemble ces définitions.

## Comparer sur une base commune

Garder identiques les titres, les cotations, les dates, les frais, le dimensionnement et les règles d'exécution. Fixer les barèmes avant d'observer la période de comparaison. Relever pour chacun le net, les frais, le pic d'investissement, les opérations et le stock final.

Une simulation plus active peut gagner davantage brut et moins net. Une autre peut sembler peu consommatrice de capital parce que des ventes ont réduit l'investissement ; elle peut encore porter un stock important. Un gain élevé sur une hausse continue ne démontre pas à lui seul l'intérêt des allers-retours.

Une comparaison simple à deux barèmes suffit souvent. Les options `--sort=activity` et `--sort=investment` de `score` aident à explorer les compromis ; en recherche adaptative, elles changent aussi le raffinement. Pour comparer les mêmes barèmes, reprendre leurs définitions dans `backtest`.

## Lire les limites du parcours

Les données journalières ne donnent pas la chronologie de chaque mouvement. Un seul ordre proposé est retenu par séance. Les gaps, le coût réel d'exécution, les exécutions partielles, les interruptions de cotation et les opérations sur titres peuvent produire un parcours réel différent.

Le [chapitre 22](22_simuler_avec_tools_backtest.md) montre comment un gap dépasse un risque nominal. Un StopLoss déclenche une action selon les possibilités du marché ; il ne garantit pas un prix ni un plafond de perte. Le résultat de plusieurs backtests individuels ne remplace pas une vérification du financement commun des trades.

L'annualisation disponible dans certains affichages experts transforme un ratio selon une durée. Elle n'ajoute pas d'observations et n'atteste pas qu'un rendement soit reproductible. Pour une courte période, les euros, les opérations et le stock final restent les premières informations à lire.

## Vérifier sur d'autres dates

Conserver le barème choisi et examiner une autre période, notamment une phase différente. Indiquer si chaque test repart d'un nouvel achat ou si l'on suit un trade réel déjà engagé. Des dates de départ différentes donnent des prix de référence et des quantités entières différents.

Pour une nouvelle période, préparer sa borne finale selon le chapitre 21 et conserver le choix avant de lire son résultat. Si l'on ajuste ensuite le barème, garder le premier rapport et créer une nouvelle ligne d'étude. Le nombre d'essais compte dans l'interprétation : chercher longtemps une configuration favorable rend le meilleur résultat moins surprenant.

## Tenir un journal daté

Le journal conserve ce qui a été décidé, pourquoi, avec quelles données, puis ce qui a été observé. `note` convient aux choix d'étude et aux événements exceptionnels d'un trade : gap, suspension, incident de courtier, exécution partielle, changement de paramétrage ou opération sur titres.

L'éditeur facilite une note complète :

~~~console
jedidemo note create --edit
~~~

Ou saisir un texte multiligne :

~~~console
jedidemo note create 2026-10-07 "Étude Growth 2025 : protocole" "Étude rétrospective sur données fictives.
Choix calculé jusqu'au 2024-12-31 ; vérification sur 2025.
Barème fixé : kc:1.5,1.38,1.23,1.14,0.52,0.4,ki:0%,kb:1,kd:0.2.
Net 2025 : -20.21 EUR ; investissement maximal : 1498.56 EUR."
~~~

La date est celle de la rédaction de cette note ; elle ne prétend pas qu'une décision ait été prise en 2024. Pour votre propre journal, utiliser la date réelle. Ne pas mélanger les champs positionnels avec `--date`, `--summary` ou `--contents`.

Une note décrit l'événement ; elle ne modifie ni les opérations ni les ordres. Enregistrer séparément chaque exécution réelle avec `operation`, puis vérifier l'état du trade. Conserver les fichiers d'étude hors de la note et y indiquer leur emplacement.

## Fiche de reproduction

| Champ | À conserver |
|---|---|
| Question et date | Objectif, date réelle du choix, caractère prospectif ou rétrospectif |
| Logiciel | Sortie de `version`, langue et configuration utile |
| Données | Fournisseur, récupération, fichiers, conversions, ajustements, droits d'usage |
| Population | Liste datée des titres, exclusions et raisons |
| Périodes | Borne de choix, fenêtre de recherche, début et fin de vérification |
| Paramètres | Définition exacte du barème, montant ou capital et `money`, frais |
| Exécution | `conservative` ou `legacy`, `next` ou `same` |
| Commandes | Commandes complètes et rapports conservés |
| Résultats | Brut, frais, net, investissement maximal, opérations et stock final |
| Suites | Décision pratique, changements ultérieurs et événements exceptionnels |

Cette fiche permet de relire une étude, d'expliquer une différence entre deux rapports et de distinguer le choix initial des modifications suivantes. Pour un projet réel, revenir à `candidate` avec le prix actuel, puis au suivi des opérations exécutées décrit dans la partie I.
