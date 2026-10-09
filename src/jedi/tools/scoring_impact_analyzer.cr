module Jedi
  module Tools
    # Descriptive sensitivity analysis over the broad exploration sample.
    #
    # This is intentionally not presented as causal importance. For each
    # discrete search feature, it compares the median primary --sort criterion
    # obtained at each tested value and expresses that span relative to the
    # overall robust span observed in the exploration sample.
    class ScoringImpactAnalyzer
      getter results : Array(ScoringResult)
      getter policy : ScoringSearchPolicy
      getter option_sort : Int32

      def initialize(
        @results : Array(ScoringResult),
        @policy : ScoringSearchPolicy = ScoringSearchPolicy.new,
        @option_sort : Int32 = 1,
      )
      end

      def analyze : Array(ScoringParameterImpact)
        valid = results.reject { |result| metric_value(result).nan? }
        return [] of ScoringParameterImpact if valid.size < 4

        metric_values = valid.map { |result| metric_value(result) }.sort
        overall_span = percentile(metric_values, 0.90) - percentile(metric_values, 0.10)
        return [] of ScoringParameterImpact if overall_span.abs < 1.0e-12

        feature_names = [] of String
        valid.each do |result|
          result.candidate.features.each_key do |key|
            feature_names << key unless feature_names.includes?(key)
          end
        end
        feature_names.sort!

        impacts = [] of ScoringParameterImpact
        feature_names.each do |feature|
          groups = {} of Float64 => Array(Float64)

          valid.each do |result|
            next unless value = result.candidate.features[feature]?

            if bucket = groups[value]?
              bucket << metric_value(result)
            else
              groups[value] = [metric_value(result)]
            end
          end

          next if groups.size < 2
          next if groups.size > policy.maximum_feature_levels

          medians = [] of Float64
          sample_count = 0
          groups.each_value do |values|
            next if values.size < 2
            medians << median(values)
            sample_count += values.size
          end
          next if medians.size < 2

          minimum = medians.min
          maximum = medians.max
          span = maximum - minimum
          ratio = span / overall_span.abs
          ratio = 1.0 if ratio > 1.0

          impacts << ScoringParameterImpact.new(
            feature,
            ratio,
            span,
            medians.size,
            sample_count,
          )
        end

        impacts.sort! do |left, right|
          if left.impact_ratio > right.impact_ratio
            -1
          elsif left.impact_ratio < right.impact_ratio
            1
          elsif left.feature < right.feature
            -1
          elsif left.feature > right.feature
            1
          else
            0
          end
        end

        limit = policy.influence_limit
        limit = impacts.size if impacts.size < limit
        impacts.first(limit)
      end

      private def metric_value(result : ScoringResult) : Float64
        case option_sort
        when 2
          result.num_avg_oper_month
        when 3
          result.maximum_investment_ratio
        else
          result.fitness
        end
      end

      private def median(values : Array(Float64)) : Float64
        sorted = values.sort
        size = sorted.size
        middle = size // 2
        if size.odd?
          sorted[middle]
        else
          (sorted[middle - 1] + sorted[middle]) / 2.0
        end
      end

      private def percentile(values : Array(Float64), ratio : Float64) : Float64
        return 0.0 if values.empty?
        return values.first if values.size == 1

        position = ratio * (values.size - 1).to_f
        lower = position.floor.to_i
        upper = position.ceil.to_i
        return values[lower] if lower == upper

        fraction = position - lower.to_f
        values[lower] + (values[upper] - values[lower]) * fraction
      end
    end
  end
end
