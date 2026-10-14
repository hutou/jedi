# Jedi glossary and notation

## Objects and paths

| Term | Meaning in Jedi |
|---|---|
| Security | Instrument identified by an ISIN, name and ticker. |
| Scale | Rules mapping a mechanical state to target prices and quantities. |
| Builder | Parameters creating a scale; `score`'s `I:` or `II:` prefix states its type. |
| Operational definition | Definition actually used after construction and any transformations, shown in reports. |
| Trade | A security's purchase/sale path with successive settings. |
| Settings | Scale applying from a date/time, with the information needed for continuity. |
| Operation | An executed and recorded purchase or sale. A proposed order is not an operation. |
| Stock, holdings | Number of shares held at a point in the path. |
| PRU | French abbreviation for *prix de revient unitaire*: average acquisition cost per share held, including fees and any applicable purchase tax; an accounting reference distinct from `c0`. |
| Round trips | Successive sales and purchases following scale movements. |
| Operability | Ability to produce checked orders with sufficient integer quantities. |
| Funding | Ability to cover the opening and projected needs while accounting for other trades. |
| Note | Dated journal entry describing a choice or event without changing the trade. |

## Positions and coefficients

| Notation | Meaning |
|---|---|
| `x:y:e` | Position: upward jumps, downward jumps and step within active settings. |
| Step | Local stage within the scale. |
| Level | Reference for a series of steps; reaching a boundary causes a jump. |
| `q0`, `c0` | Trade reference quantity and price, initially those of the first purchase. |
| `kc`, `ks` | Price coefficients (`kc`, type I) and stock coefficients (`ks`, in both scale types). |
| `vr` | Relative variation used to construct scale spacing. |
| `np`, `nn` | Step counts towards positive and negative boundaries. |
| `emax` | Positive upper scale boundary; reaching it triggers an upward jump and returns step `e` to zero. |
| `emin` | Negative lower scale boundary; reaching it triggers a downward jump and returns step `e` to zero. |
| `sr` | Target stock fraction at the final internal upward step of the compatibility builder. |
| `mi` | Downward-purchase budget parameter of that builder, relative to the initial amount. |
| `ki` | Investment fraction applied at level changes. |
| `kb` | Convention used to calculate the capital coefficient at level changes. |
| `kd` | Builder parameter transforming quantities; it is not a return. |
| `kcb`, `kcp`, `ksp` | Calculated capital, price and stock coefficients. |
| `kcpc` | Cumulative price coefficient from previous settings, retained for trade continuity. |
| `kspc` | Cumulative stock coefficient from previous settings, retained for trade continuity. |
| `cpe`, `spe` | Theoretical price and stock at a target position. |
| Type I | Scale based on reference coefficients; `calc` checks its calculations. |
| Type II | Scale recentered from actual operations; examine it with `play`. |
| Optimised | Construction or continuity variant; the term does not prove a better gain. |

[Chapters 13–16](en_13_reading_the_structure_of_a_scale.md) explain the parameters. A reset may redefine `q0` and `c0`; read active settings before interpreting them as the very first historical purchase.

