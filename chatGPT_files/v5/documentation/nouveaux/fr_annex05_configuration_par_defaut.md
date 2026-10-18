# Configuration par défaut et usage des paramètres

Cette annexe décrit toutes les entrées de la configuration intégrée à Jedi, dans la constante `App::YAML_CONFIG` de `src/jedi/app/application.cr`. Elle correspond aux sources de cette édition, en préparation de v1.1. Une valeur intégrée sert de point de départ : elle ne décrit pas nécessairement votre configuration effective.

Les tableaux donnent la valeur d’origine et l’usage réellement fait par le code. Les quelques champs présents mais non consultés sont signalés. Le bloc YAML complet en fin d’annexe reproduit toutes les valeurs, y compris les motifs techniques de collecte des cours.

## Lire la configuration effective

~~~console
jedi config --paths
jedi config
~~~

La première commande affiche les chemins, notamment `config_file`. La seconde affiche ces chemins et la configuration effective, après fusion avec le fichier personnel. Dans l’espace d’essai, utiliser les mêmes commandes avec `jedidemo`; son fichier peut être différent. Le [chapitre 02](02_installer_et_preparer_jedi.md) explique ces espaces.

Le fichier personnel utilise le format YAML : l’indentation range les entrées sous leur parent. Jedi fusionne les ensembles de clés imbriqués ; une valeur simple ou une liste fournie remplace entièrement la valeur ou la liste correspondante. Il n’est donc pas nécessaire de recopier toute la configuration.

Pour affecter **50 000 € à la production et à la simulation**, ces seules entrées suffisent dans le fichier de l’espace concerné :

~~~yaml
trading:
  capital: 50000
simulation:
  capital: 50000
~~~

La configuration intégrée fixe les deux capitaux à **20 000**, pas à 50 000. Une valeur de 50 000 affichée par `config` peut donc venir de ce remplacement personnel. Les valeurs s’appliquent à la prochaine invocation de Jedi ; les données et les opérations déjà enregistrées ne sont pas recalculées.

## Affichage, surveillance et contrôles

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `border` | `"ascii"` | Style des bordures des tableaux. `--border=PRESET`, placé avant la famille de commande, le remplace pour cette exécution. |
| `watchrate` | `10.0` | Seuil de proximité dans la liste des ordres, en pourcentage : `10.0` signifie 10 %. Une distance absolue strictement inférieure à ce seuil reçoit le repère de surveillance si aucun repère de disponibilité ne s’applique. Ce réglage modifie l’affichage, pas le risque ni les prix d’ordres. |
| `diagnostic_steps` | `3` | Horizon de contrôle des quantités sur les prochaines hausses. Sert aussi de défaut à `--operability-steps` de `candidate` et du backtest dimensionné par capital. Pour les réserves de `candidate`, l’horizon vaut le plus grand de ce nombre et de `money.n`. |
| `quotlife` | `240.0` | Âge maximal, en minutes, du cours enregistré avant que le résolveur du cours courant tente une actualisation : 240 minutes = 4 heures. Si cette tentative échoue, un ancien cours enregistré peut être réutilisé avec un avertissement. |
| `tickcheck` | `true` | Contrôle du prix enregistré par `operation create` contre le pas de cotation du titre. Un prix préfixé par `+` contourne ce contrôle pour cette opération. `play` et les moteurs de backtest enregistrent leurs opérations simulées sans ce contrôle, mais les ordres restent arrondis au pas de cotation. |

Les styles de `border` sont `ascii`, `reducedascii`, `modern`, `reducedmodern`, `fancy`, `markdown`, `empty` et `blank`. Par exemple :

~~~console
jedidemo --border=modern trade list
~~~

`watchrate` compare le prix proposé à celui du cours enregistré ; il ne déclenche aucune opération. `quotlife` est consulté par le résolveur du cours courant, notamment lors des ordres de trades. Ce n’est pas une tâche d’actualisation périodique : `quote get` interroge les fournisseurs sans utiliser ce délai ni modifier la base. Les ordres de `play` utilisent le prix de la simulation, sans ce renouvellement Web.

