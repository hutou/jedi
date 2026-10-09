module Jedi
  module MarketData
    # Builds an in-memory QuoteHistory from one market database connection.
    class QuoteHistoryLoader
      getter security_repository : SecurityRepository
      getter quote_repository : QuoteRepository

      def initialize(conn : DB::Connection)
        @security_repository = SecurityRepository.new(conn)
        @quote_repository = QuoteRepository.new(conn)
      end

      def load(
        ident : String,
        selection : HistorySelection = HistorySelection.new,
      ) : QuoteHistory
        security = security_repository.fetch!(ident)
        quotes = quote_repository.history(security.isin, selection)
        QuoteHistory.new(security, quotes)
      rescue ex : LowLevelError
        ex.log_context[:ident] = ident unless ex.log_context.has_key?(:ident)
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot load quotation history for '#{ident}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:ident => ident},
          cause: ex
        )
      end
    end
  end
end
