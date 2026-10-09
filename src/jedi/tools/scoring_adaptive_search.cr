module Jedi
  module Tools
    # Deterministic two-stage search over an already decoded candidate pool.
    #
    # Stage 1 deliberately spreads evaluations across discrete parameter values.
    # Stage 2 spends the remaining budget around the best Stage-1 candidates.
    # Candidate generation itself stays exhaustive and cheap; the budget limits
    # only expensive BacktestEngine evaluations.
    class ScoringAdaptiveSearch
      getter candidates : Array(ScoringCandidate)
      getter budget : Int32
      getter policy : ScoringSearchPolicy

      def initialize(
        @candidates : Array(ScoringCandidate),
        requested_budget : Int32,
        @policy : ScoringSearchPolicy = ScoringSearchPolicy.new,
      )
        @budget = requested_budget < candidates.size ? requested_budget : candidates.size
      end

      def exploration_candidates : Array(ScoringCandidate)
        return candidates.dup if budget >= candidates.size

        target = exploration_target
        selected = [] of ScoringCandidate
        seen = {} of String => Bool

        add_stratified_candidates(selected, seen, target)
        fill_evenly(selected, seen, target)
        selected
      end

      def refinement_candidates(
        exploration_results : Array(ScoringResult),
        objective : ScoringObjective,
      ) : Array(ScoringCandidate)
        remaining_count = budget - exploration_results.size
        return [] of ScoringCandidate if remaining_count <= 0

        evaluated = {} of String => Bool
        exploration_results.each do |result|
          evaluated[result.candidate.key] = true
        end

        pool = candidates.reject { |candidate| evaluated.has_key?(candidate.key) }
        return [] of ScoringCandidate if pool.empty?

        ranked = objective.sorted(exploration_results)
        elite_size = policy.elite_count
        elite_size = ranked.size if ranked.size < elite_size
        elites = ranked.first(elite_size).map(&.candidate)
        return fill_from_pool(pool, remaining_count) if elites.empty?

        ranges = feature_ranges(candidates)
        neighbor_lists = elites.map do |elite|
          pool.map do |candidate|
            {
              feature_distance(elite, candidate, ranges),
              candidate,
            }
          end.sort_by { |entry| entry[0] }
        end

        selected = [] of ScoringCandidate
        seen = {} of String => Bool
        offsets = Array(Int32).new(neighbor_lists.size, 0)

        while selected.size < remaining_count
          added = false

          neighbor_lists.each_with_index do |neighbors, elite_index|
            break if selected.size >= remaining_count

            offset = offsets[elite_index]
            while offset < neighbors.size
              candidate = neighbors[offset][1]
              offset += 1
              next if seen.has_key?(candidate.key)

              seen[candidate.key] = true
              selected << candidate
              added = true
              break
            end
            offsets[elite_index] = offset
          end

          break unless added
        end

        if selected.size < remaining_count
          pool.each do |candidate|
            break if selected.size >= remaining_count
            next if seen.has_key?(candidate.key)

            seen[candidate.key] = true
            selected << candidate
          end
        end

        selected
      end

      private def exploration_target : Int32
        target = (budget.to_f * policy.exploration_ratio).ceil.to_i
        if target < policy.minimum_exploration
          target = policy.minimum_exploration
        end
        target = budget if target > budget
        target
      end

      private def add_stratified_candidates(
        selected : Array(ScoringCandidate),
        seen : Hash(String, Bool),
        target : Int32,
      ) : Nil
        buckets = feature_buckets
        keys = buckets.keys.sort
        ordered_values = {} of String => Array(Float64)
        maximum_levels = 0

        keys.each do |key|
          values = buckets[key].keys.sort
          values = spread_values(values)
          ordered_values[key] = values
          maximum_levels = values.size if values.size > maximum_levels
        end

        level = 0
        while level < maximum_levels && selected.size < target
          keys.each do |key|
            break if selected.size >= target
            values = ordered_values[key]
            next if level >= values.size

            bucket = buckets[key][values[level]]
            if candidate = representative(bucket, seen)
              add_candidate(selected, seen, candidate)
            end
          end
          level += 1
        end
      end

      private def feature_buckets : Hash(String, Hash(Float64, Array(ScoringCandidate)))
        result = {} of String => Hash(Float64, Array(ScoringCandidate))
        feature_values = {} of String => Hash(Float64, Bool)

        candidates.each do |candidate|
          candidate.features.each do |key, value|
            if values = feature_values[key]?
              values[value] = true
            else
              feature_values[key] = {value => true}
            end
          end
        end

        feature_values.each do |key, values|
          next if values.size < 2
          next if values.size > policy.maximum_feature_levels

          result[key] = {} of Float64 => Array(ScoringCandidate)
        end

        candidates.each do |candidate|
          result.each_key do |key|
            next unless value = candidate.features[key]?

            if bucket = result[key][value]?
              bucket << candidate
            else
              result[key][value] = [candidate]
            end
          end
        end

        result
      end

      private def spread_values(values : Array(Float64)) : Array(Float64)
        result = [] of Float64
        left = 0
        right = values.size - 1

        while left <= right
          result << values[left]
          left += 1
          if left <= right
            result << values[right]
            right -= 1
          end
        end
        result
      end

      private def representative(
        values : Array(ScoringCandidate),
        seen : Hash(String, Bool),
      ) : ScoringCandidate?
        ordered = values.sort_by(&.key)
        middle = ordered.size // 2
        offset = 0

        while offset < ordered.size
          right = middle + offset
          if right < ordered.size
            candidate = ordered[right]
            return candidate unless seen.has_key?(candidate.key)
          end

          if offset > 0
            left = middle - offset
            if left >= 0
              candidate = ordered[left]
              return candidate unless seen.has_key?(candidate.key)
            end
          end
          offset += 1
        end

        nil
      end

      private def add_candidate(
        selected : Array(ScoringCandidate),
        seen : Hash(String, Bool),
        candidate : ScoringCandidate,
      ) : Nil
        return if seen.has_key?(candidate.key)

        seen[candidate.key] = true
        selected << candidate
      end

      private def fill_evenly(
        selected : Array(ScoringCandidate),
        seen : Hash(String, Bool),
        target : Int32,
      ) : Nil
        return if selected.size >= target

        ordered = candidates.sort_by(&.key)
        needed = target - selected.size
        attempts = needed * 3
        attempts = ordered.size if attempts > ordered.size

        index = 0
        while index < attempts && selected.size < target
          position = (((index.to_f + 0.5) * ordered.size.to_f) / attempts.to_f).floor.to_i
          position = ordered.size - 1 if position >= ordered.size
          add_candidate(selected, seen, ordered[position])
          index += 1
        end

        ordered.each do |candidate|
          break if selected.size >= target
          add_candidate(selected, seen, candidate)
        end
      end

      private def fill_from_pool(
        pool : Array(ScoringCandidate),
        count : Int32,
      ) : Array(ScoringCandidate)
        result = [] of ScoringCandidate
        pool.each do |candidate|
          break if result.size >= count
          result << candidate
        end
        result
      end

      private def feature_ranges(
        values : Array(ScoringCandidate),
      ) : Hash(String, Tuple(Float64, Float64))
        ranges = {} of String => Tuple(Float64, Float64)

        values.each do |candidate|
          candidate.features.each do |key, value|
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

      private def feature_distance(
        left : ScoringCandidate,
        right : ScoringCandidate,
        ranges : Hash(String, Tuple(Float64, Float64)),
      ) : Float64
        total = 0.0
        count = 0

        ranges.each do |key, range|
          next unless left_value = left.features[key]?
          next unless right_value = right.features[key]?

          width = range[1] - range[0]
          next if width.abs < 1.0e-12

          delta = (left_value - right_value) / width
          total += delta * delta
          count += 1
        end

        return 0.0 if count.zero?
        Math.sqrt(total / count.to_f)
      end
    end
  end
end
