module Jedi
  module Tools
    # User-facing score output. It deliberately exposes only the three metrics
    # used by the historical ordering and the typed canonical builder.
    class ScoringCompactReporter
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
            io << I18n.t("tools.score.compact.empty") << '\n'
          else
            io << I18n.t("tools.score.compact.columns") << '\n'
            visible.each do |result|
              io << format_row(result) << '\n'
            end
          end
          if show_note
            io << '\n' << I18n.t("tools.score.compact.ratios_note") << '\n'
            io << I18n.t("tools.score.compact.activity_note") << '\n'
          end
        end
      end

      private def format_row(result : ScoringResult) : String
        "%8.3f %8.3f %8.3f  %s" % [
          result.fitness,
          result.num_avg_oper_month,
          result.maximum_investment_ratio,
          result.candidate.typed_builder,
        ]
      end
    end
  end
end
