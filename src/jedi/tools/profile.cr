module Jedi
  module Tools
    class Profile
      getter quote_input : MarketData::QuoteHistoryInput
      getter policy : ProfilePolicy

      def initialize(
        filename : String,
        @policy : ProfilePolicy = ProfilePolicy.new,
      )
        @quote_input = MarketData::FileQuoteHistoryInput.new(filename)
      end

      def initialize(
        @quote_input : MarketData::QuoteHistoryInput,
        @policy : ProfilePolicy = ProfilePolicy.new,
      )
      end

      def run(
        option_records : String? = nil,
        option_date : String? = nil,
      ) : String
        history = QuoteHistory.new(
          quote_input,
          option_records,
          option_date,
        )
        freshness = profile_freshness(history, option_records, option_date)
        profile = ProfileAnalyzer.new(history, policy, freshness).analyze
        ProfileReporter.new(
          history,
          profile,
          quote_input.description,
          policy,
        ).render
      end

      private def profile_freshness(
        history : MarketData::QuoteHistory,
        option_records : String?,
        option_date : String?,
      ) : ProfileFreshness?
        return nil unless option_records.nil? && option_date.nil?

        case input = quote_input
        in MarketData::FileQuoteHistoryInput
          nil
        in MarketData::DatabaseQuoteHistoryInput
          database = MarketData::Database.new(input.source, input.universe)
          freshness = nil.as(ProfileFreshness?)
          database.with_connection do |conn|
            security_repository = MarketData::SecurityRepository.new(conn)
            security = security_repository.fetch!(input.security)
            datasets = security_repository.dataset_codes(security.isin)
            if datasets.size == 1
              dataset = datasets.first
              reference_date = MarketData::DatasetRepository.new(conn).freshness_date_last(dataset)
              if reference_date
                dates = MarketData::QuoteRepository.new(conn).recent_trading_dates_for_dataset(
                  dataset,
                  reference_date,
                  policy.maximum_quote_lag_sessions + 1,
                )
                freshness = ProfileFreshness.from_market_dates(history.date_last, dates)
              end
            end
          end
          freshness
        end
      end
    end
  end
end
