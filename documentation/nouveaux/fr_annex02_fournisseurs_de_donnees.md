# Configuration des fournisseurs de cours API et Web

Cette annexe complète le [chapitre 08](08_suivre_un_trade.md). Elle s'adresse à la personne qui doit **créer ou modifier** un fournisseur de cours courant. Cette tâche demande de savoir lire une documentation d'API ou une page HTML, écrire une expression régulière, examiner une réponse HTTP et vérifier les conditions d'accès de la source. Un fournisseur configuré n'est pas nécessairement disponible ou autorisé. Les exemples de cette annexe emploient des adresses et réponses **fictives** ; ils servent à comprendre la forme de la configuration, pas à obtenir un cours réel.

## Fournisseurs intégrés et séparation des bases

La configuration d'origine essaie les pages Web ABC Bourse, Tradingsat et Boursorama, puis l'API Alpha Vantage. Ce sont des définitions de collecte, dont la disponibilité dépend du fournisseur et de la structure actuelle de sa réponse. Le nom `live` indique une collecte Web, sans promettre un cours en temps réel ou sans délai. `eod` indique le parcours API ; vérifier la séance effectivement renvoyée.

Ces appels traitent le cours courant de la base principale. Ils ne remplissent pas un historique OHLCV et ne remplacent pas `market import` ou `market update`, qui lisent des fichiers préparés. Le délai de renouvellement `quotlife` vaut 240 minutes dans la configuration d'origine ; `quote refresh --force` permet une actualisation forcée selon sa sélection.

Les exemples emploient `jedidemo` pour travailler dans l'espace d'essai. Les mêmes sous-commandes avec `jedi` s'appliquent au portefeuille de production.

## Repérer le fichier et comprendre l'ordre des essais

`jedidemo config --paths` affiche le chemin du fichier de configuration effectivement utilisé (`config_file`) et celui du journal (`log_file`). Dans l'installation courante, le fichier est nommé `jedi.conf` ; les environnements de développement et de test emploient d'autres noms. Sa syntaxe est **YAML**, format qui utilise l'indentation pour ranger les clés sous leur parent. Jedi part d'une configuration intégrée, puis fusionne celle du fichier personnel : les objets de clés sont fusionnés, tandis qu'une valeur simple ou une liste fournie par l'utilisateur remplace la valeur intégrée correspondante. Écrire un petit remplacement est donc possible, mais une nouvelle liste `website_order` remplace toute l'ancienne liste.

```console
jedidemo config --paths
```

Les cours courants se trouvent sous `market_data` dans le YAML. Le nom `market_data` ici désigne la configuration des fournisseurs ; il ne transforme pas `quote get` en lecture de la base historique `market`. La configuration intégrée essaie `live` puis `eod`. `live` lit des pages Web ; `eod` consulte une API pour un cours de fin de séance. Dans chaque mode, Jedi parcourt les noms de fournisseurs dans l'ordre configuré, puis les identifiants possibles pour ce fournisseur. Le premier résultat accepté arrête les essais.

| Clé YAML | Rôle dans Jedi 1.0 |
|---|---|
| `market_data.mode_order` | Chaîne ou liste des modes `live` et `eod` ; si absente ou vide, repli sur `live`. |
| `market_data.website_order` | Liste des noms à essayer dans `websites` ; si absente ou vide, parcours des entrées de `websites`. |
| `market_data.api_order` | Liste des noms à essayer dans `api_providers` ; si absente ou vide, parcours des entrées de `api_providers`. |
| `market_data.websites` | Définition des fournisseurs de pages Web. |
| `market_data.api_providers` | Définition des fournisseurs API. |

