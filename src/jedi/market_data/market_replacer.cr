module Jedi
  module MarketData
    class MarketReplacer
      getter database : Database
      getter dataset_code : String
      getter importer : MarketImporter

      def initialize(
        @database : Database,
        @dataset_code : String,
        quotes_filename : String,
        labels_filename : String,
        dataset_name : String? = nil,
        from_date : Time? = nil,
        date_order : DateOrder? = nil,
        year_pivot : Int32 = 70,
      )
        @importer = MarketImporter.new(
          database,
          dataset_code,
          quotes_filename,
          labels_filename,
          dataset_name,
          from_date,
          date_order,
          year_pivot
        )
      end

      def run : ImportReport
        report = ImportReport.new(
          ImportOperation::Replace,
          database.filename,
          dataset_code
        )

        database.with_connection do |conn|
          conn.transaction do |tx|
            tx_conn = tx.connection
            datasets = DatasetRepository.new(tx_conn)
            datasets.fetch!(dataset_code)
            datasets.delete(dataset_code)

            importer.import_into(tx_conn, report)

            quotes = QuoteRepository.new(tx_conn)
            securities = SecurityRepository.new(tx_conn)
            report.quotes_removed = quotes.delete_unlinked
            report.securities_removed = securities.delete_orphans
          end
        end

        report
      rescue ex : LowLevelError
        enrich_error!(ex)
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot replace dataset '#{dataset_code}': " \
          "#{ex.message || ex.class.name}",
          log_context: replace_context,
          cause: ex
        )
      end

      private def replace_context : LogContext
        {
          :database_filename => database.filename,
          :market_source     => database.source,
          :market_universe   => database.universe,
          :dataset_code      => dataset_code,
        }
      end

      private def enrich_error!(ex : LowLevelError) : Nil
        replace_context.each do |key, value|
          ex.log_context[key] = value unless ex.log_context.has_key?(key)
        end
      end
    end
  end
end
