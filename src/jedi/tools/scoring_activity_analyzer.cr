module Jedi
  module Tools
    # Describes how regularly a scale actually generated operations over the
    # selected quotation history. Opening buys are deliberately excluded: they
    # start a trade but do not demonstrate that the scale itself was active.
    struct ScoringActivity
      getter known : Bool
      getter scale_operation_count : Int32
      getter history_months : Int32
      getter average_operations_per_month : Float64
      getter rolling_months : Int32
      getter rolling_mean : Float64
      getter rolling_stddev : Float64
      getter rolling_dispersion_ratio : Float64
      getter zero_rolling_ratio : Float64
      getter maximum_inactivity_months : Int32
      getter maximum_inactivity_ratio : Float64

      def initialize(
        @known : Bool,
        @scale_operation_count : Int32,
        @history_months : Int32,
        @average_operations_per_month : Float64,
        @rolling_months : Int32,
        @rolling_mean : Float64,
        @rolling_stddev : Float64,
        @rolling_dispersion_ratio : Float64,
        @zero_rolling_ratio : Float64,
        @maximum_inactivity_months : Int32,
        @maximum_inactivity_ratio : Float64,
      )
      end

      def self.unknown : ScoringActivity
        new(false, 0, 0, 0.0, 0, 0.0, 0.0, 0.0, 0.0, 0, 0.0)
      end
    end

    # Builds a monthly activity series from a completed BacktestResult and then
    # observes it through a rolling window (12 months by default).
    #
    # This analyzer is descriptive only. Rejection thresholds belong to
    # ScoringPreferencePolicy / ScoringPreferenceAnalyzer so the same activity
    # measurements can later be calibrated without changing their definition.
    class ScoringActivityAnalyzer
      def self.analyze(
        result : BacktestResult,
        rolling_months : Int32 = 12,
      ) : ScoringActivity
        first_month = month_index(result.quote_history.date_first)
        last_month = month_index(result.quote_history.date_last)
        history_months = last_month - first_month + 1
        return ScoringActivity.unknown if history_months <= 0

        counts = Array(Int32).new(history_months, 0)
        seen_trades = {} of PkId => Bool
        scale_operation_count = 0

        result.operations.each do |operation|
          trade_id = operation.settings.trade.id
          unless seen_trades.has_key?(trade_id)
            # First operation of every trade is the opening transaction and is
            # not evidence that the scale generated an actionable movement.
            seen_trades[trade_id] = true
            next
          end

          index = month_index(operation.timestamp) - first_month
          next if index < 0 || index >= history_months

          counts[index] += 1
          scale_operation_count += 1
        end

        average = scale_operation_count.to_f / history_months.to_f
        window = rolling_months < history_months ? rolling_months : history_months
        rolling = rolling_counts(counts, window)
        rolling_mean = mean(rolling)
        rolling_stddev = stddev(rolling, rolling_mean)
        rolling_dispersion_ratio = if rolling_mean > 0.0
                                     rolling_stddev / rolling_mean
                                   else
                                     0.0
                                   end
        zero_rolling_ratio = if rolling.empty?
                               0.0
                             else
                               rolling.count(&.zero?).to_f / rolling.size.to_f
                             end
        maximum_inactivity = longest_zero_run(counts)
        maximum_inactivity_ratio = maximum_inactivity.to_f / history_months.to_f

        ScoringActivity.new(
          known: true,
          scale_operation_count: scale_operation_count,
          history_months: history_months,
          average_operations_per_month: average,
          rolling_months: window,
          rolling_mean: rolling_mean,
          rolling_stddev: rolling_stddev,
          rolling_dispersion_ratio: rolling_dispersion_ratio,
          zero_rolling_ratio: zero_rolling_ratio,
          maximum_inactivity_months: maximum_inactivity,
          maximum_inactivity_ratio: maximum_inactivity_ratio,
        )
      end

      private def self.month_index(value : Time) : Int32
        value.year * 12 + value.month.to_i - 1
      end

      private def self.rolling_counts(
        counts : Array(Int32),
        window : Int32,
      ) : Array(Int32)
        return [] of Int32 if counts.empty? || window <= 0

        values = [] of Int32
        sum = 0
        counts.each_with_index do |count, index|
          sum += count
          sum -= counts[index - window] if index >= window
          values << sum if index >= window - 1
        end
        values
      end

      private def self.longest_zero_run(counts : Array(Int32)) : Int32
        longest = 0
        current = 0

        counts.each do |count|
          if count.zero?
            current += 1
            longest = current if current > longest
          else
            current = 0
          end
        end

        longest
      end

      private def self.mean(values : Array(Int32)) : Float64
        return 0.0 if values.empty?
        values.sum.to_f / values.size.to_f
      end

      private def self.stddev(values : Array(Int32), average : Float64) : Float64
        return 0.0 if values.empty?

        squared_deviations = 0.0
        values.each do |value|
          delta = value.to_f - average
          squared_deviations += delta * delta
        end
        Math.sqrt(squared_deviations / values.size.to_f)
      end
    end
  end
end
