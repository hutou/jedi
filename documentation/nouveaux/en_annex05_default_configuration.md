# Default configuration and parameter usage

This appendix describes every entry in Jedi’s built-in configuration, the `App::YAML_CONFIG` constant in `src/jedi/app/application.cr`. It matches the sources used for this edition, preparing v1.1. A built-in value is a starting point; it may differ from your effective configuration.

The tables give original values and their actual use in the code. Fields that are present but not consulted are identified. The complete YAML block at the end reproduces all values, including technical quote-collection patterns.

## Read the effective configuration

~~~console
jedi config --paths
jedi config
~~~

The first command displays paths, including config_file. The second displays those paths and the effective configuration after merging the personal file. In the experiment environment, use the same commands with jedidemo; its file may differ. [Chapter 02](en_02_installing_and_preparing_jedi.md) explains these environments.

The personal file uses YAML: indentation places entries beneath their parent. Jedi merges nested mappings; a supplied scalar or list replaces the entire corresponding scalar or list. You do not need to copy the complete configuration.

To allocate **€50,000 to both production and simulation**, these entries alone suffice in the relevant environment’s file:

~~~yaml
trading:
  capital: 50000
simulation:
  capital: 50000
~~~

Both built-in capitals are **20,000**, rather than 50,000. A value of 50,000 displayed by config may therefore come from this personal override. Values take effect on the next Jedi invocation; existing data and recorded transactions are not recalculated.

## Display, monitoring and checks

| Entry | Built-in value | Actual use |
|---|---|---|
| `border` | `"ascii"` | Table border style. `--border=PRESET`, before the command family, overrides it for that invocation. |
| `watchrate` | `10.0` | Proximity threshold in the order list, in percent: `10.0` means 10%. An absolute distance strictly below it receives the watch marker if no ready marker applies. It changes display, not risk or order prices. |
| `diagnostic_steps` | `3` | Quantity-check horizon over subsequent upward steps. Also the default for `--operability-steps` in `candidate` and capital-sized backtests. Candidate funding reserves use the larger of this value and `money.n`. |
| `quotlife` | `240.0` | Maximum age, in minutes, of a recorded quote before current-price resolution attempts an update: 240 minutes = 4 hours. If the attempt fails, a previously recorded price may be reused with a warning. |
| `tickcheck` | `true` | Checks the price recorded by `operation create` against the security’s quotation tick. Prefixing the price with `+` bypasses the check for that operation. Play and backtest engines record simulated operations without this check, while order prices still use tick rounding. |

Border styles are ascii, reducedascii, modern, reducedmodern, fancy, markdown, empty and blank. For example:

~~~console
jedidemo --border=modern trade list
~~~

Watchrate compares the proposed order price with the recorded quotation; it triggers no transaction. Quotlife is read by current-price resolution, including for trade orders. It does not schedule periodic updates: quote get queries providers without this age limit and without changing the database. Play orders use the simulated price, without this Web refresh.

## Transaction fees

The following entries are under fees.

| Entry | Built-in value | Actual use |
|---|---|---|
| `rate` | `0.0035` | Proportional fee rate: `0.0035` = 0.35% of the transaction amount. Used without an explicit `--fees`, and for new transactions in play, backtest and score. |
| `min` | `0.0` | Minimum monetary charge per transaction, in the same currency as prices. The calculation takes the larger of the proportional charge and this minimum, then rounds to cents. |

With built-in values, a €1,000 transaction incurs €3.50 in proportional fees. For a purchase, any security tax is added to the rate before comparison with the minimum. An explicit operation create --fees amount replaces automatic calculation. Candidate funding projections exclude fees. Simulated fees enter play, backtest and score results; they do not change scale coefficients.

## Real capital and money limits

Under trading:

| Entry | Built-in value | Actual use |
|---|---|---|
| `capital` | `20000` | Reference capital for real trades’ money protections. Also used for candidate sizing and funding when `--capital` is absent. Does not set a real trade’s initial purchase quantity. |

Under money:

