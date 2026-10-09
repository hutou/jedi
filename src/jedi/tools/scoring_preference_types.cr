module Jedi
  module Tools
    struct ScoringResult
      getter isin : String
      getter candidate : ScoringCandidate
      getter fitness : Float64
      getter num_avg_oper_month : Float64
      getter maximum_investment_ratio : Float64
      getter coverage : ScoringCoverage
      getter behavior_signature : String
      getter operability : ScoringOperability
      getter activity : ScoringActivity
      getter performance : ScoringPerformance

      def initialize(
        @isin : String,
        @candidate : ScoringCandidate,
        @fitness : Float64,
        @num_avg_oper_month : Float64,
        @maximum_investment_ratio : Float64,
        @coverage : ScoringCoverage = ScoringCoverage.unknown,
        @behavior_signature : String = "",
        @operability : ScoringOperability = ScoringOperability.unknown,
        @activity : ScoringActivity = ScoringActivity.unknown,
        @performance : ScoringPerformance = ScoringPerformance.unknown,
      )
      end

      def scaledef : String
        candidate.scaledef
      end

      def scalebuild : String
        candidate.scalebuild
      end

      # The exact aggregate values complement the operation signature. This
      # prevents grouping two simulations whose operation stream happens to be
      # identical but whose final valuation differs.
      def behavior_key : String
        return "candidate:#{candidate.key}" if behavior_signature.empty?

        String.build do |io|
          io << behavior_signature << '|'
          io << fitness << '|'
          io << num_avg_oper_month << '|'
          io << maximum_investment_ratio
        end
      end

      def to_s(io : IO) : Nil
        fmt = I18n.t("tools.score.result.to_s")
        io << fmt % [
          fitness,
          num_avg_oper_month,
          maximum_investment_ratio,
          scaledef,
          "",
          scalebuild,
        ]
      end
    end

    struct ScoringTemporalMetrics
      getter median_fitness : Float64
      getter worst_fitness : Float64
      getter fitness_dispersion : Float64
      getter operations_dispersion : Float64

      def initialize(
        @median_fitness : Float64,
        @worst_fitness : Float64,
        @fitness_dispersion : Float64,
        @operations_dispersion : Float64,
      )
      end
    end

    struct ScoringPreference
      getter result : ScoringResult
      getter raw_rank : Int32
      getter equivalence_tier : Int32
      getter local_median_fitness : Float64
      getter local_fitness_dispersion : Float64
      getter boundary_centrality : Float64
      getter behavior_group_size : Int32
      getter temporal : ScoringTemporalMetrics?

      def initialize(
        @result : ScoringResult,
        @raw_rank : Int32,
        @equivalence_tier : Int32,
        @local_median_fitness : Float64,
        @local_fitness_dispersion : Float64,
        @boundary_centrality : Float64,
        @behavior_group_size : Int32 = 1,
        @temporal : ScoringTemporalMetrics? = nil,
      )
      end

      def with_temporal(value : ScoringTemporalMetrics) : ScoringPreference
        ScoringPreference.new(
          result: result,
          raw_rank: raw_rank,
          equivalence_tier: equivalence_tier,
          local_median_fitness: local_median_fitness,
          local_fitness_dispersion: local_fitness_dispersion,
          boundary_centrality: boundary_centrality,
          behavior_group_size: behavior_group_size,
          temporal: value,
        )
      end
    end
  end
end
