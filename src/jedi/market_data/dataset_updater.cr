module Jedi
  module MarketData
    # Non-destructively merges a quotation file into an existing dataset.
    #
    # Existing ISIN/date quotations are accepted when they are equivalent within
    # the repository price tolerance. Material conflicts are reported and skipped
    # while the stored quotation is kept. New securities are created from the
    # labels file and linked to the dataset. A forbidden history gap still rolls
    # back every insertion/link made by the operation.
    class DatasetUpdater < MarketImporter
      MAX_UPDATE_GAP_DAYS = 7

      getter allow_gap : Bool

      def initialize(
        database : Database,
        dataset_code : String,
        quotes_filename : String,
        labels_filename : String,
        from_date : Time? = nil,
        date_order : DateOrder? = nil,
        year_pivot : Int32 = 70,
        @allow_gap : Bool = false,
      )
        super(
          database,
          dataset_code,
          quotes_filename,
          labels_filename,
          nil,
          from_date,
          date_order,
          year_pivot
        )
      end

      def run : ImportReport
        report = ImportReport.new(
          ImportOperation::Update,
          database.filename,
          dataset_code
        )
        report.market_source = database.source
        report.market_universe = database.universe
        report.source_filename = quotes_filename

        database.with_connection do |conn|
          conn.transaction do |tx|
            tx_conn = tx.connection
            datasets = DatasetRepository.new(tx_conn)
            quotes = QuoteRepository.new(tx_conn)

            datasets.fetch!(dataset_code)

            _, date_last_before = quotes.date_range_for_dataset(dataset_code)
            report.dataset_date_last_before = date_last_before

            merge_rows_into(tx_conn, report)
            ensure_usable_update!(report)
            validate_continuity!(quotes, date_last_before, report)

            datasets.refresh_stats(dataset_code)
            write_update_metadata(tx_conn, report)
          end
        end

        report
      rescue ex : LowLevelError
        enrich_update_error!(ex)
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot update dataset '#{dataset_code}': " \
          "#{ex.message || ex.class.name}",
          log_context: update_context,
          cause: ex
        )
      end

      protected def handle_conflicting_quote(
        isin : String,
        stored : Quote,
        incoming : Quote,
        report : ImportReport,
      ) : Nil
        conflict = QuoteConflict.new(
          isin,
          incoming[:date],
          stored,
          incoming
        )
        report.add_quote_conflict(conflict)

        App.log_warn(
          "market.conflicting_quote",
          "conflicting quotation skipped",
          {
            :dataset_code   => dataset_code,
            :isin           => isin,
            :date           => incoming[:date].to_s("%F"),
            :stored_quote   => quote_text(stored),
            :incoming_quote => quote_text(incoming),
          }
        )
      end

      private def ensure_usable_update!(report : ImportReport) : Nil
        return if report.date_first && report.date_last

        raise LowLevelError.new(
          "dataset update '#{dataset_code}' contains no usable quotation",
          log_context: {
            :error_code   => "empty_update",
            :dataset_code => dataset_code,
          }
        )
      end

      private def validate_continuity!(
        quotes : QuoteRepository,
        date_last_before : Time?,
        report : ImportReport,
      ) : Nil
        return unless previous = date_last_before

        first_extension = quotes.first_date_after(dataset_code, previous)
        report.extension_date_first = first_extension
        return unless extension = first_extension

        gap_days = (extension - previous).days.to_i32
        report.gap_days = gap_days

        return if gap_days <= MAX_UPDATE_GAP_DAYS

        if allow_gap
          report.gap_allowed = true
          return
        end

        raise LowLevelError.new(
          "dataset '#{dataset_code}' update would create a history gap of " \
          "#{gap_days} days between #{previous.to_s("%F")} and " \
          "#{extension.to_s("%F")}",
          log_context: {
            :error_code   => "dataset_gap",
            :dataset_code => dataset_code,
            :last_date    => previous.to_s("%F"),
            :first_date   => extension.to_s("%F"),
            :gap_days     => gap_days.to_s,
            :max_gap_days => MAX_UPDATE_GAP_DAYS.to_s,
          }
        )
      end

      private def write_update_metadata(
        conn : DB::Connection,
        report : ImportReport,
      ) : Nil
        timestamp = Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")

        Schema.set_metadata(conn, "updated_at", timestamp)
        Schema.set_metadata(conn, "last_dataset_operation", report.operation.code)
        Schema.set_metadata(conn, "last_dataset_code", dataset_code)
        Schema.set_metadata(conn, "last_dataset_update_at", timestamp)
        Schema.set_metadata(
          conn,
          "last_dataset_update_inserted",
          report.quotes_inserted.to_s
        )
        Schema.set_metadata(
          conn,
          "last_dataset_update_duplicates",
          report.identical_duplicates.to_s
        )
        Schema.set_metadata(
          conn,
          "last_dataset_update_conflicts",
          report.quotes_skipped_conflicting.to_s
        )
      end

      private def update_context : LogContext
        context = {
          :database_filename => database.filename,
          :market_source     => database.source,
          :market_universe   => database.universe,
          :dataset_code      => dataset_code,
          :quotes_filename   => quotes_filename,
          :labels_filename   => labels_filename,
          :allow_gap         => allow_gap.to_s,
        }

        if date = from_date
          context[:history_from] = date.to_s("%F")
        end

        context
      end

      private def enrich_update_error!(ex : LowLevelError) : Nil
        update_context.each do |key, value|
          ex.log_context[key] = value unless ex.log_context.has_key?(key)
        end
      end
    end
  end
end