`kcpc` and `kspc` equal **1 initially and on reinitialisation**. An ordinary settings change multiplies their previous values by the reached level coefficients `kcp` and `ksp`, while jump counters `x` and `y` restart at zero. For example, `c0=10` and `kcpc=1.40` carry forward a €14 price reference; `q0=100` and `kspc=0.785714` carry forward a theoretical stock reference of approximately 78.57 shares. Actual holdings may differ. [Chapter 16](en_16_continuity_between_settings.md#change-the-local-frame) explains this carry-forward.

`emax` and `emin` are **jump boundaries**, not steps at which a position remains recorded. With `emax=+3` and `emin=-3`, internal steps range from `−2` to `+2`, including zero. A rise from `e=+2` increases `x` and returns `e` to zero; a fall from `e=-2` increases `y` and returns `e` to zero. For a builder using `np` and `nn`, `emax=np` and `emin=-nn`. See [chapter 12](en_12_positions_steps_and_levels.md#reach-a-boundary-and-change-level).

### Distinguish PRU from the mechanical reference

PRU is an accounting reference in the broker's portfolio. For example, a single purchase of 100 shares at €10, with €3.50 fees and no other tax, has an acquisition cost per share of `(1000 + 3.50) / 100 = €10.035`. Jedi's initial `c0` remains the execution price of **€10**. [BoursoBank's cash-purchase PRU calculation](https://www.boursobank.com/aide-en-ligne/bourse/comment-investir-en-bourse/fonctionnement-de-la-bourse/question/comment-se-calcule-le-prix-de-revient-pru-au-comptant-642), in French, illustrates inclusion of fees and any applicable tax.

Each new purchase recalculates PRU from the cost of shares still held and the new purchase, weighted by their quantities. It is not the balance of purchases minus sales divided by remaining holdings. Jedi does not require the broker's PRU to calculate orders: it uses operations and settings references. Reinitialisation may therefore change `c0` without making that new reference an accounting PRU.

## Split and new origin

| Notation | Meaning |
|---|---|
| `split=NEW:OLD` | Number of new shares for old ones; `1:10` is a ten-for-one consolidation. |
| Effective holding | Holding to use after conversion, even while the latest historical operation retains the old quantity. |
| `reinit=reset,price` | Immediate new mechanical origin; position `0:0:0`, effective stock as `q0`, chosen price as `c0`. |
| `reinit=merge,price` | New origin established by the following manual transaction; references remain pending until then. |
| `split + reinit` | Combination available in next-version / v1.1; convert stock before reset or merge, supply prices after the split. |
| Fractional entitlement | Fractional right resulting from consolidation; Jedi accounts for neither its handling nor its settlement. |

[Chapter 09](en_09_adapting_or_ending_a_trade.md) details the effects and restrictions. Reinitialisation changes mechanical references, not past financial results.

## Orders and protection

| Term | Meaning |
|---|---|
| Limit | Purchase at a maximum price or sale at a minimum price. |
| Stop | Order triggered at a threshold; execution price may differ. |
| StopLoss | Protection order: loss cutting or gain protection according to trade state. |
| Tick | Price increment used when rounding an order. |
| Gap | Difference between previous close and next opening; it may cross a level without execution at that level. |
| `conservative` | Normal OHLC policy, prioritising orders executable at the opening and handling gaps. |
| `next` | Orders generated by the first purchase active on the next session; backtest default. |

The scale's operating Stop and protective StopLoss serve different purposes. [Chapters 17](en_17_from_trade_state_to_orders.md) and [22](en_22_simulating_with_tools_backtest.md) explain the rules.

## Capital

| Notation | Meaning |
|---|---|
| `K` | Capital allocated to trading; monetary reference for sizing and funding. |
| `r` | Fraction of K corresponding to a trade's nominal risk. |
| `R` | Monetary risk: `K × r`. |
| `o` | Target coefficient; monetary threshold `O = o × R` before gain protection. |
| `n` | Downward step count used for the risk path. |
| `T` | Requested opening amount, excluding fees. |
| `money` | Definition `r:...,o:...,n:...`; all three fields are required. |
| Future reserve | Projected additional purchase need over the displayed horizon. |
| Margin after candidate | Capital remaining after committed-trade and candidate needs. |
| `diagnostic_steps` | Operational-check setting, initially 3; affected help pages show its effective value. |

Nominal risk is not a guaranteed loss ceiling. `candidate` reserves are projections excluding fees over a horizon, not proof that every later path would be funded. See [chapters 06](en_06_tools_candidate.md) and [18](en_18_capital_risk_and_position_sizing.md).

## Data and freshness

| Term | Meaning |
|---|---|
| OHLCV | Open, High, Low, Close and Volume for a session. |
| Prepared file | Identified quotations converted to Jedi's format and checked before use. |
| Source | Market database name, such as `demo`. |
| Universe | General scope included in the database name; `france` by default. |
| Dataset | Imported collection with memberships, files and metadata. |
| Group | Named security list independent of dataset membership. |
| Last complete import | Date and scope of the last complete import/replacement; import history. |
| Latest available quotation | Most recent date present; it may concern very few securities. |
| Global freshness | Date reached by at least 95% of dataset securities, calculated from actual data after imports/updates. |
| Individual lag | Market-session difference from that reference: 0 normal, 1–2 watch, more than 2 rejected. |

Freshness is not measured against today's date. A file, historical selection or ambiguous dataset reference may prevent its assessment. [Chapters 04](en_04_tools_profile.md) and [10](en_10_market_database.md) explain these cases.

## profile criteria

| Criterion | Reading |
|---|---|
| Trend | Estimated closing-price direction over 252 sessions, expressed as an annual rate. |
| Liquidity | Median Close × Volume; traded value per session, in euros if prices are in euros. |
| ATR20 | Mean true range over 20 sessions, including differences from previous close; expressed as a percentage of price. |
| Oscillation | Path amplitude and reversal movements; `Sw5/y` counts moves of at least 5% and annualises them. |
| Drawdown | Largest decline from an earlier peak over the examined window. |
| Gap% | Frequency of gaps of at least 3% over the recent window. |
| Step% | Suggested scale spacing based on security characteristics; not a mandatory order. |
| Total | Unweighted sum of the first N ranks; smaller means better ranked within the current selection. |
| Status | Retained, watch or rejected according to checks; rejected securities do not enter ranking. |

## Results and studies

| Term | Definition |
|---|---|
| Gross gain | Sales − purchases + final holdings valued at the last close, excluding fees. |
| Net gain | Gross gain − charged fees. |
| Current investment | Cumulative purchases − sales, excluding fees. |
| Maximum investment | A trade’s peak purchases minus sales; in backtest and score, the largest such peak among successive trades, excluding fees. |
| Backtest buy-sell balance | Cumulative balance retaining closed trades’ gains and losses; used to calculate cumulative gain. |
| Fitness | In `score`, gross gain / first purchase amount, covering the entire period. |
| Max.inv | In `score`, maximum investment / first purchase, excluding fees. |
| Op/mo | All operations, including openings, normalised to 21 sessions from the first operation. |
| Rnet% | Net result relative to maximum investment in economic output. |
| Rann% | Annualisation of that ratio over its duration; not a forecast. |
| Adaptive search | Exploration followed by refinement of chosen regions; budget limits evaluated scales. |
| Grid search | Exhaustive evaluation of available candidates for the builder. |
| Raw ranking | Direct sorting of displayed measures. |
| Jedi ranking | Expert reading adding engine preferences and diagnostics. |
| Separate verification | Test of a fixed scale on data not used to choose it. |
| Dated monitoring | Keeping a decision at its actual date, then subsequent observations. |

See [chapter 24](en_24_interpreting_comparing_and_monitoring.md) to interpret these results.
