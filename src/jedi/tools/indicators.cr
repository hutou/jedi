module Jedi
  module Tools
    class Indicators
      getter quote_history : QuoteHistory
      getter volatility : Float64

      # Linear regression performed on closing prices. Since QuoteHistory uses
      # elapsed calendar days as its x-axis, the slope is expressed in price
      # units per calendar day.
      getter regression_slope : Float64
      getter regression_intercept : Float64

      # Linear regression performed on closing prices normalized by the first
      # close. The slope therefore represents a fraction of the initial price
      # per calendar day.
      getter normalized_regression_slope : Float64
      getter normalized_regression_intercept : Float64

      getter correlation_coefficient : Float64
      getter determination_coefficient : Float64

      def initialize(@quote_history : QuoteHistory)
        quotes_close = quote_history.quotes.map(&.[:close])
        @volatility = Core::Stats.volatility(quotes_close)

        @regression_slope, @regression_intercept = Core::Stats
          .linear_regression(quote_history.trading_days, quotes_close)

        first_close = quotes_close.first
        normalized_closes = if first_close.zero?
                              quotes_close.map { 0.0 }
                            else
                              quotes_close.map { |close| close / first_close }
                            end
        normalized_regression = Core::Stats.linear_regression(
          quote_history.trading_days,
          normalized_closes,
        )
        @normalized_regression_slope = normalized_regression[0]
        @normalized_regression_intercept = normalized_regression[1]

        @correlation_coefficient = Core::Stats.correlation_coefficient(
          quote_history.trading_days,
          quotes_close,
        )
        @determination_coefficient = correlation_coefficient ** 2
      end

      def normalized_regression_slope_percent : Float64
        normalized_regression_slope * 100.0
      end

      # Compatibility accessor. The former implementation multiplied the raw
      # price slope by 100, which did not represent a percentage. It now returns
      # the correctly normalized percentage of the initial price per calendar
      # day.
      def regression_slope_percent : Float64
        normalized_regression_slope_percent
      end
    end
  end
end
