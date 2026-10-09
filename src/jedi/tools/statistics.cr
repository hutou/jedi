module Jedi
  module Tools
    class Statistics
      getter quote_input : MarketData::QuoteHistoryInput

      def initialize(filename : String)
        @quote_input = MarketData::FileQuoteHistoryInput.new(filename)
      end

      def initialize(@quote_input : MarketData::QuoteHistoryInput)
      end

      def filename : String
        quote_input.description
      end

      def run(
        option_records : String? = nil,
        option_date : String? = nil,
      ) : String
        quote_history = QuoteHistory.new(
          quote_input,
          option_records,
          option_date,
        )
        indicators = Indicators.new(quote_history)

        String.build do |str|
          str << quote_history.history_years << '\n'
          str << quote_history.trading_days_per_year << '\n'
          str << quote_history.invalid_ohlc_count << '\n'
          str << quote_history.zero_volume_ratio_pct << '\n'
          str << quote_history.flat_close_ratio_pct << '\n'
          str << quote_history.median_traded_value << '\n'
          str << quote_history.low_liquidity_ratio_pct(20_000.0) << '\n'
          str << quote_history.large_gap_ratio_pct(3.0) << '\n'
          str << quote_history.isin << " - " << quote_history.name
          str << " (" << quote_history.date_first.to_s("%Y-%m-%d") << " - "
          str << quote_history.date_last.to_s("%Y-%m-%d") << ")\n"
          str << I18n.t("tools.statistics.volatility")
          str << indicators.volatility.round(4) << " "
          str << "(" << (indicators.volatility * 100).round(2) << "%)\n"
          str << I18n.t("tools.statistics.regression_slope")
          str << indicators.regression_slope.round(4) << '\n'
          str << I18n.t("tools.statistics.relative_regression_slope")
          str << indicators.regression_slope_percent.round(4) << "%\n"
          str << I18n.t("tools.statistics.regression_intercept")
          str << indicators.regression_intercept.round(4) << '\n'
          str << I18n.t("tools.statistics.correlation_coefficient")
          str << indicators.correlation_coefficient.round(4) << '\n'
          str << I18n.t("tools.statistics.determination_coefficient")
          str << indicators.determination_coefficient.round(4)
        end
      end
    end
  end
end
