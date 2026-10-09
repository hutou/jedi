module Jedi
  module Tools
    class CandidateReporter
      def initialize(@evaluation : CandidateEvaluation)
      end

      def render(*, extended : Bool = false) : String
        extended ? render_extended : render_summary
      end

      private getter evaluation

      private def render_summary : String
        String.build do |io|
          io << I18n.t("tools.candidate.report.summary_title") << '\n'
          io << "-" * 72 << '\n'
          if security = evaluation.security
            line(io, "tools.candidate.report.security", "#{security.ticker} — #{security.name}")
          end
          line(io, "tools.candidate.report.isin", evaluation.isin)
          render_price(io)
          line(io, "tools.candidate.report.scale", evaluation.scale.operational.definition)
          io << '\n' << I18n.t("tools.candidate.report.opening_title") << '\n'
          line(io, "tools.candidate.report.quantity", evaluation.quantity.to_s)
          line(io, "tools.candidate.report.opening_amount", money(evaluation.opening_amount))
          io << '\n'
          line(io, "tools.candidate.report.operability", operability_label)

          if funding = evaluation.funding
            line(io, "tools.candidate.report.funding_status", financeability_label(funding))
            line(io, "tools.candidate.report.available_after_reserve", money(funding.available_after_reserve))
            line(io, "tools.candidate.report.candidate_requirement", money(funding.candidate_requirement))
            line(io, "tools.candidate.report.margin_after_candidate", money(funding.margin_after_candidate))
            io << I18n.t("tools.candidate.report.summary_funding_note", {:steps => funding.candidate_step_limit.to_s}) << '\n'
          else
            line(
              io,
              "tools.candidate.report.funding_status",
              I18n.t("tools.candidate.funding.not_evaluated"),
            )
          end

          if failure = evaluation.failure
            io << '\n'
            line(io, "tools.candidate.report.reason", failure_message(failure))
          end
        end.rstrip
      end

      private def render_extended : String
        String.build do |io|
          io << I18n.t("tools.candidate.report.title") << '\n'
          io << "-" * 72 << '\n'
          if security = evaluation.security
            line(io, "tools.candidate.report.security", "#{security.name} (#{security.ticker})")
          end
          line(io, "tools.candidate.report.isin", evaluation.isin)
          render_price(io)
          line(io, "tools.candidate.report.scale", evaluation.scale.operational.definition)
          line(io, "tools.candidate.report.mode", mode_label)
          io << '\n'

          if evaluation.mode.capital?
            if sizing = evaluation.position_sizing
              if active_money = evaluation.money
                if capital = evaluation.capital
                  line(io, "tools.candidate.report.capital", money(capital))
                  line(io, "tools.candidate.report.risk_rate", pct(active_money.risk_rate))
                  line(io, "tools.candidate.report.steps_down", active_money.steps_down.to_s)
                  line(io, "tools.candidate.report.risk_distance", pct(sizing.risk_distance))
                  line(io, "tools.candidate.report.risk_amount", money(sizing.risk_amount))
                end
              end
            end
          end

          line(io, "tools.candidate.report.target_amount", money(evaluation.target_amount))
          line(io, "tools.candidate.report.quantity", evaluation.quantity.to_s)
          line(io, "tools.candidate.report.opening_amount", money(evaluation.opening_amount))
          line(io, "tools.candidate.report.minimum_operable_quantity", evaluation.minimum_operable_quantity.to_s)
          line(io, "tools.candidate.report.operability", operability_label)

          render_funding(io)

          io << '\n'
          line(io, "tools.candidate.report.minimum_quantity", evaluation.minimum_quantity.to_s)
          line(io, "tools.candidate.report.operability_steps", evaluation.operability_steps.to_s)
          line(io, "tools.candidate.report.scale_type", evaluation.scale.operational.type.to_s)
          if sizing = evaluation.position_sizing
            line(io, "tools.candidate.report.stop_price", money(sizing.stop_price))
            line(io, "tools.candidate.report.maximum_quantity_by_risk", sizing.maximum_quantity_by_risk.to_s)
            line(io, "tools.candidate.report.maximum_quantity_by_capital", sizing.maximum_quantity_by_capital.to_s)
            line(io, "tools.candidate.report.maximum_projected_investment", money(sizing.maximum_projected_investment))
            line(io, "tools.candidate.report.limiting_constraint", sizing.limiting_constraint.to_s)
          end

          if failure = evaluation.failure
            io << '\n'
            line(io, "tools.candidate.report.reason", failure_message(failure))
          end
          io << '\n' << I18n.t("tools.candidate.report.note")
        end
      end

      private def render_price(io : IO) : Nil
        line(io, "tools.candidate.report.price", money(evaluation.price))
        key = evaluation.price_source.explicit? ? "explicit" : "stored"
        line(io, "tools.candidate.report.price_source", I18n.t("tools.candidate.price_sources.#{key}"))
        if evaluation.price_source.stored?
          date = evaluation.price_date
          value = date ? date.to_s("%F %T %:z") : I18n.t("tools.candidate.price_sources.unknown_date")
          line(io, "tools.candidate.report.price_date", value)
        end
      end

      private def render_funding(io : IO) : Nil
        io << '\n'
        funding = evaluation.funding
        if funding.nil?
          line(io, "tools.candidate.report.financeability", I18n.t("tools.candidate.financeability.not_evaluated"))
          return
        end

        line(io, "tools.candidate.report.portfolio_capital", money(funding.portfolio_capital))
        line(io, "tools.candidate.report.running_trades", funding.running_trade_count.to_s)
        line(io, "tools.candidate.report.current_global_investment", money(funding.current_global_investment))
        line(io, "tools.candidate.report.existing_trade_reserve", money(funding.existing_trade_reserve))
        line(io, "tools.candidate.report.available_after_reserve", money(funding.available_after_reserve))
        line(io, "tools.candidate.report.candidate_reserve", money(funding.candidate_reserve))
        line(io, "tools.candidate.report.candidate_requirement", money(funding.candidate_requirement))
        line(io, "tools.candidate.report.financeability", financeability_label(funding))
        line(io, "tools.candidate.report.margin_after_candidate", money(funding.margin_after_candidate))
        line(io, "tools.candidate.report.available_before_reserve", money(funding.available_before_reserve))
        line(io, "tools.candidate.report.funding_steps", funding.candidate_step_limit.to_s)
        unless funding.trade_reserves.empty?
          io << '\n' << I18n.t("tools.candidate.report.trade_reserves") << '\n'
          funding.trade_reserves.each do |trade|
            io << "  %-20s %10s\n" % ["##{trade.trade_id} #{trade.trade_name}", money(trade.reserve)]
          end
        end
        io << I18n.t("tools.candidate.report.funding_note") << '\n'
      end

      private def line(io : IO, key : String, value : String) : Nil
        io << "%-32s %s\n" % [I18n.t(key) + " :", value]
      end

      private def money(value : Float64) : String
        "%.2f €" % value
      end

      private def pct(value : Float64) : String
        "%.2f %%" % (value * 100.0)
      end

      private def mode_label : String
        key = evaluation.mode.fixed_amount? ? "fixed_amount" : "capital"
        I18n.t("tools.candidate.mode.#{key}")
      end

      private def failure_key(failure : CandidateFailure) : String
        case failure
        in .initial_quantity_zero?
          "initial_quantity_zero"
        in .insufficient_operability?
          "insufficient_operability"
        in .capital_sizing?
          "capital_sizing"
        end
      end

      private def failure_message(failure : CandidateFailure) : String
        key = failure_key(failure)
        if failure.capital_sizing? && (sizing_failure = evaluation.position_sizing.try(&.failure))
          key = case sizing_failure
                in .risk_quantity_zero?       then "risk_quantity_zero"
                in .capital_quantity_zero?    then "capital_quantity_zero"
                in .insufficient_operability? then "insufficient_operability"
                end
        end
        I18n.t("tools.candidate.failure.#{key}")
      end

      private def operability_label : String
        I18n.t(evaluation.operable? ? "tools.candidate.operable.yes" : "tools.candidate.operable.no")
      end

      private def financeability_label(funding : CandidateFunding) : String
        I18n.t(funding.financeable? ? "tools.candidate.operable.yes" : "tools.candidate.operable.no")
      end
    end
  end
end
