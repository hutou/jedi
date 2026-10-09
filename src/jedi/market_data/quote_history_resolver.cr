module Jedi
  module MarketData
    # Resolves one historical quotation input without exposing its storage
    # mechanism to simulation tools.
    class QuoteHistoryResolver
      def load(
        input : QuoteHistoryInput,
        selection : HistorySelection = HistorySelection.new,
      ) : QuoteHistory
        case input
        in FileQuoteHistoryInput
          PreparedQuotesFileLoader.new(input.filename).load(selection)
        in DatabaseQuoteHistoryInput
          load_database(input, selection)
        end
      rescue ex : LowLevelError
        enrich_error!(ex, input)
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot resolve quotation history '#{input.description}': " \
          "#{ex.message || ex.class.name}",
          log_context: source_context(input),
          cause: ex,
        )
      end

      private def load_database(
        input : DatabaseQuoteHistoryInput,
        selection : HistorySelection,
      ) : QuoteHistory
        history = nil.as(QuoteHistory?)
        database = Database.new(input.source, input.universe)

        database.with_connection do |conn|
          history = QuoteHistoryLoader.new(conn).load(
            input.security,
            selection,
          )
        end

        history.not_nil!
      end

      private def enrich_error!(
        ex : LowLevelError,
        input : QuoteHistoryInput,
      ) : Nil
        source_context(input).each do |key, value|
          ex.log_context[key] = value unless ex.log_context.has_key?(key)
        end
      end

      private def source_context(
        input : QuoteHistoryInput,
      ) : Hash(Symbol, String)
        case input
        in FileQuoteHistoryInput
          {
            :history_source => "file",
            :filename       => input.filename,
          }
        in DatabaseQuoteHistoryInput
          {
            :history_source  => "database",
            :market_source   => input.source,
            :market_universe => input.universe,
            :security_ident  => input.security,
          }
        end
      end
    end
  end
end
