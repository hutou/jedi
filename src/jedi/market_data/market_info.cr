module Jedi
  module MarketData
    struct DatasetSummary
      getter code : String
      getter name : String
      getter history_from : Time?
      getter quotes_filename : String
      getter labels_filename : String
      getter imported_at : String
      getter security_count : Int64
      getter quote_count : Int64
      getter import_date_first : Time?
      getter import_date_last : Time?
      getter current_date_first : Time?
      getter current_date_last : Time?
      getter freshness_date_last : Time?
      getter group_counts : Hash(String, Int64)

      def initialize(
        @code : String,
        @name : String,
        @history_from : Time?,
        @quotes_filename : String,
        @labels_filename : String,
        @imported_at : String,
        @security_count : Int64,
        @quote_count : Int64,
        @import_date_first : Time?,
        @import_date_last : Time?,
        @current_date_first : Time?,
        @current_date_last : Time?,
        @freshness_date_last : Time?,
        @group_counts : Hash(String, Int64),
      )
      end
    end

    struct MarketGroupSummary
      getter code : String
      getter reference_source : String?
      getter reference_date : Time?
      getter synchronized_at : String?
      getter member_count : Int64

      def initialize(
        @code : String,
        @reference_source : String?,
        @reference_date : Time?,
        @synchronized_at : String?,
        @member_count : Int64,
      )
      end
    end

    struct MarketIntegritySummary
      getter securities_without_dataset : Int64
      getter datasets_without_security : Int64
      getter securities_without_quote : Int64
      getter quotes_without_dataset : Int64
      getter dataset_stats_mismatches : Int64
      getter foreign_key_violations : Int64

      def initialize(
        @securities_without_dataset : Int64,
        @datasets_without_security : Int64,
        @securities_without_quote : Int64,
        @quotes_without_dataset : Int64,
        @dataset_stats_mismatches : Int64,
        @foreign_key_violations : Int64,
      )
      end

      def valid? : Bool
        securities_without_dataset == 0 &&
          datasets_without_security == 0 &&
          securities_without_quote == 0 &&
          quotes_without_dataset == 0 &&
          dataset_stats_mismatches == 0 &&
          foreign_key_violations == 0
      end
    end

    struct MarketInfoReport
      getter database_filename : String
      getter source : String
      getter universe : String
      getter schema_version : Int32
      getter file_size : Int64
      getter created_at : String?
      getter updated_at : String?
      getter dataset_count : Int64
      getter security_count : Int64
      getter quote_count : Int64
      getter date_first : Time?
      getter date_last : Time?
      getter group_count : Int64
      getter groups : Array(MarketGroupSummary)
      getter datasets : Array(DatasetSummary)
      getter integrity : MarketIntegritySummary

      def initialize(
        @database_filename : String,
        @source : String,
        @universe : String,
        @schema_version : Int32,
        @file_size : Int64,
        @created_at : String?,
        @updated_at : String?,
        @dataset_count : Int64,
        @security_count : Int64,
        @quote_count : Int64,
        @date_first : Time?,
        @date_last : Time?,
        @group_count : Int64,
        @groups : Array(MarketGroupSummary),
        @datasets : Array(DatasetSummary),
        @integrity : MarketIntegritySummary,
      )
      end
    end

    class MarketInfo
      getter database : Database
      getter dataset_code : String?

      def initialize(
        @database : Database,
        @dataset_code : String? = nil,
      )
      end

      def run : MarketInfoReport
        result = nil.as(MarketInfoReport?)

        database.with_connection do |conn|
          result = build_report(conn)
        end

        result || raise LowLevelError.new(
          "cannot build market database information report",
          log_context: info_context
        )
      rescue ex : LowLevelError
        enrich_error!(ex)
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot inspect market database '#{database.filename}': " \
          "#{ex.message || ex.class.name}",
          log_context: info_context,
          cause: ex
        )
      end

      private def build_report(conn : DB::Connection) : MarketInfoReport
        metadata = load_metadata(conn)
        datasets = load_datasets(conn)

        if code = dataset_code
          if datasets.empty?
            raise LowLevelError.new(
              "dataset '#{code}' not found in market database",
              log_context: {
                :error_code   => "dataset_not_found",
                :dataset_code => code,
              }
            )
          end
        end

        date_first, date_last = global_date_range(conn)

        MarketInfoReport.new(
          database_filename: database.filename,
          source: metadata["source"]? || database.source,
          universe: metadata["universe"]? || database.universe,
          schema_version: Schema.version(conn),
          file_size: File.size(database.filename),
          created_at: metadata["created_at"]?,
          updated_at: metadata["updated_at"]?,
          dataset_count: count(conn, "SELECT COUNT(*) FROM datasets"),
          security_count: count(conn, "SELECT COUNT(*) FROM securities"),
          quote_count: count(conn, "SELECT COUNT(*) FROM quotes"),
          date_first: date_first,
          date_last: date_last,
          group_count: count(conn, "SELECT COUNT(*) FROM market_groups"),
          groups: load_groups(conn),
          datasets: datasets,
          integrity: load_integrity(conn)
        )
      end

      private def load_metadata(conn : DB::Connection) : Hash(String, String)
        metadata = {} of String => String

        conn.query("SELECT key, value FROM metadata") do |rs|
          rs.each do
            metadata[rs.read(String)] = rs.read(String)
          end
        end

        metadata
      rescue ex
        raise LowLevelError.new(
          "cannot read market database metadata: " \
          "#{ex.message || ex.class.name}",
          cause: ex
        )
      end

      private def load_datasets(conn : DB::Connection) : Array(DatasetSummary)
        datasets = [] of DatasetSummary
        sql = dataset_query(!dataset_code.nil?)
        group_counts = load_dataset_group_counts(conn)

        if code = dataset_code
          conn.query(sql, code) do |rs|
            append_datasets(rs, datasets, group_counts)
          end
        else
          conn.query(sql) do |rs|
            append_datasets(rs, datasets, group_counts)
          end
        end

        datasets
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot read market datasets: #{ex.message || ex.class.name}",
          log_context: dataset_context,
          cause: ex
        )
      end

      private def dataset_query(filtered : Bool) : String
        where = filtered ? "WHERE d.code = ?" : ""

        <<-SQL
          SELECT
            d.code,
            d.name,
            d.history_from,
            d.quotes_file,
            d.labels_file,
            d.imported_at,
            (
              SELECT COUNT(*)
              FROM security_datasets sd
              WHERE sd.dataset_code = d.code
            ),
            (
              SELECT COUNT(*)
              FROM quote_datasets qd
              WHERE qd.dataset_code = d.code
            ),
            d.date_first,
            d.date_last,
            d.freshness_date_last,
            (
              SELECT MIN(qd.date)
              FROM quote_datasets qd
              WHERE qd.dataset_code = d.code
            ),
            (
              SELECT MAX(qd.date)
              FROM quote_datasets qd
              WHERE qd.dataset_code = d.code
            )
          FROM datasets d
          #{where}
          ORDER BY d.code
        SQL
      end

      private def append_datasets(
        rs,
        datasets : Array(DatasetSummary),
        group_counts : Hash(String, Hash(String, Int64)),
      ) : Nil
        rs.each do
          code = rs.read(String)
          name = rs.read(String)
          history_from = stored_date(rs.read(Int64?))
          quotes_filename = rs.read(String)
          labels_filename = rs.read(String)
          imported_at = rs.read(String)
          security_count = rs.read(Int64)
          quote_count = rs.read(Int64)
          import_date_first = stored_date(rs.read(Int64?))
          import_date_last = stored_date(rs.read(Int64?))
          freshness_date_last = stored_date(rs.read(Int64?))
          current_date_first = stored_date(rs.read(Int64?))
          current_date_last = stored_date(rs.read(Int64?))
          datasets << DatasetSummary.new(
            code: code,
            name: name,
            history_from: history_from,
            quotes_filename: quotes_filename,
            labels_filename: labels_filename,
            imported_at: imported_at,
            security_count: security_count,
            quote_count: quote_count,
            import_date_first: import_date_first,
            import_date_last: import_date_last,
            current_date_first: current_date_first,
            current_date_last: current_date_last,
            freshness_date_last: freshness_date_last,
            group_counts: group_counts[code]? || ({} of String => Int64)
          )
        end
      end

      private def load_groups(
        conn : DB::Connection,
      ) : Array(MarketGroupSummary)
        groups = [] of MarketGroupSummary

        conn.query(
          <<-SQL
            SELECT
              g.code,
              g.reference_source,
              g.reference_date,
              g.synchronized_at,
              COUNT(sg.isin)
            FROM market_groups AS g
            LEFT JOIN security_groups AS sg ON sg.group_code = g.code
            GROUP BY
              g.code,
              g.reference_source,
              g.reference_date,
              g.synchronized_at
            ORDER BY g.code COLLATE NOCASE
          SQL
        ) do |rs|
          rs.each do
            groups << MarketGroupSummary.new(
              code: rs.read(String),
              reference_source: rs.read(String?),
              reference_date: stored_date(rs.read(Int64?)),
              synchronized_at: rs.read(String?),
              member_count: rs.read(Int64),
            )
          end
        end

        groups
      rescue ex
        raise LowLevelError.new(
          "cannot read market groups: #{ex.message || ex.class.name}",
          cause: ex
        )
      end

      private def load_dataset_group_counts(
        conn : DB::Connection,
      ) : Hash(String, Hash(String, Int64))
        counts = {} of String => Hash(String, Int64)

        conn.query(
          <<-SQL
            SELECT sd.dataset_code, sg.group_code, COUNT(*)
            FROM security_datasets AS sd
            INNER JOIN security_groups AS sg ON sg.isin = sd.isin
            GROUP BY sd.dataset_code, sg.group_code
            ORDER BY sd.dataset_code, sg.group_code COLLATE NOCASE
          SQL
        ) do |rs|
          rs.each do
            dataset = rs.read(String)
            group = rs.read(String)
            value = rs.read(Int64)
            dataset_counts = counts[dataset]? || ({} of String => Int64)
            dataset_counts[group] = value
            counts[dataset] = dataset_counts
          end
        end

        counts
      rescue ex
        raise LowLevelError.new(
          "cannot count market groups by dataset: " \
          "#{ex.message || ex.class.name}",
          cause: ex
        )
      end

      private def global_date_range(
        conn : DB::Connection,
      ) : Tuple(Time?, Time?)
        first = nil.as(Time?)
        last = nil.as(Time?)

        conn.query("SELECT MIN(date), MAX(date) FROM quotes") do |rs|
          rs.each do
            first = stored_date(rs.read(Int64?))
            last = stored_date(rs.read(Int64?))
          end
        end

        {first, last}
      rescue ex
        raise LowLevelError.new(
          "cannot read market quotation period: " \
          "#{ex.message || ex.class.name}",
          cause: ex
        )
      end

      private def load_integrity(conn : DB::Connection) : MarketIntegritySummary
        MarketIntegritySummary.new(
          securities_without_dataset: count(
            conn,
            <<-SQL
              SELECT COUNT(*)
              FROM securities s
              WHERE NOT EXISTS (
                SELECT 1
                FROM security_datasets sd
                WHERE sd.isin = s.isin
              )
            SQL
          ),
          datasets_without_security: count(
            conn,
            <<-SQL
              SELECT COUNT(*)
              FROM datasets d
              WHERE NOT EXISTS (
                SELECT 1
                FROM security_datasets sd
                WHERE sd.dataset_code = d.code
              )
            SQL
          ),
          securities_without_quote: count(
            conn,
            <<-SQL
              SELECT COUNT(*)
              FROM securities s
              WHERE NOT EXISTS (
                SELECT 1
                FROM quotes q
                WHERE q.isin = s.isin
              )
            SQL
          ),
          quotes_without_dataset: count(
            conn,
            <<-SQL
              SELECT COUNT(*)
              FROM quotes q
              WHERE NOT EXISTS (
                SELECT 1
                FROM quote_datasets qd
                WHERE qd.isin = q.isin
                  AND qd.date = q.date
              )
            SQL
          ),
          dataset_stats_mismatches: count(
            conn,
            <<-SQL
              SELECT COUNT(*)
              FROM datasets d
              WHERE d.security_count != (
                SELECT COUNT(*)
                FROM security_datasets sd
                WHERE sd.dataset_code = d.code
              )
                 OR d.quote_count != (
                SELECT COUNT(*)
                FROM quote_datasets qd
                WHERE qd.dataset_code = d.code
              )
            SQL
          ),
          foreign_key_violations: foreign_key_violation_count(conn)
        )
      end

      private def count(conn : DB::Connection, sql : String) : Int64
        conn.query_one(sql, as: Int64)
      rescue ex
        raise LowLevelError.new(
          "cannot execute market database count: " \
          "#{ex.message || ex.class.name}",
          cause: ex
        )
      end

      private def foreign_key_violation_count(conn : DB::Connection) : Int64
        violations = 0_i64

        conn.query("PRAGMA foreign_key_check") do |rs|
          rs.each do
            rs.read(String)
            rs.read(Int64?)
            rs.read(String)
            rs.read(Int64)
            violations += 1
          end
        end

        violations
      rescue ex
        raise LowLevelError.new(
          "cannot check market database foreign keys: " \
          "#{ex.message || ex.class.name}",
          cause: ex
        )
      end

      private def stored_date(value : Int64?) : Time?
        value.try { |date| QuoteRepository.date_from_i(date) }
      end

      private def dataset_context : LogContext
        context = LogContext.new
        if code = dataset_code
          context[:dataset_code] = code
        end
        context
      end

      private def info_context : LogContext
        context = {
          :database_filename => database.filename,
          :market_source     => database.source,
          :market_universe   => database.universe,
        }
        if code = dataset_code
          context[:dataset_code] = code
        end
        context
      end

      private def enrich_error!(ex : LowLevelError) : Nil
        info_context.each do |key, value|
          ex.log_context[key] = value unless ex.log_context.has_key?(key)
        end
      end
    end
  end
end
