module Jedi
  module Tools
    # Replays only the preliminary preferred candidates on contiguous temporal
    # segments. This intentionally adds a small bounded cost instead of
    # multiplying every candidate by the number of periods.
    class ScoringTemporalValidator
      getter conn_main : DB::Connection
      getter conn_memory : DB::Connection
      getter quote_history : QuoteHistory
      getter policy : ScoringPreferencePolicy

      def initialize(
        @conn_main : DB::Connection,
        @conn_memory : DB::Connection,
        @quote_history : QuoteHistory,
        @policy : ScoringPreferencePolicy = ScoringPreferencePolicy.new,
      )
      end

      def validate(
        preferences : Array(ScoringPreference),
      ) : Hash(String, ScoringTemporalMetrics)
        metrics = {} of String => ScoringTemporalMetrics
        segments = temporal_segments
        return metrics if segments.size < 2

        count = policy.temporal_candidates
        count = preferences.size if preferences.size < count

        preferences.first(count).each do |preference|
          fitness_values = [] of Float64
          operation_values = [] of Float64

          segments.each do |segment|
            history = QuoteHistory.new(
              quote_history.input,
              quote_history.security,
              segment,
            )
            simulation = evaluate(preference.result.candidate, history)
            fitness_values << simulation.gross_fitness
            operation_values << simulation.average_operations_per_month
          end

          clean_fitness = fitness_values.reject(&.nan?)
          next if clean_fitness.empty?

          median_fitness = median(clean_fitness)
          metrics[preference.result.candidate.key] = ScoringTemporalMetrics.new(
            median_fitness: median_fitness,
            worst_fitness: clean_fitness.min,
            fitness_dispersion: relative_mad(clean_fitness, median_fitness),
            operations_dispersion: mad(operation_values),
          )
        end

        metrics
      end

      private def evaluate(
        candidate : ScoringCandidate,
        history : QuoteHistory,
      ) : BacktestResult
        BacktestEngine.new(
          conn_main: conn_main,
          conn_memory: conn_memory,
          quote_history: history,
          scaledef: candidate.scaledef,
          money: nil,
          sizing_policy: FixedAmountSizingPolicy.new(App.initial_investment.to_f),
          execution_policy: BacktestExecutionPolicy.new,
        ).run
      end

      private def temporal_segments : Array(Array(MarketData::Quote))
        quotes = quote_history.quotes
        periods = policy.temporal_periods
        return [] of Array(MarketData::Quote) if periods < 2

        segment_size = quotes.size // periods
        return [] of Array(MarketData::Quote) if segment_size < policy.minimum_period_quotes

        segments = [] of Array(MarketData::Quote)
        start = 0
        period = 0
        while period < periods
          finish = period == periods - 1 ? quotes.size : start + segment_size
          segment = quotes[start, finish - start]
          segments << segment if segment.size >= policy.minimum_period_quotes
          start = finish
          period += 1
        end

        segments
      end

      private def median(values : Array(Float64)) : Float64
        sorted = values.sort
        middle = sorted.size // 2
        sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
      end

      private def mad(values : Array(Float64)) : Float64
        clean = values.reject(&.nan?)
        return Float64::INFINITY if clean.empty?

        center = median(clean)
        median(clean.map { |value| (value - center).abs })
      end

      private def relative_mad(values : Array(Float64), center : Float64) : Float64
        denominator = center.abs
        denominator = 1.0e-9 if denominator < 1.0e-9
        mad(values) / denominator
      end
    end
  end
end
