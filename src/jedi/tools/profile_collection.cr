module Jedi
  module Tools
    class ProfileCollection
      getter selection : ProfileCollectionSelection
      getter policy : ProfilePolicy

      def initialize(
        @selection : ProfileCollectionSelection,
        @policy : ProfilePolicy = ProfilePolicy.new,
      )
      end

      def run(
        option_records : String? = nil,
        option_date : String? = nil,
        option_sort : String? = nil,
        rank_criteria : Int32 = 7,
        option_limit : Int32? = nil,
        include_rejected : Bool = false,
      ) : String
        history_selection = MarketData::HistorySelection.from_options(
          option_records,
          option_date,
        )
        result = ProfileCollectionAnalyzer.new(selection, policy).analyze(
          history_selection,
        )

        ProfileCollectionReporter.new(
          result,
          ProfileCollectionSort.parse(option_sort),
          option_limit,
          include_rejected,
          policy,
          rank_criteria,
        ).render
      end
    end
  end
end
