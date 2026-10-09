module Jedi
  module MarketData
    class DatasetRepository
      IDENT_PATTERN              = /\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/
      FRESHNESS_COVERAGE_PERCENT = 95

      getter conn : DB::Connection

      def initialize(@conn : DB::Connection)
      end

      def find(code : String) : DatasetInfo?
        datasets = [] of DatasetInfo

        conn.query(
          <<-SQL,
            SELECT code, name, history_from
            FROM datasets
            WHERE code = ?
          SQL
          code
        ) do |rs|
          rs.each do
            stored_code = rs.read(String)
            name = rs.read(String)
            history_value = rs.read(Int64?)
            history_from = history_value.try do |value|
              QuoteRepository.date_from_i(value)
            end

            datasets << DatasetInfo.new(
              code: stored_code,
              name: name,
              history_from: history_from
            )
          end
        end

        datasets.first?
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error("cannot find dataset '#{code}'", ex, code)
      end

      def fetch!(code : String) : DatasetInfo
        find(code) || raise LowLevelError.new(
          "dataset '#{code}' not found in market database",
          log_context: {
            :error_code   => "dataset_not_found",
            :dataset_code => code,
          }
        )
      end

      def exists?(code : String) : Bool
        !find(code).nil?
      end

      # Last quotation date recorded by the most recent full dataset import.
      # Individual security updates deliberately leave this value unchanged.
      def full_import_date_last(code : String) : Time?
        value = nil.as(Time?)

        conn.query(
          <<-SQL,
            SELECT date_last
            FROM datasets
            WHERE code = ?
          SQL
          code
        ) do |rs|
          rs.each do
            stored = rs.read(Int64?)
            value = stored.try { |item| QuoteRepository.date_from_i(item) }
          end
        end

        value
      rescue ex
        raise repository_error(
          "cannot read last full-import date for dataset '#{code}'",
          ex,
          code
        )
      end

      # Quotation date reached by at least 95% of the dataset's securities.
      def freshness_date_last(code : String) : Time?
        value = conn.query_one?(
          "SELECT freshness_date_last FROM datasets WHERE code = ?",
          code,
          as: Int64?
        )
        value.try { |date| QuoteRepository.date_from_i(date) }
      rescue ex
        raise repository_error(
          "cannot read freshness date for dataset '#{code}'",
          ex,
          code
        )
      end

      def insert(
        code : String,
        name : String,
        history_from : Time?,
        quotes_filename : String,
        labels_filename : String,
      ) : Nil
        validate_code!(code)
        timestamp = Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")

        conn.exec(
          <<-SQL,
            INSERT INTO datasets(
              code, name, history_from, date_first, date_last,
              quotes_file, labels_file, imported_at,
              security_count, quote_count
            )
            VALUES (?, ?, ?, NULL, NULL, ?, ?, ?, 0, 0)
          SQL
          code,
          name,
          history_from.try { |date| QuoteRepository.date_to_i(date) },
          File.basename(quotes_filename),
          File.basename(labels_filename),
          timestamp
        )
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error("cannot insert dataset '#{code}'", ex, code)
      end

      # Updates the full-import snapshot and computes the current freshness.
      def update_stats(
        code : String,
        security_count : Int64,
        quote_count : Int64,
        date_first : Time?,
        date_last : Time?,
      ) : Nil
        result = conn.exec(
          <<-SQL,
            UPDATE datasets
            SET security_count = ?,
                quote_count = ?,
                date_first = ?,
                date_last = ?,
                freshness_date_last = ?,
                imported_at = ?
            WHERE code = ?
          SQL
          security_count,
          quote_count,
          date_first.try { |date| QuoteRepository.date_to_i(date) },
          date_last.try { |date| QuoteRepository.date_to_i(date) },
          calculate_freshness_date_last(code),
          Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ"),
          code
        )

        if result.rows_affected == 0
          raise LowLevelError.new(
            "cannot update missing dataset '#{code}'",
            log_context: {:dataset_code => code}
          )
        end
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error("cannot update dataset '#{code}'", ex, code)
      end

      # Recomputes counters and freshness from the whole dataset after an update.
      # It does not alter imported_at or the period of the last full import.
      def refresh_stats(code : String) : Nil
        security_count = conn.query_one(
          <<-SQL,
            SELECT COUNT(*)
            FROM security_datasets
            WHERE dataset_code = ?
          SQL
          code,
          as: Int64
        )

        quote_count = conn.query_one(
          <<-SQL,
            SELECT COUNT(*)
            FROM quote_datasets
            WHERE dataset_code = ?
          SQL
          code,
          as: Int64
        )

        result = conn.exec(
          <<-SQL,
            UPDATE datasets
            SET security_count = ?, quote_count = ?, freshness_date_last = ?
            WHERE code = ?
          SQL
          security_count,
          quote_count,
          calculate_freshness_date_last(code),
          code
        )

        if result.rows_affected == 0
          raise LowLevelError.new(
            "cannot refresh missing dataset '#{code}'",
            log_context: {:dataset_code => code}
          )
        end
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error(
          "cannot refresh statistics for dataset '#{code}'",
          ex,
          code
        )
      end

      def delete(code : String) : Bool
        conn.exec(
          "DELETE FROM datasets WHERE code = ?",
          code
        ).rows_affected > 0
      rescue ex
        raise repository_error("cannot delete dataset '#{code}'", ex, code)
      end

      def count : Int64
        conn.query_one("SELECT COUNT(*) FROM datasets", as: Int64)
      rescue ex
        raise repository_error("cannot count datasets", ex)
      end

      private def calculate_freshness_date_last(code : String) : Int64?
        # Sort individual last dates in ascending order and discard at most 5%
        # of the securities, using integer arithmetic. For 600 securities this
        # selects the 31st date: at least 570 securities have reached it.
        # Securities without quotations remain in the population as NULL dates;
        # if more than 5% have no quotation, no reference can be validated.
        conn.query_one(
          <<-SQL,
            WITH latest_quotes AS (
              SELECT (
                SELECT MAX(qd.date)
                FROM quote_datasets qd
                WHERE qd.dataset_code = sd.dataset_code AND qd.isin = sd.isin
              ) AS date_last
              FROM security_datasets sd
              WHERE sd.dataset_code = ?
            )
            SELECT (
              SELECT date_last
              FROM latest_quotes
              ORDER BY date_last
              LIMIT 1 OFFSET (
                SELECT COUNT(*) * #{100 - FRESHNESS_COVERAGE_PERCENT} / 100
                FROM latest_quotes
              )
            )
          SQL
          code,
          as: Int64?
        )
      end

      private def validate_code!(code : String) : Nil
        return if code.matches?(IDENT_PATTERN)

        raise LowLevelError.new(
          "invalid dataset code '#{code}'",
          log_context: {
            :field        => "dataset_code",
            :dataset_code => code,
          }
        )
      end

      private def repository_error(
        message : String,
        cause : Exception,
        code : String? = nil,
      ) : LowLevelError
        context = LogContext.new
        context[:dataset_code] = code if code

        LowLevelError.new(
          "#{message}: #{cause.message || cause.class.name}",
          log_context: context,
          cause: cause
        )
      end
    end
  end
end