## Frais des opérations

Les entrées suivantes sont sous `fees`.

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `rate` | `0.0035` | Taux proportionnel de frais : `0.0035` = 0,35 % du montant de l’opération. Utilisé sans `--fees` explicite, ainsi que pour les nouvelles opérations de `play`, `backtest` et `score`. |
| `min` | `0.0` | Minimum monétaire par opération, dans la même monnaie que les prix. Le calcul retient le plus grand du montant proportionnel et de ce minimum, puis arrondit au centime. |

Avec les valeurs intégrées, une opération de 1 000 € supporte 3,50 € de frais proportionnels. Pour un achat, la taxe éventuelle du titre s’ajoute au taux avant la comparaison avec le minimum. Un montant explicite `operation create --fees=...` remplace le calcul automatique. Les projections de financement de `candidate` sont hors frais. Les frais simulés entrent dans les résultats de `play`, `backtest` et `score`; ils ne changent pas les coefficients du barème.

Une modification de `fees.rate` ou `fees.min` concerne les nouvelles opérations ; elle ne recalcule pas les frais déjà enregistrés. Pour corriger une opération existante, utiliser `operation fees ID MONTANT`, expliqué au [chapitre 08](08_suivre_un_trade.md#corriger-les-frais-dune-opération-enregistrée). Le montant remplace directement le total enregistré ; les paramètres de frais et la taxe ne lui sont pas ajoutés.

## Capital réel et limites de money

Sous `trading` :

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `capital` | `20000` | Capital de référence des protections `money` des trades réels. Sert aussi au dimensionnement et au financement de `candidate` si `--capital` est absent. N’impose pas la quantité du premier achat d’un trade. |

Sous `money` :

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `risk_rate_min` | `0.005` | Borne inférieure admise pour le champ `r` de `money` : 0,5 %. |
| `risk_rate_max` | `0.05` | Borne supérieure admise pour `r` : 5 %. |
| `target_coeff_min` | `0.5` | Borne inférieure admise pour le coefficient d’objectif `o`. |
| `target_coeff_max` | `5.0` | Borne supérieure admise pour `o`. |
| `steps_down_min` | `1` | Borne inférieure admise pour le nombre entier d’échelons baissiers `n`. |
| `steps_down_max` | `5` | Borne supérieure admise pour `n`. |

Ces bornes sont **inclusives**. Ce sont des limites de validation, pas une définition `money` automatiquement attribuée aux trades. Les trois champs `r`, `o` et `n` doivent être fournis, par exemple `money=r:2%,o:2,n:2`. `r` désigne la fraction risquée, `o` multiplie le risque pour définir l’objectif, et `n` fixe le nombre d’échelons de baisse projetés. Les entrées `risk_rate_min` et `risk_rate_max` peuvent aussi être écrites comme chaînes de pourcentage dans le YAML, par exemple `"0.5%"`.

## Paramètres de simulation

Les entrées suivantes sont sous `simulation`. Les taux y sont des fractions numériques : `0.015` signifie 1,5 %, tandis que `watchrate: 10.0` signifie directement 10 %.

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `capital` | `20000` | Capital de référence des protections de `play`. Entre aussi dans le montant initial de référence de `score` et du backtest sans `--capital`. |
| `distance` | `0.2` | Fraction utilisée au dénominateur du montant initial de référence : `0.2` = 20 %. Utilisée par `score` et le backtest sans `--capital`; `--distance` peut la remplacer dans ce dernier. N’intervient pas dans `play`. |
| `risk_rate` | `0.015` | Fraction utilisée au numérateur du montant initial de référence : `0.015` = 1,5 %. Utilisée par `score` et le backtest sans `--capital`. Ne fournit jamais implicitement le champ `r` de `money`, y compris dans `play`. |

Le montant initial de référence est calculé au démarrage :

~~~text
montant initial = capital × risk_rate / distance
valeurs intégrées : 20 000 × 0,015 / 0,2 = 1 500 €
capital personnel de 50 000 : 50 000 × 0,015 / 0,2 = 3 750 €
~~~

Le résultat est tronqué à un montant entier. Garder un capital et une `distance` strictement positifs. Pour les protections, le moteur se replie sur `trading.capital` si le capital de simulation n’est pas positif. **`play` n’utilise pas le montant initial de référence** : son ouverture est celle de `q0` titres au prix `c0`, ou celle de l’opération choisie comme point de départ.

### Quel réglage pour quel outil ?

| Usage | Capital | Taux de risque | Distance ou horizon |
|---|---|---|---|
| Ordres d’un trade réel avec `money` | `trading.capital` | `r` du trade | `n` du trade et son barème. |
| `tools play` avec `money` | `simulation.capital` | `r` fourni dans la simulation | `n` et barème de la simulation. |
| `tools candidate --money=...` | `--capital`, sinon `trading.capital` | `r` de `--money` | Distance obtenue à `n` échelons du barème. |
| `tools backtest` sans `--capital` | `simulation.capital` pour le montant initial | `simulation.risk_rate` pour ce montant ; `money.r` pour les protections si activées | `simulation.distance`, remplacée par `--distance` si fourni, pour le montant ; `money.n` pour les protections. |
| `tools backtest --capital=...` | Capital explicite | `r` de `--money`, qui est requis | Distance obtenue à `n` échelons ; `--distance` est incompatible avec ce mode. |
| `tools score` | `simulation.capital` dans le montant initial | `simulation.risk_rate` dans ce montant | `simulation.distance` dans ce montant ; les simulations de score fonctionnent sans les protections `money`. |

Avec `candidate --amount=...`, le montant est explicitement choisi : il n’est pas dimensionné à partir de `simulation.distance` ou de `simulation.risk_rate`.

### Exemple de play avec un capital personnel de 50 000 €

Après le remplacement de configuration montré plus haut, cette simulation fictive fournit elle-même `r`, `o` et `n` :

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,q0=1000,c0=10,tick=0.01,money=r:2%,o:2,n:2,loss=active" -1
~~~

Le risque vaut **1 000 €** (`50 000 × 2 %`) et le seuil d’objectif **2 000 €** (`1 000 × 2`). La projection porte sur deux échelons du barème. Le premier achat porte bien sur 1 000 titres à 10 €, soit **10 000 € hors frais**, malgré le montant initial de référence de 3 750 €. Dans ce scénario, l’étape baissière exécute une vente de protection à 9 €, soit une perte brute de 1 000 € avant frais. Changer seulement `simulation.distance` ou `simulation.risk_rate` ne change pas ce parcours ; changer `money.r` peut changer la protection.

Le [chapitre 18](18_capital_risque_et_dimensionnement.md) détaille le risque et le dimensionnement ; le [chapitre 19](19_verifier_avec_tools_calc_et_play.md) présente les parcours de `play`.

## Univers et ordre de collecte des cours

Les entrées suivantes sont sous `market_data`.

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `default_universe` | `"france"` | Univers utilisé par défaut pour choisir la base historique de marché, notamment par `market` et les outils lisant un historique en base. `--universe` le remplace lorsqu’il est proposé. Ne sélectionne ni un dataset ni le groupe PEA. |
| `mode_order` | `["live", "eod"]` | Ordre des modes de collecte lorsque la commande ne fixe pas un mode : pages Web `live`, puis API `eod`. Le premier résultat accepté termine la recherche. |
| `api_order` | `["alphavantage"]` | Noms des fournisseurs API à essayer, dans cet ordre, en mode `eod`. Le nom doit correspondre à une définition dans `api_providers`. |
| `website_order` | `["abcbourse", "tradingsat", "boursorama"]` | Noms des fournisseurs Web à essayer, dans cet ordre, en mode `live`. Le nom doit correspondre à une définition dans `websites`. |

L’univers concerne la base historique ; les autres entrées de cette section concernent la collecte d’un **cours courant**. Elles ne remplissent pas un historique OHLCV. `live` désigne une lecture Web, sans garantir un cours en temps réel ; `eod` désigne le parcours API. Lors du calcul des ordres réels, le résolveur demande `live` par défaut : modifier `mode_order` ne force pas ce parcours à utiliser `eod`.

Une liste d’ordre vide fait parcourir toutes les définitions correspondantes ; elle ne désactive pas les fournisseurs. Pour une liste non vide, une définition absente de cette liste n’est pas essayée. L’[annexe 02](fr_annex02_fournisseurs_de_donnees.md) explique la configuration et le diagnostic des fournisseurs.

## Fournisseur API intégré

Les entrées suivantes sont sous `market_data.api_providers.alphavantage`.

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `api_key` | `"yyyyy"` | Valeur envoyée au fournisseur via `{api_key}`. `yyyyy` est une valeur d’attente, à remplacer par sa propre clé pour utiliser cette API. |
| `symbol_candidates.mode` | `"ticker_plus_suffixes"` | Fabrique les symboles API à partir du ticker et des suffixes. Un ticker contenant déjà `.` ou `:` est conservé tel quel. Sans ticker, Jedi utilise l’identifiant disponible, ici l’ISIN. |
| `symbol_candidates.suffixes` | `[".PAR", ".PA", ""]` | Suffixes essayés dans l’ordre. Le dernier, vide, essaie le ticker seul. Aucun suffixe n’est ajouté à un ISIN utilisé faute de ticker. |

Sous `market_data.api_providers.alphavantage.quote` :

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `base_url` | `"https://www.alphavantage.co"` | Adresse de base du fournisseur, à laquelle le chemin est ajouté. |
| `path` | `"/query"` | Chemin de la requête sous cette adresse de base. |
| `query.function` | `"GLOBAL_QUOTE"` | Valeur du paramètre HTTP `function` demandant la réponse `GLOBAL_QUOTE`. |
| `query.symbol` | `"{symbol}"` | Paramètre HTTP remplacé par chaque symbole fabriqué précédemment. |
| `query.apikey` | `"{api_key}"` | Paramètre HTTP remplacé par `api_key`. |
| `symbol_path` | `["Global Quote", "01. symbol"]` | **Non utilisé** par l’extraction actuelle. Sa présence n’entraîne pas de vérification du symbole renvoyé. |
| `price_path` | `["Global Quote", "05. price"]` | Chemin, dans la réponse JSON, vers le prix à lire. |
| `trading_day_path` | `["Global Quote", "07. latest trading day"]` | Chemin vers la date de séance. En mode `eod`, cette date est enregistrée à minuit local. |
| `prev_close_path` | `["Global Quote", "08. previous close"]` | Chemin vers la clôture précédente. Le code la lit même lorsque le pourcentage de variation est fourni directement. |
| `change_path` | `["Global Quote", "09. change"]` | **Non utilisé** par l’extraction actuelle : la variation en montant n’est pas lue à ce chemin. |
| `change_percent_path` | `["Global Quote", "10. change percent"]` | Chemin vers le pourcentage de variation. S’il n’est pas fourni, Jedi calcule la variation à partir du prix et de la clôture précédente. |
| `change_percent_strip_percent` | `true` | Retire le caractère `%` du texte de variation avant sa conversion en nombre. |

Un chemin tel que `["Global Quote", "05. price"]` signifie : ouvrir l’objet `Global Quote`, puis y lire `05. price`. Le lecteur actuel vérifie aussi qu’un objet `Global Quote` non vide existe. Changer seulement ces chemins ne suffit donc pas nécessairement pour utiliser une autre API.

## Fournisseurs Web intégrés

Chaque site possède sa propre adresse, ses modèles d’identifiants et ses motifs de capture. Les tableaux indiquent les entrées et leur usage ; les adresses et les regex sont placées sous chaque tableau, sur toute la largeur de la page. Dans les chaînes YAML entre guillemets, l’antislash final permet de poursuivre la même chaîne à la ligne suivante sans ajouter de caractère. Les valeurs sont identiques à celles du code. Leur présence ne garantit pas que le site répondra ou que son HTML restera compatible.

### ABC Bourse

Sous `market_data.websites.abcbourse` :

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `url` | Adresse ci-dessous | Page du titre. |
| `regex_price` | Motifs ci-dessous | Extraction du prix. |
| `regex_variation` | Motifs ci-dessous | Extraction de la variation. |

Dans l’adresse, `{key}` est remplacé par chaque identifiant candidat. Les regex recherchent les nombres dans le HTML : le groupe nommé `price` fournit le prix ; `variation` fournit la variation en pourcentage.

~~~yaml
url: "https://www.abcbourse.com/cotation/{key}"
regex_price: "id=\"lastcx\">(?<price>\\d+(?:[.,]\\d+)*)\\s*&#x20AC;"
regex_variation: "id=\"varcx\"\\s+class=\"quote_(up|down)b\">(?<variati\
  on>(&#x2B;|&#x2D;|\\+|-)?\\d+(?:[.,]\\d+)*)%"
~~~

Sous `key_strategy.candidates` :

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `[0].template` | `"{ticker}p"` | Ticker suivi de `p`. |
| `[1].template` | `"{isin}"` | ISIN seul. |

Les modèles sont essayés dans cet ordre. Le premier est écarté si le ticker est indisponible.

### Tradingsat

Sous `market_data.websites.tradingsat` :

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `url` | Adresse ci-dessous | Page du titre. |
| `regex_price` | Motifs ci-dessous | Extraction du prix. |
| `regex_variation` | Motifs ci-dessous | Extraction de la variation. |

Dans l’adresse, `{key}` est remplacé par chaque identifiant candidat. Les regex recherchent les nombres dans le HTML : le groupe nommé `price` fournit le prix ; `variation` fournit la variation en pourcentage.

~~~yaml
url: "https://www.tradingsat.com/{key}"
regex_price: "class=\"price\">(?<price>\\d+(?:[,.]\\d+)*)\\s*€"
regex_variation: "class=\"variation var-(down|neutral|up)\">(?<variatio\
  n>[+-]?\\d+(?:[,.]\\d+)*)\\s*%"
~~~

Sous `key_strategy.candidates` :

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `[0].template` | `"{name_slug}-{isin}"` | Nom transformé et ISIN. |

Ce modèle est écarté si le nom nécessaire est indisponible. `name_slug` est construit par les transformations ci-dessous.

Sous `key_strategy.candidates[0].vars.name_slug` :

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `from` | `"name"` | Nom du titre. |
| `ops[0]` | `"downcase"` | Passage en minuscules. |
| `ops[1].gsub.pattern` | `"\\."` | Recherche des points. |
| `ops[1].gsub.replace` | `""` | Supprime les points. |
| `ops[2].gsub.pattern` | `" "` | Recherche des espaces. |
| `ops[2].gsub.replace` | `"-"` | Remplace les espaces par des tirets. |

### Boursorama

Sous `market_data.websites.boursorama` :

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `url` | Adresse ci-dessous | Page du titre. |
| `regex_price` | Motifs ci-dessous | Extraction du prix. |
| `regex_variation` | Motifs ci-dessous | Extraction de la variation. |

Dans l’adresse, `{key}` est remplacé par chaque identifiant candidat. Les regex recherchent les nombres dans le HTML : le groupe nommé `price` fournit le prix ; `variation` fournit la variation en pourcentage.

~~~yaml
url: "https://www.boursorama.com/cours/{key}/"
regex_price: "c-faceplate__info.+?price.+?ist-last>(?<price>\\d+(?:[,.]\
  \\d+)*)<"
regex_variation: "c-faceplate__info.+?fluctuation.+?ist-variation>(?<va\
  riation>[+-]?\\d+(?:[.,]\\d+)*)%"
~~~

Sous `key_strategy.candidates` :

| Entrée | Valeur intégrée | Usage effectif |
|---|---|---|
| `[0].template` | `"1rP{ticker}"` | Préfixe `1rP` et ticker. |
| `[1].template` | `"1rEP{ticker}"` | Préfixe `1rEP` et ticker. |
| `[2].template` | `"{ticker}"` | Ticker seul. |
| `[2].ops.ticker` | `["upcase", "trim"]` | **Non appliqué.** |

Les trois modèles sont essayés dans cet ordre et écartés si le ticker est indisponible. **Les transformations `upcase` et `trim` sous `[2].ops.ticker` ne sont pas utilisées à cet emplacement** par le constructeur actuel. Les opérations prises en charge se trouvent sous `vars.<variable>.ops`.

## Configuration intégrée complète

Ce bloc reproduit les valeurs intégrées sous une présentation YAML directement lisible. Les commentaires du code ne sont pas des entrées de configuration. Il sert de référence ; un fichier personnel peut se limiter aux seuls remplacements souhaités.

~~~yaml

border: ascii
market_data:
  default_universe: france
  mode_order:
  - live
  - eod
  api_order:
  - alphavantage
  website_order:
  - abcbourse
  - tradingsat
  - boursorama
  api_providers:
    alphavantage:
      api_key: yyyyy
      symbol_candidates:
        mode: ticker_plus_suffixes
        suffixes:
        - .PAR
        - .PA
        - ""
      quote:
        base_url: https://www.alphavantage.co
        path: /query
        query:
          function: GLOBAL_QUOTE
          symbol: '{symbol}'
          apikey: '{api_key}'
        symbol_path:
        - Global Quote
        - 01. symbol
        price_path:
        - Global Quote
        - 05. price
        trading_day_path:
        - Global Quote
        - 07. latest trading day
        prev_close_path:
        - Global Quote
        - 08. previous close
        change_path:
        - Global Quote
        - 09. change
        change_percent_path:
        - Global Quote
        - 10. change percent
        change_percent_strip_percent: true
  websites:
    abcbourse:
      url: https://www.abcbourse.com/cotation/{key}
      key_strategy:
        candidates:
        - template: '{ticker}p'
        - template: '{isin}'
      regex_price: "id=\"lastcx\">(?<price>\\d+(?:[.,]\\d+)*)\\s*&#x20A\
        C;"
      regex_variation: "id=\"varcx\"\\s+class=\"quote_(up|down)b\">(?<v\
        ariation>(&#x2B;|&#x2D;|\\+|-)?\\d+(?:[.,]\\d+)*)%"
    tradingsat:
      url: https://www.tradingsat.com/{key}
      key_strategy:
        candidates:
        - template: '{name_slug}-{isin}'
          vars:
            name_slug:
              from: name
              ops:
              - downcase
              - gsub:
                  pattern: \.
                  replace: ""
              - gsub:
                  pattern: ' '
                  replace: '-'
      regex_price: "class=\"price\">(?<price>\\d+(?:[,.]\\d+)*)\\s*€"
      regex_variation: "class=\"variation var-(down|neutral|up)\">(?<va\
        riation>[+-]?\\d+(?:[,.]\\d+)*)\\s*%"
    boursorama:
      url: https://www.boursorama.com/cours/{key}/
      key_strategy:
        candidates:
        - template: 1rP{ticker}
        - template: 1rEP{ticker}
        - template: '{ticker}'
          ops:
            ticker:
            - upcase
            - trim
      regex_price: "c-faceplate__info.+?price.+?ist-last>(?<price>\\d+(\
        ?:[,.]\\d+)*)<"
      regex_variation: "c-faceplate__info.+?fluctuation.+?ist-variation\
        >(?<variation>[+-]?\\d+(?:[.,]\\d+)*)%"
fees:
  rate: 0.0035
  min: 0.0
watchrate: 10.0
diagnostic_steps: 3
quotlife: 240.0
tickcheck: true
trading:
  capital: 20000
money:
  risk_rate_min: 0.005
  risk_rate_max: 0.05
  target_coeff_min: 0.5
  target_coeff_max: 5.0
  steps_down_min: 1
  steps_down_max: 5
simulation:
  capital: 20000
  distance: 0.2
  risk_rate: 0.015
~~~
