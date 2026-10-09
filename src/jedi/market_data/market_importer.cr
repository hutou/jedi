module Jedi
  module MarketData
    class MarketImporter
      getter database : Database
      getter dataset_code : String
      getter dataset_name : String
      getter quotes_filename : String
      getter labels_filename : String
      getter from_date : Time?
      getter date_order : DateOrder?
      getter year_pivot : Int32

      def initialize(
        @database : Database,
        @dataset_code : String,
        @quotes_filename : String,
        @labels_filename : String,
        dataset_name : String? = nil,
        @from_date : Time? = nil,
        @date_order : DateOrder? = nil,
        @year_pivot : Int32 = 70,
      )
        @dataset_name = dataset_name || dataset_code
      end

      def run : ImportReport
        report = ImportReport.new(
          ImportOperation::Import,
          database.filename,
          dataset_code
        )

        database.with_connection do |conn|
          conn.transaction do |tx|
            tx_conn = tx.connection
            datasets = DatasetRepository.new(tx_conn)

            if datasets.exists?(dataset_code)
              raise LowLevelError.new(
                "dataset '#{dataset_code}' already exists",
                log_context: {
                  :error_code   => "dataset_exists",
                  :dataset_code => dataset_code,
                }
              )
            end

            import_into(tx_conn, report)
          end
        end

        report
      rescue ex : LowLevelError
        enrich_error!(ex)
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot import dataset '#{dataset_code}': " \
          "#{ex.message || ex.class.name}",
          log_context: import_context,
          cause: ex
        )
      end

      def import_into(
        conn : DB::Connection,
        report : ImportReport,
      ) : Nil
        DatasetRepository.new(conn).insert(
          dataset_code,
          dataset_name,
          from_date,
          quotes_filename,
          labels_filename
        )

        merge_rows_into(conn, report)
        finalize_full_import(conn, report)
      end

      # Shared by full imports/replacements and non-destructive dataset updates.
      # It performs all CSV selection, OHLCV validation, duplicate detection,
      # security creation/linking and quotation insertion/linking, but does not
      # decide how dataset statistics or import metadata are finalized.
      protected def merge_rows_into(
        conn : DB::Connection,
        report : ImportReport,
      ) : Nil
        labels = read_labels(report)
        securities = SecurityRepository.new(conn)
        quotes = QuoteRepository.new(conn)

        seen_isins = {} of String => Bool
        unknown_isins = {} of String => Bool

        reader = QuotesCsvReader.new(
          quotes_filename,
          date_order: date_order,
          year_pivot: year_pivot
        )

        selector = ->(isin : String, date : Time) {
          select_quote?(
            isin,
            date,
            labels,
            unknown_isins,
            report
          )
        }

        invalid_quote_handler = ->(anomaly : QuoteAnomaly) {
          report.add_quote_anomaly(anomaly)
        }

        reader.each(selector, invalid_quote_handler) do |row|
          security = labels[row.isin]

          unless seen_isins.has_key?(row.isin)
            report.securities_read += 1
            report.securities_inserted += 1 if securities.insert_or_update(security)
            report.securities_linked += 1 if securities.link_dataset(
                                               row.isin,
                                               dataset_code
                                             )
            seen_isins[row.isin] = true
          end

          if stored = quotes.find(row.isin, row.quote[:date])
            if QuoteRepository.same?(stored, row.quote)
              report.identical_duplicates += 1
            else
              handle_conflicting_quote(row.isin, stored, row.quote, report)
              report.observe_quote(row.quote[:date])
              next
            end
          else
            quotes.insert(row.isin, row.quote)
            report.quotes_inserted += 1
          end

          if quotes.link_dataset(dataset_code, row.isin, row.quote[:date])
            report.quotes_linked += 1
          end
          report.observe_quote(row.quote[:date])
        end

        report.unknown_isins.concat(unknown_isins.keys.sort)
      end

      private def finalize_full_import(
        conn : DB::Connection,
        report : ImportReport,
      ) : Nil
        datasets = DatasetRepository.new(conn)
        securities = SecurityRepository.new(conn)
        quotes = QuoteRepository.new(conn)

        # Do not infer the final dataset contents from ExecResult#rows_affected.
        # The database itself is the source of truth, especially after
        # INSERT OR IGNORE operations.
        dataset_security_count = securities.count_for_dataset(dataset_code)
        dataset_quote_count = quotes.count_for_dataset(dataset_code)

        report.securities_linked = dataset_security_count
        report.quotes_linked = dataset_quote_count

        if dataset_quote_count == 0
          raise LowLevelError.new(
            empty_dataset_message(report),
            log_context: {
              :error_code                   => "empty_dataset",
              :dataset_code                 => dataset_code,
              :labels_read                  => report.labels_read.to_s,
              :quotes_read                  => report.quotes_read.to_s,
              :quotes_skipped_before_start  => report.quotes_skipped_before_start.to_s,
              :quotes_skipped_without_label => report.quotes_skipped_without_label.to_s,
              :quotes_skipped_invalid       => report.quotes_skipped_invalid.to_s,
              :invalid_quote_isins          => report.invalid_quote_isins.size.to_s,
              :unknown_isins                => report.unknown_isins.size.to_s,
              :history_from                 => from_date.try(&.to_s("%F")) || "none",
            }
          )
        end

        datasets.update_stats(
          dataset_code,
          dataset_security_count,
          dataset_quote_count,
          report.date_first,
          report.date_last
        )

        write_metadata(conn, report)
      end

      # Runs before OHLCV decoding. Records outside the requested period or
      # without a current label are therefore skipped without validating their
      # price fields.
      private def select_quote?(
        isin : String,
        date : Time,
        labels : Hash(String, SecurityInfo),
        unknown_isins : Hash(String, Bool),
        report : ImportReport,
      ) : Bool
        report.quotes_read += 1

        if start = from_date
          if date < start
            report.quotes_skipped_before_start += 1
            return false
          end
        end

        unless labels.has_key?(isin)
          unknown_isins[isin] = true
          report.quotes_skipped_without_label += 1
          return false
        end

        true
      end

      private def empty_dataset_message(report : ImportReport) : String
        retained = report.quotes_read -
                   report.quotes_skipped_before_start -
                   report.quotes_skipped_without_label -
                   report.quotes_skipped_invalid

        if report.quotes_read == 0
          "dataset '#{dataset_code}' contains no quotation record"
        elsif retained == 0 && report.quotes_skipped_before_start == report.quotes_read
          boundary = from_date.try(&.to_s("%F")) || "the requested date"
          "dataset '#{dataset_code}' contains no quotation on or after #{boundary}"
        elsif retained == 0 && report.quotes_skipped_without_label > 0
          "dataset '#{dataset_code}' contains no quotation matching the labels file"
        elsif retained == 0 && report.quotes_skipped_invalid > 0
          "dataset '#{dataset_code}' contains no valid OHLCV quotation"
        else
          "dataset '#{dataset_code}' contains no stored quotation"
        end
      end

      private def read_labels(report : ImportReport) : Hash(String, SecurityInfo)
        labels = {} of String => SecurityInfo

        LabelsCsvReader.new(labels_filename).each do |security|
          report.labels_read += 1
          labels[security.isin] = security
        end

        if labels.empty?
          raise LowLevelError.new(
            "labels file contains no security: #{labels_filename}",
            log_context: {
              :error_code => "empty_labels",
              :filename   => labels_filename,
            }
          )
        end

        labels
      end

      protected def handle_conflicting_quote(
        isin : String,
        stored : Quote,
        incoming : Quote,
        report : ImportReport,
      ) : Nil
        raise conflicting_quote_error(isin, stored, incoming)
      end

      private def conflicting_quote_error(
        isin : String,
        stored : Quote,
        incoming : Quote,
      ) : LowLevelError
        LowLevelError.new(
          "conflicting quotation already exists for '#{isin}' at " \
          "#{incoming[:date].to_s("%F")}",
          log_context: {
            :error_code     => "conflicting_quote",
            :dataset_code   => dataset_code,
            :isin           => isin,
            :date           => incoming[:date].to_s("%F"),
            :stored_quote   => quote_text(stored),
            :incoming_quote => quote_text(incoming),
          }
        )
      end

      protected def quote_text(quote : Quote) : String
        "O=#{quote[:open]} H=#{quote[:high]} L=#{quote[:low]} " \
        "C=#{quote[:close]} V=#{quote[:volume]}"
      end

      private def write_metadata(
        conn : DB::Connection,
        report : ImportReport,
      ) : Nil
        timestamp = Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")

        Schema.set_metadata(conn, "updated_at", timestamp)
        Schema.set_metadata(conn, "last_dataset_operation", report.operation.code)
        Schema.set_metadata(conn, "last_dataset_code", dataset_code)
      end

      private def import_context : LogContext
        context = {
          :database_filename => database.filename,
          :market_source     => database.source,
          :market_universe   => database.universe,
          :dataset_code      => dataset_code,
          :quotes_filename   => quotes_filename,
          :labels_filename   => labels_filename,
        }

        if date = from_date
          context[:history_from] = date.to_s("%F")
        end

        context
      end

      private def enrich_error!(ex : LowLevelError) : Nil
        import_context.each do |key, value|
          ex.log_context[key] = value unless ex.log_context.has_key?(key)
        end
      end
    end
  end
end
