module Jedi
  module Tools
    # Reorders only economically equivalent results. It first collapses equal
    # behavior inside each search family, measures local plateaus within that
    # family, then merges equivalent behavior across families. Terminally
    # inoperable scales and historically insufficient or overly concentrated
    # activity are rejected before those analyses; insufficiently exercised
    # outer extents are removed afterwards.
    class ScoringPreferenceAnalyzer
      alias Representative = NamedTuple(
        result: ScoringResult,
        raw_rank: Int32,
        behavior_group_size: Int32)

      getter results : Array(ScoringResult)
      getter policy : ScoringPreferencePolicy
      getter behaviorally_redundant_count : Int32
      getter insignificant_count : Int32
      getter inoperable_count : Int32
      getter inactive_count : Int32

      def initialize(
        @results : Array(ScoringResult),
        @policy : ScoringPreferencePolicy = ScoringPreferencePolicy.new,
      )
        @behaviorally_redundant_count = 0
        @insignificant_count = 0
        @inoperable_count = 0
        @inactive_count = 0
      end

      def analyze : Array(ScoringPreference)
        @behaviorally_redundant_count = 0
        @insignificant_count = 0
        @inoperable_count = 0
        @inactive_count = 0
        return [] of ScoringPreference if results.empty?

        @inoperable_count = results.count(&.operability.terminally_inoperable?)
        @inactive_count = results.count do |result|
          !result.operability.terminally_inoperable? && activity_inadmissible?(result.activity)
        end
        return [] of ScoringPreference if @inoperable_count + @inactive_count == results.size

        representatives = behavior_representatives
        admissible_count = results.size - @inoperable_count - @inactive_count
        within_family_redundant_count = admissible_count - representatives.size
        eligible = representatives.reject do |entry|
          coverage = entry[:result].coverage
          coverage.known && !coverage.significant?(policy.maximum_significant_unused)
        end

        # A very short or exceptionally quiet history may fail to exercise all
        # candidates. In that case keep the representatives rather than return
        # an empty report, but do not claim that candidates were eliminated.
        if eligible.empty?
          eligible = representatives
          @insignificant_count = 0
        else
          @insignificant_count = representatives.size - eligible.size
        end

        eligible.sort_by! { |entry| entry[:raw_rank] }
        representative_results = eligible.map { |entry| entry[:result] }
        tiers = equivalence_tiers(representative_results)
        preferences = [] of ScoringPreference

        eligible.each_with_index do |entry, index|
          result = entry[:result]
          family_results = representative_results.select do |other|
            other.candidate.family == result.candidate.family
          end
          ranges = feature_ranges(family_results)
          neighbors = nearest_neighbors(result, family_results, ranges)
          # The candidate is part of the local sample. Otherwise a weaker
          # point can be promoted merely because its closest neighbours are
          # better than it is.
          local_values = neighbors.map(&.fitness)
          local_values << result.fitness
          local_median = median(local_values)

          preferences << ScoringPreference.new(
            result: result,
            raw_rank: entry[:raw_rank],
            equivalence_tier: tiers[index],
            local_median_fitness: local_median,
            local_fitness_dispersion: relative_mad(local_values, local_median),
            boundary_centrality: boundary_centrality(result.candidate, ranges),
            behavior_group_size: entry[:behavior_group_size],
          )
        end

        collapsed = collapse_cross_family_behavior(preferences)
        cross_family_redundant_count = preferences.size - collapsed.size
        @behaviorally_redundant_count = within_family_redundant_count + cross_family_redundant_count
        rank(collapsed)
      end

      def rank(values : Array(ScoringPreference)) : Array(ScoringPreference)
        values.sort do |left, right|
          compare(left, right)
        end
      end

      private def compare(left : ScoringPreference, right : ScoringPreference) : Int32
        comparison = left.equivalence_tier <=> right.equivalence_tier
        return comparison unless comparison.zero?

        comparison = compare_temporal(left.temporal, right.temporal)
        return comparison unless comparison.zero?

        comparison = compare_activity(left.result.activity, right.result.activity)
        return comparison unless comparison.zero?

        comparison = descending(
          left.local_median_fitness,
          right.local_median_fitness,
        )
        return comparison unless comparison.zero?

        comparison = ascending(
          left.local_fitness_dispersion,
          right.local_fitness_dispersion,
        )
        return comparison unless comparison.zero?

        comparison = compare_coverage(left.result.coverage, right.result.coverage)
        return comparison unless comparison.zero?

        comparison = ascending(
          left.result.maximum_investment_ratio,
          right.result.maximum_investment_ratio,
        )
        return comparison unless comparison.zero?

        comparison = ascending(
          left.result.candidate.complexity,
          right.result.candidate.complexity,
        )
        return comparison unless comparison.zero?

        # Distance from the search-space boundary is only a tie-breaker for
        # genuinely identical raw outcomes. It must never promote a weaker
        # raw result inside an otherwise identical local plateau.
        if raw_metrics_equal?(left.result, right.result)
          comparison = descending(left.boundary_centrality, right.boundary_centrality)
          return comparison unless comparison.zero?
        end

        left.raw_rank <=> right.raw_rank
      end

      private def raw_metrics_equal?(
        left : ScoringResult,
        right : ScoringResult,
      ) : Bool
        left.fitness.round(3) == right.fitness.round(3) &&
          left.num_avg_oper_month.round(3) == right.num_avg_oper_month.round(3) &&
          left.maximum_investment_ratio.round(3) == right.maximum_investment_ratio.round(3)
      end

      private def compare_temporal(
        left : ScoringTemporalMetrics?,
        right : ScoringTemporalMetrics?,
      ) : Int32
        if left && right
          comparison = descending(left.worst_fitness, right.worst_fitness)
          return comparison unless comparison.zero?

          comparison = descending(left.median_fitness, right.median_fitness)
          return comparison unless comparison.zero?

          comparison = ascending(
            left.fitness_dispersion,
            right.fitness_dispersion,
          )
          return comparison unless comparison.zero?

          return ascending(
            left.operations_dispersion,
            right.operations_dispersion,
          )
        elsif left
          -1
        elsif right
          1
        else
          0
        end
      end

      private def compare_activity(
        left : ScoringActivity,
        right : ScoringActivity,
      ) : Int32
        left_assessable = activity_assessable?(left)
        right_assessable = activity_assessable?(right)

        if left_assessable && !right_assessable
          return -1
        elsif right_assessable && !left_assessable
          return 1
        elsif !left_assessable && !right_assessable
          return 0
        end

        comparison = ascending(left.zero_rolling_ratio, right.zero_rolling_ratio)
        return comparison unless comparison.zero?

        comparison = ascending(
          left.rolling_dispersion_ratio,
          right.rolling_dispersion_ratio,
        )
        return comparison unless comparison.zero?

        ascending(left.maximum_inactivity_ratio, right.maximum_inactivity_ratio)
      end

      private def activity_inadmissible?(activity : ScoringActivity) : Bool
        return false unless activity_assessable?(activity)

        if activity.average_operations_per_month < policy.minimum_average_operations_per_month
          return true
        end

        long_inactivity =
          activity.maximum_inactivity_months > policy.maximum_inactivity_months &&
            activity.maximum_inactivity_ratio > policy.maximum_inactivity_ratio
        return true if long_inactivity

        activity.zero_rolling_ratio > policy.maximum_zero_rolling_ratio
      end

      private def activity_assessable?(activity : ScoringActivity) : Bool
        activity.known &&
          activity.history_months >= policy.activity_rolling_months
      end

      private def compare_coverage(
        left : ScoringCoverage,
        right : ScoringCoverage,
      ) : Int32
        if left.known && !right.known
          return -1
        elsif right.known && !left.known
          return 1
        elsif !left.known && !right.known
          return 0
        end

        left_significant = left.significant?(policy.maximum_significant_unused)
        right_significant = right.significant?(policy.maximum_significant_unused)
        if left_significant && !right_significant
          return -1
        elsif right_significant && !left_significant
          return 1
        end

        comparison = left.margin_distance(policy.desired_unused_margin) <=>
                     right.margin_distance(policy.desired_unused_margin)
        return comparison unless comparison.zero?

        comparison = left.total_unused <=> right.total_unused
        return comparison unless comparison.zero?

        left.maximum_unused <=> right.maximum_unused
      end

      private def ascending(left : Float64, right : Float64) : Int32
        return 0 if left.nan? && right.nan?
        return 1 if left.nan?
        return -1 if right.nan?
        return -1 if left < right
        return 1 if left > right

        0
      end

      private def descending(left : Float64, right : Float64) : Int32
        return 0 if left.nan? && right.nan?
        return 1 if left.nan?
        return -1 if right.nan?
        return -1 if left > right
        return 1 if left < right

        0
      end

      private def behavior_representatives : Array(Representative)
        groups = {} of String => Array(Tuple(ScoringResult, Int32))
        order = [] of String

        results.each_with_index do |result, index|
          next if result.operability.terminally_inoperable?
          next if activity_inadmissible?(result.activity)

          # First collapse identical behavior only inside one search family.
          # Local robustness must be measured before equivalent candidates
          # discovered through another parameterization are merged globally.
          key = "#{result.candidate.family.key}|#{result.behavior_key}"
          unless groups.has_key?(key)
            groups[key] = [] of Tuple(ScoringResult, Int32)
            order << key
          end
          groups[key] << {result, index + 1}
        end

        representatives = [] of Representative
        order.each do |key|
          entries = groups[key]
          selected = entries.min_by do |entry|
            representative_key(entry[0], entry[1])
          end
          representatives << {
            result:              selected[0],
            raw_rank:            selected[1],
            behavior_group_size: entries.size,
          }
        end

        representatives
      end

      private def collapse_cross_family_behavior(
        values : Array(ScoringPreference),
      ) : Array(ScoringPreference)
        groups = {} of String => Array(ScoringPreference)
        order = [] of String

        values.each do |preference|
          key = preference.result.behavior_key
          unless groups.has_key?(key)
            groups[key] = [] of ScoringPreference
            order << key
          end
          groups[key] << preference
        end

        order.map do |key|
          entries = groups[key]
          selected = entries.first
          entries.each do |entry|
            selected = entry if compare(entry, selected) < 0
          end

          group_size = 0
          entries.each { |entry| group_size += entry.behavior_group_size }
          ScoringPreference.new(
            result: selected.result,
            raw_rank: selected.raw_rank,
            equivalence_tier: selected.equivalence_tier,
            local_median_fitness: selected.local_median_fitness,
            local_fitness_dispersion: selected.local_fitness_dispersion,
            boundary_centrality: selected.boundary_centrality,
            behavior_group_size: group_size,
            temporal: selected.temporal,
          )
        end
      end

      private def representative_key(
        result : ScoringResult,
        raw_rank : Int32,
      ) : Tuple(Int32, Int32, Int32, Float64, Int32)
        coverage = result.coverage
        coverage_class = if !coverage.known
                           2
                         elsif coverage.significant?(policy.maximum_significant_unused)
                           0
                         else
                           1
                         end

        {
          coverage_class,
          coverage.margin_distance(policy.desired_unused_margin),
          coverage.total_unused,
          result.candidate.complexity,
          raw_rank,
        }
      end

      private def equivalence_tiers(values : Array(ScoringResult)) : Array(Int32)
        tiers = [] of Int32
        tier = 0
        anchor = values.first

        values.each_with_index do |result, index|
          if index.zero?
            tiers << tier
            next
          end

          unless equivalent?(anchor, result)
            tier += 1
            anchor = result
          end
          tiers << tier
        end

        tiers
      end

      private def equivalent?(left : ScoringResult, right : ScoringResult) : Bool
        return false if left.fitness.nan? || right.fitness.nan?

        relative_difference(left.fitness, right.fitness) <= policy.fitness_tolerance_ratio &&
          (left.num_avg_oper_month - right.num_avg_oper_month).abs <= policy.operations_tolerance &&
          relative_difference(
            left.maximum_investment_ratio,
            right.maximum_investment_ratio,
          ) <= policy.investment_tolerance_ratio
      end

      private def relative_difference(left : Float64, right : Float64) : Float64
        denominator = left.abs
        denominator = right.abs if right.abs > denominator
        denominator = 1.0e-9 if denominator < 1.0e-9
        (left - right).abs / denominator
      end

      private def feature_ranges(
        values : Array(ScoringResult),
      ) : Hash(String, Tuple(Float64, Float64))
        ranges = {} of String => Tuple(Float64, Float64)

        values.each do |result|
          result.candidate.features.each do |key, value|
            if range = ranges[key]?
              minimum = value < range[0] ? value : range[0]
              maximum = value > range[1] ? value : range[1]
              ranges[key] = {minimum, maximum}
            else
              ranges[key] = {value, value}
            end
          end
        end

        ranges
      end

      private def nearest_neighbors(
        target : ScoringResult,
        values : Array(ScoringResult),
        ranges : Hash(String, Tuple(Float64, Float64)),
      ) : Array(ScoringResult)
        distances = [] of Tuple(Float64, ScoringResult)

        values.each do |other|
          next if other.candidate.key == target.candidate.key
          distances << {
            feature_distance(target.candidate, other.candidate, ranges),
            other,
          }
        end

        distances.sort_by! { |entry| entry[0] }
        limit = policy.neighbor_count
        limit = distances.size if distances.size < limit
        distances.first(limit).map { |entry| entry[1] }
      end

      private def feature_distance(
        left : ScoringCandidate,
        right : ScoringCandidate,
        ranges : Hash(String, Tuple(Float64, Float64)),
      ) : Float64
        sum = 0.0
        count = 0

        ranges.each do |key, range|
          left_value = left.features[key]?
          right_value = right.features[key]?
          next if left_value.nil? || right_value.nil?

          width = range[1] - range[0]
          next if width <= 0.0

          sum += ((left_value.not_nil! - right_value.not_nil!) / width).abs
          count += 1
        end

        count.zero? ? 1.0 : sum / count.to_f
      end

      private def boundary_centrality(
        candidate : ScoringCandidate,
        ranges : Hash(String, Tuple(Float64, Float64)),
      ) : Float64
        sum = 0.0
        count = 0

        candidate.features.each do |key, value|
          range = ranges[key]?
          next if range.nil?

          width = range.not_nil![1] - range.not_nil![0]
          next if width <= 0.0

          normalized = (value - range.not_nil![0]) / width
          centrality = 1.0 - 2.0 * (normalized - 0.5).abs
          centrality = 0.0 if centrality < 0.0
          sum += centrality
          count += 1
        end

        count.zero? ? 1.0 : sum / count.to_f
      end

      private def median(values : Array(Float64)) : Float64
        clean = values.reject(&.nan?).sort
        return Float64::NAN if clean.empty?

        middle = clean.size // 2
        clean.size.odd? ? clean[middle] : (clean[middle - 1] + clean[middle]) / 2.0
      end

      private def relative_mad(values : Array(Float64), center : Float64) : Float64
        return Float64::INFINITY if center.nan?

        deviations = values.reject(&.nan?).map { |value| (value - center).abs }
        mad = median(deviations)
        denominator = center.abs
        denominator = 1.0e-9 if denominator < 1.0e-9
        mad / denominator
      end
    end
  end
end
