module Jedi
  module Tools
    class ScoringPreferenceReporter
      getter preferences : Array(ScoringPreference)
      getter policy : ScoringPreferencePolicy
      getter behaviorally_redundant_count : Int32
      getter insignificant_count : Int32
      getter inoperable_count : Int32
      getter inactive_count : Int32

      def initialize(
        @preferences : Array(ScoringPreference),
        @policy : ScoringPreferencePolicy = ScoringPreferencePolicy.new,
        @behaviorally_redundant_count : Int32 = 0,
        @insignificant_count : Int32 = 0,
        @inoperable_count : Int32 = 0,
        @inactive_count : Int32 = 0,
      )
      end

      def render : String
        String.build do |io|
          io << I18n.t("tools.score.preference.title") << '\n'
          io << I18n.t("tools.score.preference.explanation") << "\n\n"
          append_reduction_summary(io)
          io << I18n.t("tools.score.preference.columns") << '\n'

          limit = policy.output_limit
          limit = preferences.size if preferences.size < limit
          preferences.first(limit).each_with_index do |preference, index|
            io << format_row(index + 1, preference) << '\n'
          end

          unless preferences.empty?
            io << '\n'
            io << I18n.t("tools.score.preference.preferred") << '\n'
            io << preferred_reason(preferences.first) << '\n'
          end
        end
      end

      private def append_reduction_summary(io : IO) : Nil
        if inoperable_count > 0
          io << I18n.t(
            "tools.score.preference.inoperable_removed",
            {:count => inoperable_count.to_s},
          ) << '\n'
        end
        if inactive_count > 0
          io << I18n.t(
            "tools.score.preference.inactive_removed",
            {:count => inactive_count.to_s},
          ) << '\n'
        end
        if behaviorally_redundant_count > 0
          io << I18n.t(
            "tools.score.preference.redundant_removed",
            {:count => behaviorally_redundant_count.to_s},
          ) << '\n'
        end
        if insignificant_count > 0
          io << I18n.t(
            "tools.score.preference.insignificant_removed",
            {:count => insignificant_count.to_s},
          ) << '\n'
        end
        if inoperable_count > 0 || inactive_count > 0 || behaviorally_redundant_count > 0 || insignificant_count > 0
          io << '\n'
        end
      end

      private def format_row(rank : Int32, preference : ScoringPreference) : String
        result = preference.result
        temporal = preference.temporal
        temporal_median = temporal ? format_float(temporal.median_fitness) : "-"
        temporal_worst = temporal ? format_float(temporal.worst_fitness) : "-"

        "%3d %3d %3d %8.3f %7.3f %7.3f %7s %6s %6s %6s %5s %8.3f %7.3f %8s %8s %13s %5s %3d %6.2f %4s  %s" % [
          rank,
          preference.raw_rank,
          preference.equivalence_tier + 1,
          result.fitness,
          result.num_avg_oper_month,
          result.maximum_investment_ratio,
          activity_average_text(result.activity),
          activity_rolling_mean_text(result.activity),
          activity_stddev_text(result.activity),
          activity_zero_text(result.activity),
          activity_gap_text(result.activity),
          preference.local_median_fitness,
          preference.local_fitness_dispersion,
          temporal_median,
          temporal_worst,
          coverage_text(result.coverage),
          unused_text(result.coverage),
          preference.behavior_group_size,
          result.candidate.complexity,
          result.candidate.family.key,
          result.candidate.search_builder,
        ]
      end

      private def activity_average_text(activity : ScoringActivity) : String
        return "-" unless activity.known
        "%.3f" % activity.average_operations_per_month
      end

      private def activity_rolling_mean_text(activity : ScoringActivity) : String
        return "-" unless activity.known
        "%.2f" % activity.rolling_mean
      end

      private def activity_stddev_text(activity : ScoringActivity) : String
        return "-" unless activity.known
        "%.2f" % activity.rolling_stddev
      end

      private def activity_zero_text(activity : ScoringActivity) : String
        return "-" unless activity.known
        "%.0f%%" % (activity.zero_rolling_ratio * 100.0)
      end

      private def activity_gap_text(activity : ScoringActivity) : String
        return "-" unless activity.known
        activity.maximum_inactivity_months.to_s
      end

      private def coverage_text(coverage : ScoringCoverage) : String
        return "-" unless coverage.known

        "+#{coverage.positive_reached}/#{coverage.positive_available} " +
          "-#{coverage.negative_reached}/#{coverage.negative_available}"
      end

      private def unused_text(coverage : ScoringCoverage) : String
        return "-" unless coverage.known

        "#{coverage.unused_positive}/#{coverage.unused_negative}"
      end

      private def format_float(value : Float64) : String
        "%.3f" % value
      end

      private def preferred_reason(preference : ScoringPreference) : String
        reasons = [] of String
        temporal = preference.temporal
        coverage = preference.result.coverage

        if temporal
          if temporal.fitness_dispersion <= 0.10
            reasons << I18n.t("tools.score.preference.reasons.temporal_stability")
          else
            reasons << I18n.t("tools.score.preference.reasons.temporal_caution")
          end
        end

        activity = preference.result.activity
        if activity.known && activity.zero_rolling_ratio <= 0.10 &&
           activity.rolling_dispersion_ratio <= 0.50
          reasons << I18n.t("tools.score.preference.reasons.regular_activity")
        end

        if preference.local_fitness_dispersion <= 0.05
          reasons << I18n.t("tools.score.preference.reasons.local_plateau")
        end
        if coverage.known
          if coverage.margin_distance(policy.desired_unused_margin).zero?
            reasons << I18n.t("tools.score.preference.reasons.ideal_coverage")
          elsif coverage.significant?(policy.maximum_significant_unused)
            reasons << I18n.t("tools.score.preference.reasons.significant_coverage")
          end
        end
        if preference.behavior_group_size > 1
          reasons << I18n.t(
            "tools.score.preference.reasons.canonical_representative",
            {:count => preference.behavior_group_size.to_s},
          )
        end
        if preference.boundary_centrality >= 0.50
          reasons << I18n.t("tools.score.preference.reasons.central")
        end
        reasons << I18n.t("tools.score.preference.reasons.moderate_investment")

        reasons.join(" ; ")
      end
    end
  end
end
