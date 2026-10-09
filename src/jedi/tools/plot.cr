module Jedi
  module Tools
    class Plot
      getter quote_input : MarketData::QuoteHistoryInput
      getter position : String
      getter! quote_history : QuoteHistory
      getter! stats : Indicators

      def initialize(
        filename : String,
        @position : String,
      )
        @quote_input = MarketData::FileQuoteHistoryInput.new(filename)
      end

      def initialize(
        @quote_input : MarketData::QuoteHistoryInput,
        @position : String,
      )
      end

      def filename : String
        quote_input.description
      end

      def run(
        option_records : String? = nil,
        option_date : String? = nil,
        render : Bool = true,
      ) : Nil
        # QuoteHistory raises if the selected history is empty.
        @quote_history = QuoteHistory.new(
          quote_input,
          option_records,
          option_date,
        )
        @stats = Indicators.new(quote_history)
        plot if render
      end

      private def plot : Nil
        quotes = quote_history.quotes.map { |quote| quote[:close] }

        regression = quote_history.trading_days.map do |day|
          day * stats.regression_slope + stats.regression_intercept
        end
        equation = String.build do |io|
          intercept = stats.regression_intercept
          io << "y=" << stats.regression_slope.round(4) << "x"
          io << "+" unless intercept < 0
          io << intercept.round(4)
          io << ", " << I18n.t("tools.plot.relative_slope") << "="
          io << stats.regression_slope_percent.round(4)
          io << I18n.t("tools.plot.percent_per_day")
        end

        Cryplot.plot {
          title(
            I18n.t("tools.plot.title") + ": #{quote_history.isin} - " +
            quote_history.name
          ).title_font_size(14).title_text_color("blue")
          xlabel(
            "#{quote_history.date_first.to_s("%d-%m-%Y")} - " +
            quote_history.date_last.to_s("%d-%m-%Y")
          )
          ylabel(I18n.t("tools.plot.prices"))
          case position.downcase
          when "tl"
            legend.at_top_left
          when "tr"
            legend.at_top_right
          when "bl"
            legend.at_bottom_left
          when "br"
            legend.at_bottom_right
          when ""
            if stats.regression_slope < 0
              legend.at_top_right
            else
              legend.at_top_left
            end
          else
            raise LowLevelError.new(
              "invalid plot legend position '#{position}'",
              key: "tools.plot.position_invalid",
              kind: LowLevelError::Kind::UserInput,
              context: {:position => position},
              log_context: {
                :source => Core::Utils.source(__FILE__, __LINE__),
              },
            )
          end
          grid
            .show
            .back
            .line_width(1)
          border.none
          style_fill.border_show
          tics.hide
          border.left.right.top.bottom.back
          draw_curve(
            quote_history.trading_days,
            quotes,
          ).label(
            I18n.t("tools.plot.quotes") +
            " (#{quote_history.trading_days.size} " +
            I18n.t("tools.plot.trading_days") + ")"
          )
          draw_curve(
            quote_history.trading_days,
            regression,
          ).label(I18n.t("tools.plot.regression") + " (#{equation})")
          size(640, 480)
          show
          save("jedi_plot.svg")
        }
      end
    end
  end
end