| Entry | Built-in value | Actual use |
|---|---|---|
| `risk_rate_min` | `0.005` | Lower accepted bound for money’s `r`: 0.5%. |
| `risk_rate_max` | `0.05` | Upper accepted bound for `r`: 5%. |
| `target_coeff_min` | `0.5` | Lower accepted bound for the target coefficient `o`. |
| `target_coeff_max` | `5.0` | Upper accepted bound for `o`. |
| `steps_down_min` | `1` | Lower accepted bound for the integer number of downward steps `n`. |
| `steps_down_max` | `5` | Upper accepted bound for `n`. |

These bounds are **inclusive**. They validate input; they do not automatically assign money management to trades. All three fields r, o and n must be supplied, for example money=r:2%,o:2,n:2. R is the fraction at risk, o multiplies monetary risk to set the target, and n sets the number of downward steps projected. Risk_rate_min and risk_rate_max can also be percentage strings in YAML, such as "0.5%".

## Simulation parameters

The following entries are under simulation. Rates here are numeric fractions: 0.015 means 1.5%, whereas watchrate: 10.0 directly means 10%.

| Entry | Built-in value | Actual use |
|---|---|---|
| `capital` | `20000` | Reference capital for play’s protections. Also enters the reference opening amount used by score and backtest without `--capital`. |
| `distance` | `0.2` | Fraction in the denominator of the reference opening amount: `0.2` = 20%. Used by score and backtest without `--capital`; `--distance` can override it in the latter. Not used by play. |
| `risk_rate` | `0.015` | Fraction in the numerator of the reference opening amount: `0.015` = 1.5%. Used by score and backtest without `--capital`. Never implicitly supplies money’s `r`, including in play. |

The reference opening amount is calculated at startup:

~~~text
opening amount = capital × risk_rate / distance
built-in values: 20,000 × 0.015 / 0.2 = €1,500
personal capital of 50,000: 50,000 × 0.015 / 0.2 = €3,750
~~~

The result is truncated to a whole monetary unit. Keep capital and distance strictly positive. For protections, the engine falls back to trading.capital if simulation capital is not positive. **Play does not use the reference opening amount**: it opens with q0 shares at c0, or starts from the selected recorded transaction.

### Which settings does each tool use?

| Use | Capital | Risk rate | Distance or horizon |
|---|---|---|---|
| Real trade orders with money | trading.capital | The trade’s r | The trade’s n and scale. |
| tools play with money | simulation.capital | r supplied in the simulation | The simulation’s n and scale. |
| tools candidate --money=... | --capital, otherwise trading.capital | r from --money | Distance reached after n downward scale steps. |
| tools backtest without --capital | simulation.capital for the opening amount | simulation.risk_rate for that amount; money.r for protections when enabled | simulation.distance, overridden by --distance if supplied, for the amount; money.n for protections. |
| tools backtest --capital=... | Explicit capital | r from the required --money | Distance reached after n steps; --distance is incompatible with this mode. |
| tools score | simulation.capital in the opening amount | simulation.risk_rate in that amount | simulation.distance in that amount; score simulations run without money protections. |

With candidate --amount, the opening amount is explicitly chosen: it is not sized using simulation.distance or simulation.risk_rate.

### Play example with personal capital of €50,000

After the configuration override shown above, this invented simulation supplies its own r, o and n:

~~~console
jedidemo tools play -c o0,6-14,17 -- \
  "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,q0=1000,c0=10,tick=0.01,money=r:2%,o:2,n:2,loss=active" -1
~~~

Risk is **€1,000** (50,000 × 2%) and the target threshold **€2,000** (1,000 × 2). Projection follows two scale steps. The first purchase is 1,000 shares at €10, or **€10,000 before fees**, despite the reference opening amount of €3,750. In this scenario the downward step executes a protective sale at €9, a gross loss of €1,000 before fees. Changing only simulation.distance or simulation.risk_rate leaves this path unchanged; changing money.r can change the protection.

[Chapter 18](en_18_capital_risk_and_position_sizing.md) explains risk and sizing; [chapter 19](en_19_checking_with_tools_calc_and_play.md) introduces play paths.

## Universe and quote-collection order

The following entries are under market_data.

