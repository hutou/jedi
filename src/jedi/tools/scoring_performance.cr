module Jedi
  module Tools
    # Economic and activity diagnostics attached to one completed scoring
    # simulation. These values are descriptive only: ScoringObjective and the
    # Jedi preference ranking deliberately continue to use their existing
    # criteria.
    struct ScoringPerformance
      getter known : Bool
      getter net_fitness : Float64
      getter net_return_on_maximum_investment : Float64
      getter net_annualized_return : Float64
      getter maximum_investment_cents : Int32
      getter total_fees_cents : Int32
      getter operation_count : Int32
      getter scale_operation_count : Int32
      getter scale_operations_per_year : Float64

      def initialize(
        @known : Bool,
        @net_fitness : Float64,
        @net_return_on_maximum_investment : Float64,
        @net_annualized_return : Float64,
        @maximum_investment_cents : Int32,
        @total_fees_cents : Int32,
        @operation_count : Int32,
        @scale_operation_count : Int32,
        @scale_operations_per_year : Float64,
      )
      end

      def self.from(result : BacktestResult) : ScoringPerformance
        scale_operations = result.operation_count - result.trade_count
        scale_operations = 0 if scale_operations < 0
        days = result.num_calendar_days
        operations_per_year = if days > 0
                                scale_operations.to_f / days.to_f * 365.0
                              else
                                0.0
                              end

        new(
          known: true,
          net_fitness: result.net_fitness,
          net_return_on_maximum_investment: result.net_return_on_maximum_investment,
          net_annualized_return: result.net_annualized_return,
          maximum_investment_cents: result.maximum_investment_cents,
          total_fees_cents: result.total_fees_cents,
          operation_count: result.operation_count,
          scale_operation_count: scale_operations,
          scale_operations_per_year: operations_per_year,
        )
      end

      def self.unknown : ScoringPerformance
        new(false, 0.0, 0.0, 0.0, 0, 0, 0, 0, 0.0)
      end
    end
  end
end
