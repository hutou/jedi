module Jedi
  module Tools
    # Economic summary of the completed simulation, without statistical
    # diagnostics or extrapolation beyond the selected quotation period.
    class BacktestCompactReporter
      getter result : BacktestResult

      def initialize(@result : BacktestResult)
      end

      def render : String
        history = result.quote_history

        String.build do |io|
          io << I18n.t("tools.backtest.table.title") << '\n'
          line(io, "security", {
            :name => history.name, :ticker => history.ticker, :isin => history.isin,
          })
          line(io, "period", {
            :first => history.date_first.to_s("%Y-%m-%d"),
            :last  => history.date_last.to_s("%Y-%m-%d"),
            :days  => history.num_trading_days.to_s,
          })
          line(io, "scale", {:definition => result.scale.operational.definition})

          case policy = result.sizing_policy
          when FixedAmountSizingPolicy
            line(io, "fixed_amount", {:amount => "%.2f" % policy.amount})
          when CapitalSizingPolicy
            line(io, "capital", {
              :amount => "%.2f" % policy.capital,
              :risk   => "%.2f" % (policy.risk_rate * 100.0),
              :steps  => policy.stop_steps.to_s,
            })
            line(io, "operability", {
              :quantity => policy.minimum_quantity.to_s,
              :steps    => policy.operability_steps.to_s,
            })
          end
          mode = result.execution_mode.conservative? ? "conservative" : "legacy"
          opening = result.opening_day_policy.next_session? ? "next" : "same"
          line(io, "execution", {
            :mode    => I18n.t("tools.backtest.compact.modes.#{mode}"),
            :opening => I18n.t("tools.backtest.compact.opening_days.#{opening}"),
          })
          line(io, "openings", {
            :accepted => result.trade_count.to_s,
            :rejected => result.opening_rejection_count.to_s,
          })

          if result.trade_count.zero?
            io << I18n.t("tools.backtest.no_trade_opened") << '\n'
          else
            line(io, "first_purchase", {
              :date     => result.first_operation_date.not_nil!.to_utc.to_s("%Y-%m-%d"),
              :quantity => result.first_accepted_sizing.not_nil!.quantity.to_s,
              :amount   => "%.2f" % (result.initial_buy_cents / 100.0),
            })
            line(io, "operations", {:operations => result.operation_count.to_s})
            money_line(io, "gross_gain", result.gross_gain_cents)
            money_line(io, "fees", result.total_fees_cents)
            money_line(io, "net_gain", result.net_gain_cents)
            money_line(io, "maximum_investment", result.maximum_investment_cents)
            line(io, "net_return", {:value => "%.2f" % result.net_return_on_maximum_investment})
            line(io, "holdings", {
              :quantity => result.final_stock.to_s,
              :value    => "%.2f" % (result.portfolio_cents / 100.0),
            })
            io << I18n.t("tools.backtest.compact.note") << '\n'
          end
        end
      end

      private def line(io : IO, key : String, context : Hash(Symbol, String)) : Nil
        io << I18n.t("tools.backtest.compact.#{key}", context) << '\n'
      end

      private def money_line(io : IO, key : String, cents : Int32) : Nil
        line(io, key, {:value => "%.2f" % (cents / 100.0)})
      end
    end
  end
end