| Entry | Built-in value | Actual use |
|---|---|---|
| `default_universe` | `"france"` | Default universe used to choose the historical market database, including by market commands and tools reading database history. `--universe` overrides it where offered. Does not select a dataset or the PEA group. |
| `mode_order` | `["live", "eod"]` | Collection-mode order when the command does not set a mode: live Web pages, then the eod API. The first accepted result ends the search. |
| `api_order` | `["alphavantage"]` | API provider names to try in this order in eod mode. Each name must match a definition in api_providers. |
| `website_order` | `["abcbourse", "tradingsat", "boursorama"]` | Web provider names to try in this order in live mode. Each name must match a definition in websites. |

The universe concerns historical storage; the other entries in this section collect a **current quotation**. They do not populate OHLCV history. Live means Web collection without guaranteeing real-time prices; eod means the API path. For real trade orders, current-price resolution requests live by default: changing mode_order does not force this path to use eod.

An empty order list traverses all matching definitions; it does not disable providers. With a nonempty list, a definition omitted from that list is not attempted. [Appendix 02](en_annex02_data_providers.md) explains provider configuration and diagnosis.

## Built-in API provider

The following entries are under market_data.api_providers.alphavantage.

| Entry | Built-in value | Actual use |
|---|---|---|
| `api_key` | `"yyyyy"` | Value sent to the provider through `{api_key}`. `yyyyy` is a placeholder; supply your own key to use this API. |
| `symbol_candidates.mode` | `"ticker_plus_suffixes"` | Builds API symbols from the ticker and suffixes. A ticker already containing `.` or `:` is kept unchanged. Without a ticker, Jedi uses the available identifier, here the ISIN. |
| `symbol_candidates.suffixes` | `[".PAR", ".PA", ""]` | Suffixes tried in order. The final empty suffix tries the ticker alone. No suffix is added to an ISIN used when the ticker is missing. |

Under market_data.api_providers.alphavantage.quote:

| Entry | Built-in value | Actual use |
|---|---|---|
| `base_url` | `"https://www.alphavantage.co"` | Provider base address, to which the path is appended. |
| `path` | `"/query"` | Request path under that base address. |
| `query.function` | `"GLOBAL_QUOTE"` | HTTP function parameter requesting the GLOBAL_QUOTE response. |
| `query.symbol` | `"{symbol}"` | HTTP parameter replaced with each symbol built above. |
| `query.apikey` | `"{api_key}"` | HTTP parameter replaced with api_key. |
| `symbol_path` | `["Global Quote", "01. symbol"]` | **Unused** by current extraction. Its presence does not cause the returned symbol to be checked. |
| `price_path` | `["Global Quote", "05. price"]` | Path in the JSON response to the price to read. |
| `trading_day_path` | `["Global Quote", "07. latest trading day"]` | Path to the trading date. In eod mode it is recorded at local midnight. |
| `prev_close_path` | `["Global Quote", "08. previous close"]` | Path to the previous close. The code reads it even when the percentage change is supplied directly. |
| `change_path` | `["Global Quote", "09. change"]` | **Unused** by current extraction: the absolute price change is not read at this path. |
| `change_percent_path` | `["Global Quote", "10. change percent"]` | Path to the percentage change. If not provided, Jedi computes it from the price and previous close. |
| `change_percent_strip_percent` | `true` | Removes the percent sign from the change text before converting it to a number. |

A path such as ["Global Quote", "05. price"] means: open the Global Quote object, then read 05. price within it. The current reader also requires a nonempty Global Quote object. Changing only paths may therefore be insufficient to use another API.

## Built-in Web providers

Long extraction patterns are reproduced exactly in the complete YAML block. Each site has its own address, identifier templates and capture patterns. Their presence does not guarantee a response or lasting HTML compatibility.

### ABC Bourse

Under market_data.websites.abcbourse:

| Entry | Built-in value | Actual use |
|---|---|---|
| `url` | `"https://www.abcbourse.com/cotation/{key}"` | Page address: `{key}` is replaced with each candidate identifier. |
| `regex_price` | Pattern in the complete YAML block | Pattern locating the price in HTML. The named price group supplies the extracted number. |
| `regex_variation` | Pattern in the complete YAML block | Pattern locating percentage change in HTML. The named variation group supplies the extracted number. |

