# Configuring API and Web quote providers

This appendix supplements [chapter 08](en_08_monitoring_a_trade.md). It is for someone who needs to **create or change** a current-quote provider. This work requires the ability to read API documentation or HTML, write a regular expression, inspect an HTTP response and check the source's access conditions. A configured provider is not necessarily available or authorized. Addresses and responses in the examples below are **invented**: they explain configuration structure and do not fetch a real quote.

[Appendix 05](en_annex05_default_configuration.md) lists every built-in value, including fields that are currently unused.

## Built-in providers and separate databases

Default configuration tries ABC Bourse, Tradingsat and Boursorama Web pages, then the Alpha Vantage API. These are collection definitions whose availability depends on the provider and its current response structure. `live` identifies Web collection without promising real-time or undelayed prices. `eod` identifies the API path; check the session actually returned.

These calls handle the main database's current quotation. They do not populate OHLCV history or replace `market import` and `market update`, which read prepared files. The `quotlife` refresh interval defaults to 240 minutes; `quote refresh --force` forces updates according to its selection.

Examples use `jedidemo` in the experiment environment. The same subcommands with `jedi` apply to the production portfolio.

## Locate the file and understand the order of attempts

`jedidemo config --paths` displays the actual configuration file path (`config_file`) and log path (`log_file`). In normal operation the file is named `jedi.conf`; development and test environments use other names. It uses **YAML**, whose indentation places keys under a parent. Jedi starts with built-in settings and merges the personal file into them: nested mappings are merged, while an overriding scalar or list replaces its built-in counterpart. A small override is possible, but supplying `website_order` replaces the entire built-in list.

```console
jedidemo config --paths
```

Current-quote providers are configured under `market_data`. That YAML name does not make `quote get` read Jedi's historical market database. The built-in order attempts `live` and then `eod`. `live` reads Web pages; `eod` queries an end-of-day API. Within each mode, Jedi tries provider names in configured order and then candidate identifiers for that provider. The first accepted quote ends the search.

| YAML key | Role in Jedi 1.0 |
|---|---|
| `market_data.mode_order` | String or list of `live` and `eod`; missing or empty falls back to `live`. |
| `market_data.website_order` | Names to try from `websites`; missing or empty traverses the entries in `websites`. |
| `market_data.api_order` | Names to try from `api_providers`; missing or empty traverses their entries. |
| `market_data.websites` | Web page provider definitions. |
| `market_data.api_providers` | API provider definitions. |

An ordered name without a matching definition is skipped. To try only a chosen provider, set its corresponding order; leaving a definition in `websites` or `api_providers` does not activate it when a nonempty order omits its name. Built-in Web definitions, including ABC Bourse and Boursorama, do not establish permission to collect data: check the provider's access conditions before use.

## Configure a Web provider

This example describes an **invented page** whose HTML would contain `data-price="12,34"` and `data-change="&#x2D;0,50"`. The `.invalid` address identifies no usable service. Replace it with details of a source whose access is permitted and whose response has been checked.

```yaml
market_data:
  mode_order: ["live"]
  website_order: ["demo_web"]
  websites:
    demo_web:
      url: "https://quotes.example.invalid/security/{key}"
      key_strategy:
        candidates:
          - template: "{isin}"
      regex_price: 'data-price="(?<price>\d+(?:[.,]\d+)?)"'
      regex_variation: 'data-change="(?<variation>(?:&#x2B;|&#x2D;|[+-])?\d+(?:[.,]\d+)?)"'
```

Jedi can read this configuration when placed under `market_data` in the configuration file. It does not guarantee that real HTML matches or that the number is the correct quote. The named `price` capture is mandatory in `regex_price`. If `regex_variation` is configured, its named `variation` capture must produce a number; otherwise this provider attempt fails and Jedi tries its configured fallback. If variation is **missing, null or an empty list**, Jedi returns `0.0` for variation. That means “not extracted” here, rather than “the price did not change.” `regex_price` cannot be missing, null or empty.

| Key under `websites.<name>` | Meaning and shape |
|---|---|
| `url` | HTTP(S) address normally containing `{key}`; Jedi encodes the generated key in that path segment. |
| `key_strategy.candidates` | Ordered `template` list using `{isin}`, `{ticker}`, `{name}` or derived variables declared in `vars`. |
| `key_exceptions` | Optional `ISIN: key` mapping; one matching key replaces ordinary candidates for that ISIN. |
| `regex_price` | Required pattern containing `(?<price>...)`. |
| `regex_variation` | Optional pattern containing `(?<variation>...)` when provided. |
| `http_error_patterns` | Optional patterns recognizing an error page near its start; `null` disables this check, and a list replaces built-in patterns. |
| `min_body_chars`, `min_body_lines` | Minimum body length in characters or lines; defaults are 100 characters and no line minimum. Earlier `min_response_chars` and `min_response_lines` names are also read. |

For each candidate Jedi expands known variables in its template. If an unresolved field remains, the candidate is omitted. `quote get <isin>` supplies only the ISIN; templates requiring ticker or name work only where those fields are available from a registered security, for example with `quote update`. Duplicate keys are removed. If no candidate can be formed, Jedi makes no page request.

For a derived variable, the code reads this form:

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

