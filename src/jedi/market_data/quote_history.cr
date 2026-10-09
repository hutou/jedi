module Jedi
  module MarketData
    # In-memory quotation history for one security.
    #
    # The class contains no file or SQL access. Loaders are responsible for
    # producing SecurityInfo and normalized Quote records.
    class QuoteHistory
      include QuoteHistoryIndicators

      getter security : SecurityInfo
      getter quotes : Array(Quote)
      getter ticker : String
      getter isin : String
      getter name : String
      getter tick : Exchange::Security::Tick
      getter trading_days : Array(Float64)
      getter num_trading_days : Int32
      getter date_first : Time
      getter date_last : Time

      def initialize(
        @security : SecurityInfo,
        quotes : Array(Quote),
      )
        if quotes.empty?
          raise LowLevelError.new(
            "quotation history is empty for '#{security.isin}'",
            log_context: {
              :error_code => "empty_history",
              :isin       => security.isin,
            }
          )
        end

        @isin = security.isin
        @ticker = security.ticker
        @name = security.name
        @quotes = quotes.sort_by { |quote| quote[:date] }

        @date_first = @quotes.first[:date]
        @date_last = @quotes.last[:date]
        @tick = Exchange::Security::Tick.new(estimate_tick)
        @trading_days = @quotes.map do |quote|
          (quote[:date] - @date_first).days.to_f
        end
        @num_trading_days = @trading_days.size
      end

      private def estimate_tick : Float64
        return Exchange::Security::Tick::VALID_TICKS.last if quotes.empty?

        prices_history = quotes.flat_map do |quote|
          [quote[:open], quote[:high], quote[:low], quote[:close]]
        end

        diffs = [] of Float64
        (1...prices_history.size).each do |index|
          diff = (prices_history[index] - prices_history[index - 1]).abs
          diffs << diff if diff > 0.0
        end

        return Exchange::Security::Tick::VALID_TICKS.last if diffs.empty?

        rounded_minimal_tick = diffs.min.round(4)
        valid_steps = Exchange::Security::Tick::VALID_TICKS.select do |step|
          step <= rounded_minimal_tick
        end

        valid_steps.empty? ? Exchange::Security::Tick::VALID_TICKS.last : valid_steps.max
      end
    end
  end
end