Under key_strategy.candidates, indexes [0] and [1] denote the first and second templates:

| Entry | Built-in value | Actual use |
|---|---|---|
| `[0].template` | `"{ticker}p"` | First identifier: ticker followed by p. Skipped if the ticker is unavailable. |
| `[1].template` | `"{isin}"` | Second identifier: ISIN alone. |

### Tradingsat

Under market_data.websites.tradingsat:

| Entry | Built-in value | Actual use |
|---|---|---|
| `url` | `"https://www.tradingsat.com/{key}"` | Page address: `{key}` is replaced with each candidate identifier. |
| `regex_price` | Pattern in the complete YAML block | Pattern locating the price in HTML. The named price group supplies the extracted number. |
| `regex_variation` | Pattern in the complete YAML block | Pattern locating percentage change in HTML. The named variation group supplies the extracted number. |

Under key_strategy.candidates:

| Entry | Built-in value | Actual use |
|---|---|---|
| `[0].template` | `"{name_slug}-{isin}"` | Identifier combining the transformed name and ISIN. Skipped if the required name is unavailable. |
| `[0].vars.name_slug.from` | `"name"` | The security name is the input text for name_slug. |
| `[0].vars.name_slug.ops[0]` | `"downcase"` | Converts the name to lowercase. |
| `[0].vars.name_slug.ops[1].gsub.pattern` | `"\\."` | Finds periods in the name. The pattern is a regular expression. |
| `[0].vars.name_slug.ops[1].gsub.replace` | `""` | Replaces those periods with an empty string, removing them. |
| `[0].vars.name_slug.ops[2].gsub.pattern` | `" "` | Finds ordinary spaces. |
| `[0].vars.name_slug.ops[2].gsub.replace` | `"-"` | Replaces those spaces with hyphens. |

### Boursorama

Under market_data.websites.boursorama:

| Entry | Built-in value | Actual use |
|---|---|---|
| `url` | `"https://www.boursorama.com/cours/{key}/"` | Page address: `{key}` is replaced with each candidate identifier. |
| `regex_price` | Pattern in the complete YAML block | Pattern locating the price in HTML. The named price group supplies the extracted number. |
| `regex_variation` | Pattern in the complete YAML block | Pattern locating percentage change in HTML. The named variation group supplies the extracted number. |

Under key_strategy.candidates:

| Entry | Built-in value | Actual use |
|---|---|---|
| `[0].template` | `"1rP{ticker}"` | First identifier: 1rP followed by the ticker. |
| `[1].template` | `"1rEP{ticker}"` | Second identifier: 1rEP followed by the ticker. |
| `[2].template` | `"{ticker}"` | Third identifier: ticker alone. All three templates are skipped if the ticker is unavailable. |
| `[2].ops.ticker` | `["upcase", "trim"]` | **Unused at this location** by the current builder. This entry’s upcase and trim transformations are therefore not applied. Supported operations are under vars.<variable>.ops. |

## Complete built-in configuration

This block reproduces the built-in values as readable YAML. Source-code comments are not configuration entries. It is a reference; a personal file can contain only the desired overrides.

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
      regex_price: id="lastcx">(?<price>\d+(?:[.,]\d+)*)\s*&#x20AC;
      regex_variation: id="varcx"\s+class="quote_(up|down)b">(?<variation>(&#x2B;|&#x2D;|\+|-)?\d+(?:[.,]\d+)*)%
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
      regex_price: class="price">(?<price>\d+(?:[,.]\d+)*)\s*€
      regex_variation: class="variation var-(down|neutral|up)">(?<variation>[+-]?\d+(?:[,.]\d+)*)\s*%
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
      regex_price: c-faceplate__info.+?price.+?ist-last>(?<price>\d+(?:[,.]\d+)*)<
      regex_variation: c-faceplate__info.+?fluctuation.+?ist-variation>(?<variation>[+-]?\d+(?:[.,]\d+)*)%
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