Un nom inscrit dans un ordre sans définition correspondante est ignoré par le parcours. Pour ne tenter qu'un fournisseur précis, renseigner l'ordre correspondant ; une définition conservée dans `websites` ou `api_providers` ne suffit pas à l'activer si elle est absente d'une liste d'ordre non vide. La présence de fournisseurs Web intégrés, dont ABC Bourse et Boursorama, ne constitue pas une autorisation de collecte : vérifier les conditions d'accès du fournisseur avant utilisation.

## Configuration d'un fournisseur Web

L'exemple ci-dessous décrit une **page fictive** qui afficherait dans son HTML `data-price="12,34"` et `data-change="&#x2D;0,50"`. L'adresse `.invalid` ne désigne aucun service utilisable. Remplacer l'ensemble par les détails d'une source dont l'accès est permis et dont la page a été vérifiée.

```yaml
market_data:
  mode_order: ["live"]
  website_order: ["demo_web"]
  websites:
    demo_web:
      url: "https://cours.example.invalid/security/{key}"
      key_strategy:
        candidates:
          - template: "{isin}"
      regex_price: 'data-price="(?<price>\d+(?:[.,]\d+)?)"'
      regex_variation: 'data-change="(?<variation>(?:&#x2B;|&#x2D;|[+-])?\d+(?:[.,]\d+)?)"'
```

Cette configuration peut être lue par Jedi si elle figure sous `market_data` dans le fichier de configuration. Elle ne garantit ni que le HTML réel correspond, ni que le nombre est un cours correct. Le groupe nommé `price` est obligatoire pour `regex_price`. Si `regex_variation` est présente, son groupe nommé `variation` doit pouvoir être extrait ; sinon la tentative auprès de ce fournisseur échoue et Jedi poursuit le repli. Si elle est **absente, nulle ou une liste vide**, Jedi rend `0.0` pour la variation, valeur qui signifie dans ce cas « non extraite » et non « variation effectivement nulle ». `regex_price` ne peut être absente, nulle ni vide.

| Clé sous `websites.<nom>` | Sens et forme |
|---|---|
| `url` | Adresse HTTP(S) comportant normalement `{key}` ; Jedi encode la clé construite dans ce segment de chemin. |
| `key_strategy.candidates` | Liste ordonnée de `template` ; les champs utilisables sont `{isin}`, `{ticker}`, `{name}` et les variables dérivées déclarées par `vars`. |
| `key_exceptions` | Dictionnaire facultatif `ISIN: clé` ; pour un ISIN présent, sa clé unique remplace les candidats ordinaires. |
| `regex_price` | Motif requis contenant `(?<price>...)`. |
| `regex_variation` | Motif facultatif contenant `(?<variation>...)` lorsqu'il est configuré. |
| `http_error_patterns` | Motifs facultatifs pour reconnaître une page d'erreur parmi ses premières lignes ; `null` désactive ce contrôle, une liste remplace les motifs intégrés. |
| `min_body_chars`, `min_body_lines` | Longueur minimale du corps en caractères ou lignes ; par défaut, 100 caractères et aucune limite de lignes. Les anciens noms `min_response_chars` et `min_response_lines` sont aussi lus. |

Pour chaque candidat, Jedi remplace les variables connues dans le modèle. S'il reste un champ non résolu, ce candidat est omis. `quote get <isin>` fournit seulement l'ISIN ; les modèles exigeant ticker ou nom ne fonctionnent que si ces champs existent dans le titre enregistré, par exemple avec `quote update`. Les clés identiques sont dédupliquées. Si aucun candidat n'est disponible, la page n'est pas demandée.

Pour fabriquer une variable dérivée, la forme réellement lue par le code est :

```yaml
key_strategy:
  candidates:
    - template: "{slug}-{isin}"
      vars:
        slug:
          from: "name"
          ops:
            - downcase
            - {gsub: {pattern: "\\.", replace: ""}}
            - {gsub: {pattern: " ", replace: "-"}}
```

