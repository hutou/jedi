module Jedi
  module Tools
    # Economic reading of already-ranked score results. This reporter does not
    # alter the search, raw ordering or Jedi preference ranking; it only exposes
    # the quantities needed to understand whether a historically acceptable
    # fitness came from return, capital usage or sparse scale activity.
    class ScoringStudyReporter
      getter results : Array(ScoringResult)
      getter title_key : String
      getter limit : Int32?
      getter show_note : Bool

      def initialize(
        @results : Array(ScoringResult),
        @title_key : String,
        @limit : Int32? = nil,
        @show_note : Bool = true,
      )
      end

      def render : String
        visible = if count = limit
                    results.first(count < results.size ? count : results.size)
                  else
                    results
                  end

        String.build do |io|
          io << I18n.t(title_key) << '\n'
          if visible.empty?
            io << I18n.t("tools.score.study.empty") << '\n'
          else
            io << I18n.t("tools.score.study.columns") << '\n'
            visible.each_with_index do |result, index|
              io << format_row(index + 1, result) << '\n'
            end
            if show_note
              io << '\n' << I18n.t("tools.score.study.note") << '\n'
            end
          end
        end
      end

      private def format_row(rank : Int32, result : ScoringResult) : String
        performance = result.performance

        "%4d %7.3f %7s %7s %7s %6s %4s %8s %7s %5s %4s  %s" % [
          rank,
          result.fitness,
          performance_float(performance, performance.net_fitness, 3),
          performance_float(performance, performance.net_return_on_maximum_investment, 2),
          performance_float(performance, performance.net_annualized_return, 2),
          performance_float(performance, performance.scale_operations_per_year, 2),
          performance_int(performance, performance.operation_count),
          performance_money(performance, performance.maximum_investment_cents),
          performance_money(performance, performance.total_fees_cents),
          variation_rate(result.candidate),
          result.candidate.family.key,
          result.candidate.typed_builder,
        ]
      end

      # Crystal format strings are static; keep precision dispatch explicit.
      private def performance_float(
        performance : ScoringPerformance,
        value : Float64,
        precision : Int32,
      ) : String
        return "-" unless performance.known
        precision == 3 ? ("%.3f" % value) : ("%.2f" % value)
      end

      private def performance_int(
        performance : ScoringPerformance,
        value : Int32,
      ) : String
        return "-" unless performance.known
        value.to_s
      end

      private def performance_money(
        performance : ScoringPerformance,
        value : Int32,
      ) : String
        return "-" unless performance.known
        "%.0f" % (value.to_f / 100.0)
      end

      private def variation_rate(candidate : ScoringCandidate) : String
        value = candidate.features["vr"]?
        return "-" if value.nil?
        "%.1f" % (value.not_nil! * 100.0)
      end
    end
  end
end
