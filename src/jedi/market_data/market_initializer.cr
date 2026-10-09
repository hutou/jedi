module Jedi
  module MarketData
    class MarketInitializer
      getter database : Database

      def initialize(@database : Database)
      end

      def run : ImportReport
        database.create!
        ImportReport.new(ImportOperation::Init, database.filename)
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot initialize market database '#{database.filename}': " \
          "#{ex.message || ex.class.name}",
          log_context: database_context,
          cause: ex
        )
      end

      private def database_context : LogContext
        {
          :filename        => database.filename,
          :market_source   => database.source,
          :market_universe => database.universe,
        }
      end
    end
  end
end
