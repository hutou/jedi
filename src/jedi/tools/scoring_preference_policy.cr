module Jedi
  module Tools
    # Explicit and intentionally small policy for the robust Jedi ranking.
    # Thresholds are centralized here so they can be calibrated on real
    # securities without changing the analysis algorithm.
    struct ScoringPreferencePolicy
      getter fitness_tolerance_ratio : Float64
      getter operations_tolerance : Float64
      getter investment_tolerance_ratio : Float64
      getter neighbor_count : Int32
      getter temporal_periods : Int32
      getter temporal_candidates : Int32
      getter minimum_period_quotes : Int32
      getter output_limit : Int32
      getter desired_unused_margin : Int32
      getter maximum_significant_unused : Int32
      getter minimum_order_quantity : Int32
      getter activity_rolling_months : Int32
      getter minimum_average_operations_per_month : Float64
      getter maximum_inactivity_months : Int32
      getter maximum_inactivity_ratio : Float64
      getter maximum_zero_rolling_ratio : Float64

      def initialize(
        @fitness_tolerance_ratio : Float64 = 0.02,
        @operations_tolerance : Float64 = 0.10,
        @investment_tolerance_ratio : Float64 = 0.05,
        @neighbor_count : Int32 = 8,
        @temporal_periods : Int32 = 3,
        @temporal_candidates : Int32 = 20,
        @minimum_period_quotes : Int32 = 120,
        @output_limit : Int32 = 20,
        @desired_unused_margin : Int32 = 1,
        @maximum_significant_unused : Int32 = 2,
        @minimum_order_quantity : Int32 = 2,
        @activity_rolling_months : Int32 = 12,
        @minimum_average_operations_per_month : Float64 = 0.10,
        @maximum_inactivity_months : Int32 = 24,
        @maximum_inactivity_ratio : Float64 = 0.30,
        @maximum_zero_rolling_ratio : Float64 = 0.50,
      )
      end
    end
  end
end