`from` chooses `isin`, `ticker` or `name`. Supported operations inside `vars.<variable>.ops` are `trim`, `upcase`, `downcase` and `gsub`, a regular-expression replacement. Here `"\\."` is YAML's way to write regex `\.`. **An `ops` field directly on a candidate is not applied by `ScrapingKeyBuilder` in Jedi 1.0**: put operations in `vars` as above. A built-in Boursorama candidate has such a field, but a new provider should not rely on that effect.

### Accepted regex shapes

Both `regex_price` and `regex_variation` accept a string or a list. A string in the list is an alternative pattern; a nested list of strings is **joined into one pattern**, then tried. Alternatives are attempted in order until numeric extraction succeeds:

```yaml
regex_price:
  - 'data-price="(?<price>\d+(?:[.,]\d+)?)"'
  - ['class="last">', '(?<price>\d+(?:[.,]\d+)?)', '<']
```

The second entry's three fragments are joined without spaces or newlines. YAML single quotes preserve regex backslashes. The capture must represent a number Crystal can parse: Jedi replaces `&nbsp;`, trims surrounding whitespace, and converts decimal commas to periods, `&#x2B;` to `+`, and `&#x2D;` to `-`. It does not automatically strip all spaces inside numbers, currency signs or every HTML entity. Verify the captured value, security and date, rather than merely checking that a regex matches some number.

## Configure an API provider

The built-in API illustrates Alpha Vantage's `GLOBAL_QUOTE` response shape. The following example retains **the structure of its keys** but uses an invented address and provider name. It describes a service compatible with this particular response structure; it is not a universal adapter for all JSON APIs.

```yaml
market_data:
  mode_order: ["eod"]
  api_order: ["demo_api"]
  api_providers:
    demo_api:
      api_key: "REPLACE_WITH_YOUR_OWN_KEY"
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

Place a real key only in a protected personal configuration; do not share this file, full URLs or unredacted logs. In Jedi 1.0 diagnostic context may contain the key when it is part of the URL. The built-in Alpha Vantage key `"yyyyy"` is merely a placeholder.

| Key under `api_providers.<name>` | Actual use |
|---|---|
| `api_key` | String substituted into the request through `{api_key}`. |
| `symbol_candidates.mode`, `suffixes` | `ticker_plus_suffixes` appends each suffix to a ticker, in order; a ticker already containing `.` or `:` is used unchanged. Without a ticker, Jedi tries the ISIN without suffixes. |
| `quote.base_url`, `quote.path`, `quote.query` | Build the URL and parameters; parameter values are strings with substitutions `{symbol}`, `{api_key}` or `{q}` (the available ISIN). |
| `quote.price_path`, `quote.prev_close_path` | JSON key paths required to read price and previous close; a numeric path element can index an array. |
| `quote.trading_day_path` | Optional `YYYY-MM-DD` date path in `eod` mode; otherwise Jedi uses the current local date. |
| `quote.change_percent_path`, `quote.change_percent_strip_percent` | API-supplied percentage; without the path, the percentage is calculated from price and previous close. `true` strips `%` from the string. |

The current adapter also treats responses containing `Note` or `Information` as throttling indicators and expects a nonempty `Global Quote` object. Although JSON paths can be configured, an API with a different root may therefore need **a code change**. `symbol_path` and `change_path` appear in built-in configuration but are not read by the current extraction method: do not assume they have an effect on a new provider. `prev_close_path` remains required by the code even if `change_percent_path` supplies the percentage.

## Diagnose without inventing a quote

First check file location and syntax. For a security whose ISIN is known, a query that changes no database can show whether a provider replies:

```console
jedidemo config --paths
jedidemo quote get FR0000120271
```

This example command appears in Jedi's help; **it predicts neither an actual response nor permission to query the configured service**. `quote get` has no `--mode` option and does not read the stored quote. To target one mode for a registered security, `quote update <id-or-isin> --mode=eod` is supported, but **stores** the result on success; choose a suitable security and test procedure before using it. `quote refresh --mode=eod` may update several securities and is not the first diagnostic step. `quote set` can record a checked quote without an external request.

| Symptom or stage | Concrete check |
|---|---|
| Configuration not applied | `config_file` path, YAML indentation, an order list containing the provider's exact name; lists replace built-in lists. |
| No Web identifier | ISIN, ticker/name required by template, derived variables and transformations, ISIN exception. |
| HTTP `429`, another error, or very short body | Quota, URL, redirect, permitted access, consent page; HTTP `200` does not guarantee a quote. |
| No match or a nonnumeric capture | Actual received HTML, named `price`/`variation` group, decimal format and HTML entities; verify the right security. |
| Empty or limited API result, unexpected JSON | Symbol and suffixes tried, key and quota, `Global Quote` structure and JSON paths. |
| Variation `0.0` | Check whether `regex_variation` was omitted: zero may mean “not extracted.” |

Jedi attempts patterns, keys, providers and modes according to configuration; the context of the final failure does not necessarily describe **every** earlier attempt. The log may contain a response excerpt, URL, parsing error and possibly an API key: inspect it locally and redact these values before sharing. Configuration errors, network responses and extraction of the wrong number are distinct problems. Check price and date against an independent authorized source before recording or using them in a trade. Keep data provenance and conditions of use, as described in [chapter 21](en_21_preparing_a_historical_study.md).