`from` choisit `isin`, `ticker` ou `name`. Les opérations possibles dans `vars.<variable>.ops` sont `trim`, `upcase`, `downcase` et `gsub`, qui remplace les correspondances d'une expression régulière. Dans ce bloc, `"\\."` est la façon YAML d'écrire le motif regex `\.`. **Le champ `ops` placé directement sur un candidat n'est pas appliqué par `ScrapingKeyBuilder` dans Jedi 1.0** : placer les opérations dans `vars`, comme ci-dessus. La configuration intégrée présente un tel champ sur un candidat Boursorama, mais il ne faut pas compter sur cet effet pour écrire un nouveau fournisseur.

### Les formes de regex acceptées

`regex_price` et `regex_variation` acceptent soit une chaîne, soit une liste. Dans la liste, une chaîne est un motif à essayer ; une sous-liste de chaînes est **concaténée en un seul motif**, puis essayée. Les alternatives sont tentées dans l'ordre jusqu'à ce qu'une extraction numérique réussisse :

```yaml
regex_price:
  - 'data-price="(?<price>\d+(?:[.,]\d+)?)"'
  - ['class="last">', '(?<price>\d+(?:[.,]\d+)?)', '<']
```

Les trois fragments du second élément sont joints sans espace ni saut de ligne. Des apostrophes YAML autour de la regex préservent les antislashs. La capture doit représenter un nombre que Crystal peut convertir en décimal : Jedi retire `&nbsp;`, les espaces extérieurs et remplace la virgule par un point, `&#x2B;` par `+` et `&#x2D;` par `-`. Il ne retire pas automatiquement tous les espaces entre chiffres, les symboles monétaires ni les autres entités HTML. Vérifier la capture, son titre et sa date, plutôt que le seul fait qu'une regex trouve un nombre.

## Configuration d'un fournisseur API

L'API intégrée illustre le format `GLOBAL_QUOTE` d'Alpha Vantage. La configuration ci-dessous reprend **la forme des clés** avec une adresse et un nom de fournisseur fictifs. Elle décrit un service compatible avec cette structure de réponse précise ; elle ne constitue pas un adaptateur universel pour toute API JSON.

```yaml
market_data:
  mode_order: ["eod"]
  api_order: ["demo_api"]
  api_providers:
    demo_api:
      api_key: "REMPLACER_PAR_UNE_CLE_PERSONNELLE"
      symbol_candidates:
        mode: "ticker_plus_suffixes"
        suffixes: [".PA", ""]
      quote:
        base_url: "https://api.example.invalid"
        path: "/query"
        query:
          function: "GLOBAL_QUOTE"
          symbol: "{symbol}"
          apikey: "{api_key}"
        price_path: ["Global Quote", "05. price"]
        prev_close_path: ["Global Quote", "08. previous close"]
        trading_day_path: ["Global Quote", "07. latest trading day"]
        change_percent_path: ["Global Quote", "10. change percent"]
        change_percent_strip_percent: true
```

Ne placer une vraie clé que dans une configuration personnelle protégée ; éviter de partager ce fichier, l'URL complète et les journaux bruts. Dans Jedi 1.0, le contexte de diagnostic peut contenir la clé lorsqu'elle figure dans l'URL. La clé `"yyyyy"` livrée pour Alpha Vantage est seulement un espace réservé.

| Clé sous `api_providers.<nom>` | Rôle effectivement utilisé |
|---|---|
| `api_key` | Chaîne substituée dans la requête via `{api_key}`. |
| `symbol_candidates.mode`, `suffixes` | Avec `ticker_plus_suffixes`, ajoute chaque suffixe au ticker, dans l'ordre ; un ticker contenant déjà `.` ou `:` est gardé tel quel. Sans ticker, Jedi essaie l'ISIN sans suffixe. |
| `quote.base_url`, `quote.path`, `quote.query` | Construisent l'URL et ses paramètres ; valeurs de paramètres sous forme de chaînes, avec substitutions `{symbol}`, `{api_key}` ou `{q}` (`{q}` représente l'ISIN disponible). |
| `quote.price_path`, `quote.prev_close_path` | Chemins de clés JSON nécessaires pour lire le prix et la clôture précédente ; un élément numérique peut désigner un indice dans un tableau. |
| `quote.trading_day_path` | Chemin facultatif de date `AAAA-MM-JJ` en mode `eod` ; sinon Jedi utilise la date locale du jour. |
| `quote.change_percent_path`, `quote.change_percent_strip_percent` | Pourcentage renvoyé par l'API ; si le chemin est absent, calcul à partir du prix et de la clôture précédente. `true` retire le signe `%` du texte. |

