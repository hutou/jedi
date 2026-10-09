module Jedi
  module Tools
    # Single source of truth for the historical score ordering.
    #
    # Keeping this comparator outside Scoring lets the adaptive search use the
    # exact same objective as the final raw ranking without inventing a weighted
    # synthetic fitness.
    struct ScoringObjective
      getter option_sort : Int32

      def initialize(@option_sort : Int32 = 1)
      end

      def sort!(results : Array(ScoringResult)) : Nil
        results.sort! do |left, right|
          compare(left, right)
        end
      end

      def sorted(results : Array(ScoringResult)) : Array(ScoringResult)
        copy = results.dup
        sort!(copy)
        copy
      end

      def compare(left : ScoringResult, right : ScoringResult) : Int32
        case option_sort
        when 2
          comparison = descending(
            left.num_avg_oper_month.round(3),
            right.num_avg_oper_month.round(3),
          )
          return comparison unless comparison.zero?

          comparison = descending(
            left.fitness.round(3),
            right.fitness.round(3),
          )
          return comparison unless comparison.zero?

          ascending(
            left.maximum_investment_ratio.round(3),
            right.maximum_investment_ratio.round(3),
          )
        when 3
          comparison = ascending(
            left.maximum_investment_ratio.round(3),
            right.maximum_investment_ratio.round(3),
          )
          return comparison unless comparison.zero?

          comparison = descending(
            left.num_avg_oper_month.round(3),
            right.num_avg_oper_month.round(3),
          )
          return comparison unless comparison.zero?

          descending(
            left.fitness.round(3),
            right.fitness.round(3),
          )
        else
          comparison = descending(
            left.fitness.round(3),
            right.fitness.round(3),
          )
          return comparison unless comparison.zero?

          comparison = descending(
            left.num_avg_oper_month.round(3),
            right.num_avg_oper_month.round(3),
          )
          return comparison unless comparison.zero?

          ascending(
            left.maximum_investment_ratio.round(3),
            right.maximum_investment_ratio.round(3),
          )
        end
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
    end
  end
end
