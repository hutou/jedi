module Jedi
  module Tools
    class BacktestPlotter
      getter result : BacktestResult

      def initialize(@result : BacktestResult)
      end

      def plot : Nil
        valuations = result.daily_valuations
        return if valuations.empty?

        history = result.quote_history
        quotes = history.quotes.map(&.[:close])
        first_quote = quotes.first
        reference_capital = result.reference_capital_cents
        return if first_quote.zero? || reference_capital <= 0

        quotation_index = quotes.map { |value| value / first_quote }
        net_value_index = valuations.map do |valuation|
          1.0 + valuation.net_gain_cents.to_f / reference_capital.to_f
        end
        investment_ratio = valuations.map do |valuation|
          valuation.investment_cents.to_f / reference_capital.to_f
        end
        days = valuations.map(&.day)

        indicators = result.indicators
        slope = indicators.normalized_regression_slope
        intercept = indicators.normalized_regression_intercept
        regression = history.trading_days.map { |day| day * slope + intercept }
        equation = "y=#{slope.round(6)}x+#{intercept.round(4)}, " +
                   I18n.t("tools.backtest.plot.normalized_slope") +
                   "=#{indicators.normalized_regression_slope_percent.round(4)}%"

        Cryplot.plot {
          title(
            I18n.t("tools.backtest.plot.title") +
            " #{history.isin} - #{history.name}",
          ).title_font_size(14).title_text_color("blue")

          xlabel(
            "#{history.date_first.to_s("%d-%m-%Y")} - " +
            history.date_last.to_s("%d-%m-%Y"),
          )
          ylabel(I18n.t("tools.backtest.plot.indices_and_ratios"))
          if slope < 0
            legend.at_top_right
          else
            legend.at_top_left
          end
          grid.show.back.line_width(1)
          border.none
          style_fill.border_show
          tics.hide
          border.left.right.top.bottom.back
          draw_curve(days, net_value_index)
            .label(I18n.t("tools.backtest.plot.net_value_index"))
          draw_curve(days, investment_ratio)
            .label(I18n.t("tools.backtest.plot.investment_ratio"))
          draw_curve(history.trading_days, quotation_index)
            .label(
              I18n.t("tools.backtest.plot.quotation_index") + " (" +
              history.trading_days.size.to_s + " " +
              I18n.t("tools.backtest.plot.trading_days") + ")",
            )
          draw_curve(history.trading_days, regression)
            .label(I18n.t("tools.backtest.plot.regression") + " (#{equation})")
          size(640, 480)
          show
          save("jedi_backtest.svg")
        }
      end
    end
  end
end
