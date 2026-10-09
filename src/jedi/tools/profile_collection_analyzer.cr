module Jedi
  module Tools
    # Applies the Jedi profile to several securities while keeping only one
    # quotation history in memory at a time.
    class ProfileCollectionAnalyzer
      getter selection : ProfileCollectionSelection
      getter policy : ProfilePolicy

      def initialize(
        @selection : ProfileCollectionSelection,
        @policy : ProfilePolicy = ProfilePolicy.new,
      )
      end

      def analyze(
        history_selection : MarketData::HistorySelection = MarketData::HistorySelection.new,
      ) : ProfileCollectionResult
        items = [] of ProfileCollectionItem
        failures = [] of ProfileCollectionFailure
        selected_count = 0

        database = MarketData::Database.new(
          selection.source,
          selection.universe,
        )

        database.with_connection do |conn|
          securities = select_securities(conn)
          selected_count = securities.size
          loader = MarketData::QuoteHistoryLoader.new(conn)
          security_repository = MarketData::SecurityRepository.new(conn)
          dataset_repository = MarketData::DatasetRepository.new(conn)
          quote_repository = loader.quote_repository
          freshness_dates = {} of String => Array(Time)?
          assess_freshness = current_history?(history_selection)

          securities.each do |security|
            begin
              history = loader.load(security.isin, history_selection)
              freshness = if assess_freshness
                            profile_freshness(
                              security,
                              history,
                              security_repository,
                              dataset_repository,
                              quote_repository,
                              freshness_dates,
                            )
                          end
              items << ProfileCollectionItem.new(
                security,
                ProfileAnalyzer.new(history, policy, freshness).analyze,
              )
            rescue ex : LowLevelError
              failures << ProfileCollectionFailure.new(
                security,
                ex.message || ex.class.name,
              )
            end
          end
        end

        ProfileCollectionResult.new(
          selection,
          selected_count,
          items,
          failures,
        )
      end

      private def current_history?(
        history_selection : MarketData::HistorySelection,
      ) : Bool
        history_selection.records.nil? && !history_selection.date_filter?
      end

      private def profile_freshness(
        security : MarketData::SecurityInfo,
        history : MarketData::QuoteHistory,
        security_repository : MarketData::SecurityRepository,
        dataset_repository : MarketData::DatasetRepository,
        quote_repository : MarketData::QuoteRepository,
        freshness_dates : Hash(String, Array(Time)?),
      ) : ProfileFreshness?
        dataset_code = freshness_dataset_code(security_repository, security)
        return nil if dataset_code.nil?

        code = dataset_code.not_nil!
        dates = if freshness_dates.has_key?(code)
                  freshness_dates[code]
                else
                  value = dataset_repository.freshness_date_last(code).try do |reference_date|
                    quote_repository.recent_trading_dates_for_dataset(
                      code,
                      reference_date,
                      policy.maximum_quote_lag_sessions + 1,
                    )
                  end
                  freshness_dates[code] = value
                  value
                end
        return nil if dates.nil?

        ProfileFreshness.from_market_dates(history.date_last, dates.not_nil!)
      end

      private def freshness_dataset_code(
        repository : MarketData::SecurityRepository,
        security : MarketData::SecurityInfo,
      ) : String?
        return selection.dataset if selection.dataset

        datasets = repository.dataset_codes(security.isin)
        datasets.size == 1 ? datasets.first : nil
      end

      private def select_securities(
        conn : DB::Connection,
      ) : Array(MarketData::SecurityInfo)
        repository = MarketData::SecurityRepository.new(conn)

        if dataset = selection.dataset
          MarketData::DatasetRepository.new(conn).fetch!(dataset)
          repository.for_dataset(dataset, selection.group)
        elsif selection.securities.empty?
          repository.all(selection.group)
        else
          select_named_securities(repository)
        end
      end

      private def select_named_securities(
        repository : MarketData::SecurityRepository,
      ) : Array(MarketData::SecurityInfo)
        securities = [] of MarketData::SecurityInfo
        seen = {} of String => Bool

        selection.securities.each do |ident|
          security = repository.fetch!(ident)
          next if seen.has_key?(security.isin)
          if group = selection.group
            next unless repository.in_group?(security.isin, group)
          end

          seen[security.isin] = true
          securities << security
        end

        securities
      end
    end
  end
end