Dans l'adaptateur actuel, Jedi vérifie aussi les réponses contenant `Note` ou `Information` comme signes de limitation, et attend un objet `Global Quote` non vide. Même si des chemins JSON sont paramétrables, une autre API avec un objet racine différent peut donc nécessiter **une modification du code**. Les champs `symbol_path` et `change_path` existent dans la configuration intégrée, mais ne sont pas consultés dans la méthode actuelle d'extraction : ne leur attribuer aucun effet dans un nouveau paramétrage. `prev_close_path` reste requis par le code même si `change_percent_path` fournit déjà la variation.

## Diagnostiquer sans inventer de cours

Commencer par vérifier le chemin et la syntaxe du fichier. Pour un titre dont l'ISIN est connu, une interrogation ne modifiant aucune base permet de constater si un fournisseur répond :

```console
jedidemo config --paths
jedidemo quote get FR0000120271
```

Cette commande d'exemple est documentée dans l'aide ; **elle ne préjuge ni d'une réponse effective ni du droit d'interroger la source configurée**. `quote get` n'a pas d'option `--mode` et ne lit pas le cours enregistré. Pour cibler un mode sur un titre déjà enregistré, `quote update <id-ou-isin> --mode=eod` est possible, mais **enregistre** le résultat si l'appel réussit ; choisir un titre et une procédure de test adaptés avant de l'utiliser. `quote refresh --mode=eod` peut mettre à jour plusieurs titres et ne sert pas de premier essai de diagnostic. `quote set` permet de saisir un cours vérifié sans requête externe.

| Symptôme ou étape | Vérification concrète |
|---|---|
| Configuration non prise en compte | Chemin `config_file`, indentation YAML, liste d'ordre qui contient le nom exact du fournisseur ; les listes remplacent les listes intégrées. |
| Aucun identifiant Web | ISIN présent, champs ticker/nom nécessaires au modèle, `vars` et transformations, exception par ISIN. |
| HTTP `429`, autre erreur, ou corps très court | Quota, URL, redirection, accès permis, page de consentement ; le statut `200` ne garantit pas la présence d'un cours. |
| Motif absent ou capture non numérique | HTML exact reçu, groupe nommé `price`/`variation`, format décimal et entités HTML ; contrôler que le prix correspond au bon titre. |
| API vide, limitée ou JSON inattendu | Symbole essayé, suffixes, clé et quota, structure `Global Quote` et chemins JSON. |
| Variation `0.0` | Vérifier si `regex_variation` était omise : ce zéro peut signifier « non extraite ». |

Jedi essaie successivement motifs, clés, fournisseurs et modes selon leur configuration ; le contexte du dernier échec ne raconte pas nécessairement **tous** les essais antérieurs. Le journal peut contenir un extrait de la réponse, l'URL, une erreur de parsing et éventuellement une clé API : le consulter localement et masquer ces éléments avant tout partage. Une erreur de configuration, une réponse réseau et une extraction du mauvais chiffre sont des problèmes distincts. Tester le prix et sa date contre une source autorisée indépendante avant de l'enregistrer ou de l'utiliser dans un trade. Conserver la provenance et les conditions d'utilisation des données, selon le [chapitre 21](21_preparer_une_etude_historique.md).
