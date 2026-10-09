module Jedi
  module Tools
    struct ScoringSearchPolicy
      getter default_budget : Int32
      getter exploration_ratio : Float64
      getter minimum_exploration : Int32
      getter maximum_feature_levels : Int32
      getter elite_count : Int32
      getter influence_limit : Int32

      def initialize(
        @default_budget : Int32 = 500,
        @exploration_ratio : Float64 = 0.40,
        @minimum_exploration : Int32 = 40,
        @maximum_feature_levels : Int32 = 24,
        @elite_count : Int32 = 12,
        @influence_limit : Int32 = 8,
      )
      end
    end

    struct ScoringSearchSummary
      getter strategy : String
      getter available_candidates : Int32
      getter evaluated_candidates : Int32
      getter exploration_candidates : Int32
      getter refinement_candidates : Int32
      getter requested_budget : Int32?

      def initialize(
        @strategy : String,
        @available_candidates : Int32,
        @evaluated_candidates : Int32,
        @exploration_candidates : Int32,
        @refinement_candidates : Int32,
        @requested_budget : Int32? = nil,
      )
      end

      def adaptive? : Bool
        strategy == "adaptive"
      end

      def reduction_percent : Float64
        return 0.0 if available_candidates <= 0

        reduction = 1.0 - evaluated_candidates.to_f / available_candidates.to_f
        reduction = 0.0 if reduction < 0.0
        reduction * 100.0
      end
    end

    struct ScoringParameterImpact
      getter feature : String
      getter impact_ratio : Float64
      getter median_span : Float64
      getter distinct_values : Int32
      getter sample_count : Int32

      def initialize(
        @feature : String,
        @impact_ratio : Float64,
        @median_span : Float64,
        @distinct_values : Int32,
        @sample_count : Int32,
      )
      end
    end
  end
end
