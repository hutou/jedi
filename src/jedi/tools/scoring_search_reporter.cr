module Jedi
  module Tools
    class ScoringSearchReporter
      getter summary : ScoringSearchSummary
      getter impacts : Array(ScoringParameterImpact)

      def initialize(
        @summary : ScoringSearchSummary,
        @impacts : Array(ScoringParameterImpact),
      )
      end

      def render : String
        return "" unless summary.adaptive?

        String.build do |io|
          io << I18n.t("tools.score.search.title") << '\n'
          io << I18n.t("tools.score.search.strategy") << "adaptive\n"
          io << I18n.t("tools.score.search.available") << summary.available_candidates << '\n'
          io << I18n.t("tools.score.search.evaluated") << summary.evaluated_candidates << '\n'
          io << I18n.t("tools.score.search.exploration") << summary.exploration_candidates << '\n'
          io << I18n.t("tools.score.search.refinement") << summary.refinement_candidates << '\n'
          io << I18n.t("tools.score.search.reduction") << summary.reduction_percent.round(1) << "%\n"

          unless impacts.empty?
            io << '\n' << I18n.t("tools.score.search.influence_title") << '\n'
            io << I18n.t("tools.score.search.influence_note") << '\n'
            impacts.each do |impact|
              io << "  " << impact.feature.ljust(18)
              io << " " << (impact.impact_ratio * 100.0).round(1).to_s.rjust(6) << "%"
              io << "  Δmed=" << impact.median_span.round(4)
              io << "  n=" << impact.distinct_values
              io << '\n'
            end
          end
        end
      end
    end
  end
end
