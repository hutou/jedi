module Jedi
  module MarketData
    class SecurityRepository
      getter conn : DB::Connection

      def initialize(@conn : DB::Connection)
      end

      def find_by_isin(isin : String) : SecurityInfo?
        query(
          <<-SQL,
            SELECT isin, ticker, name
            FROM securities
            WHERE isin = ?
          SQL
          isin
        ).first?
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error("cannot find security by ISIN '#{isin}'", ex, isin)
      end

      def find_by_ticker(ticker : String) : SecurityInfo?
        securities = query(
          <<-SQL,
            SELECT isin, ticker, name
            FROM securities
            WHERE ticker = ? COLLATE NOCASE
            ORDER BY isin
          SQL
          ticker
        )

        case securities.size
        when 0
          nil
        when 1
          securities.first
        else
          raise LowLevelError.new(
            "ticker '#{ticker}' identifies several securities",
            log_context: {
              :ticker => ticker,
              :isins  => securities.map(&.isin).join(","),
            }
          )
        end
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error("cannot find security by ticker '#{ticker}'", ex)
      end

      def find_by_isin_or_ticker(ident : String) : SecurityInfo?
        find_by_isin(ident) || find_by_ticker(ident)
      end

      def fetch!(ident : String) : SecurityInfo
        find_by_isin_or_ticker(ident) || raise LowLevelError.new(
          "security '#{ident}' not found in market database",
          log_context: {
            :error_code => "security_not_found",
            :ident      => ident,
          }
        )
      end

      def all(group_code : String? = nil) : Array(SecurityInfo)
        if code = group_code
          canonical = GroupRepository.new(conn).fetch!(code).code
          query(
            <<-SQL,
              SELECT s.isin, s.ticker, s.name
              FROM securities AS s
              INNER JOIN security_groups AS sg ON sg.isin = s.isin
              WHERE sg.group_code = ? COLLATE NOCASE
              ORDER BY s.isin
            SQL
            canonical
          )
        else
          query(
            <<-SQL
              SELECT isin, ticker, name
              FROM securities
              ORDER BY isin
            SQL
          )
        end
      rescue ex : LowLevelError
        raise ex
      rescue ex
        message = if code = group_code
                    "cannot list securities in market group '#{code}'"
                  else
                    "cannot list market securities"
                  end
        raise repository_error(message, ex)
      end

      def for_dataset(
        dataset_code : String,
        group_code : String? = nil,
      ) : Array(SecurityInfo)
        if code = group_code
          canonical = GroupRepository.new(conn).fetch!(code).code
          query(
            <<-SQL,
              SELECT s.isin, s.ticker, s.name
              FROM securities AS s
              INNER JOIN security_datasets AS sd ON sd.isin = s.isin
              INNER JOIN security_groups AS sg ON sg.isin = s.isin
              WHERE sd.dataset_code = ?
                AND sg.group_code = ? COLLATE NOCASE
              ORDER BY s.ticker COLLATE NOCASE, s.isin
            SQL
            dataset_code,
            canonical
          )
        else
          query(
            <<-SQL,
              SELECT s.isin, s.ticker, s.name
              FROM securities AS s
              INNER JOIN security_datasets AS sd ON sd.isin = s.isin
              WHERE sd.dataset_code = ?
              ORDER BY s.ticker COLLATE NOCASE, s.isin
            SQL
            dataset_code
          )
        end
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error(
          "cannot list securities for dataset '#{dataset_code}'",
          ex
        )
      end

      def list_with_datasets(
        dataset_code : String? = nil,
      ) : Array(SecurityListEntry)
        entries = [] of SecurityListEntry
        group_codes = load_group_codes

        sql = if dataset_code
                <<-SQL
                  SELECT s.isin, s.ticker, s.name, sd.dataset_code
                  FROM securities AS s
                  INNER JOIN security_datasets AS sd ON sd.isin = s.isin
                  WHERE EXISTS (
                    SELECT 1
                    FROM security_datasets AS selected
                    WHERE selected.isin = s.isin
                      AND selected.dataset_code = ?
                  )
                  ORDER BY s.ticker COLLATE NOCASE, s.isin, sd.dataset_code
                SQL
              else
                <<-SQL
                  SELECT s.isin, s.ticker, s.name, sd.dataset_code
                  FROM securities AS s
                  INNER JOIN security_datasets AS sd ON sd.isin = s.isin
                  ORDER BY s.ticker COLLATE NOCASE, s.isin, sd.dataset_code
                SQL
              end

        current_isin = nil.as(String?)
        current_ticker = ""
        current_name = ""
        datasets = [] of String

        reader = ->(rs : DB::ResultSet) do
          rs.each do
            isin = rs.read(String)
            ticker = rs.read(String)
            name = rs.read(String)
            dataset = rs.read(String)

            if previous_isin = current_isin
              if previous_isin != isin
                entries << SecurityListEntry.new(
                  previous_isin,
                  current_ticker,
                  current_name,
                  datasets,
                  group_codes[previous_isin]? || ([] of String),
                )
                datasets = [] of String
              end
            end

            current_isin = isin
            current_ticker = ticker
            current_name = name
            datasets << dataset
          end
        end

        if code = dataset_code
          conn.query(sql, code) { |rs| reader.call(rs) }
        else
          conn.query(sql) { |rs| reader.call(rs) }
        end

        if isin = current_isin
          entries << SecurityListEntry.new(
            isin,
            current_ticker,
            current_name,
            datasets,
            group_codes[isin]? || ([] of String),
          )
        end

        entries
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error(
          dataset_code ? "cannot list securities for dataset '#{dataset_code}'" : "cannot list market securities with datasets",
          ex
        )
      end

      def count : Int64
        conn.query_one("SELECT COUNT(*) FROM securities", as: Int64)
      rescue ex
        raise repository_error("cannot count market securities", ex)
      end

      def count_for_dataset(dataset_code : String) : Int64
        conn.query_one(
          <<-SQL,
            SELECT COUNT(*)
            FROM security_datasets
            WHERE dataset_code = ?
          SQL
          dataset_code,
          as: Int64
        )
      rescue ex
        raise repository_error(
          "cannot count securities for dataset '#{dataset_code}'",
          ex
        )
      end

      def insert(security : SecurityInfo) : Nil
        conn.exec(
          <<-SQL,
            INSERT INTO securities(isin, name, ticker)
            VALUES (?, ?, ?)
          SQL
          security.isin,
          security.name,
          security.ticker
        )
      rescue ex
        raise LowLevelError.new(
          "cannot insert security '#{security.isin}': " \
          "#{ex.message || ex.class.name}",
          log_context: {
            :isin   => security.isin,
            :ticker => security.ticker,
          },
          cause: ex
        )
      end

      def insert_or_update(security : SecurityInfo) : Bool
        if stored = find_by_isin(security.isin)
          if stored.name != security.name || stored.ticker != security.ticker
            conn.exec(
              <<-SQL,
                UPDATE securities
                SET name = ?, ticker = ?
                WHERE isin = ?
              SQL
              security.name,
              security.ticker,
              security.isin
            )
          end
          false
        else
          insert(security)
          true
        end
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error(
          "cannot store security '#{security.isin}'",
          ex,
          security.isin
        )
      end

      def link_dataset(isin : String, dataset_code : String) : Bool
        conn.exec(
          <<-SQL,
            INSERT OR IGNORE INTO security_datasets(dataset_code, isin)
            VALUES (?, ?)
          SQL
          dataset_code,
          isin
        ).rows_affected > 0
      rescue ex
        raise LowLevelError.new(
          "cannot link security '#{isin}' to dataset '#{dataset_code}': " \
          "#{ex.message || ex.class.name}",
          log_context: {
            :isin         => isin,
            :dataset_code => dataset_code,
          },
          cause: ex
        )
      end

      def dataset_codes(isin : String) : Array(String)
        codes = [] of String

        conn.query(
          <<-SQL,
            SELECT dataset_code
            FROM security_datasets
            WHERE isin = ?
            ORDER BY dataset_code
          SQL
          isin
        ) do |rs|
          rs.each { codes << rs.read(String) }
        end

        codes
      rescue ex
        raise repository_error(
          "cannot list datasets for security '#{isin}'",
          ex,
          isin
        )
      end

      def delete_orphans : Int64
        conn.exec(
          <<-SQL
            DELETE FROM securities
            WHERE NOT EXISTS (
              SELECT 1
              FROM security_datasets
              WHERE security_datasets.isin = securities.isin
            )
          SQL
        ).rows_affected
      rescue ex
        raise repository_error("cannot delete orphan securities", ex)
      end

      def in_group?(isin : String, group_code : String) : Bool
        GroupRepository.new(conn).member?(group_code, isin)
      end

      private def load_group_codes : Hash(String, Array(String))
        groups = {} of String => Array(String)

        conn.query(
          <<-SQL
            SELECT isin, group_code
            FROM security_groups
            ORDER BY isin, group_code COLLATE NOCASE
          SQL
        ) do |rs|
          rs.each do
            isin = rs.read(String)
            code = rs.read(String)
            codes = groups[isin]? || ([] of String)
            codes << code
            groups[isin] = codes
          end
        end

        groups
      end

      private def query(sql : String, *params) : Array(SecurityInfo)
        securities = [] of SecurityInfo

        conn.query(sql, *params) do |rs|
          rs.each do
            isin = rs.read(String)
            ticker = rs.read(String)
            name = rs.read(String)

            securities << SecurityInfo.new(
              isin: isin,
              ticker: ticker,
              name: name
            )
          end
        end

        securities
      end

      private def repository_error(
        message : String,
        cause : Exception,
        isin : String? = nil,
      ) : LowLevelError
        context = LogContext.new
        context[:isin] = isin if isin

        LowLevelError.new(
          "#{message}: #{cause.message || cause.class.name}",
          log_context: context,
          cause: cause
        )
      end
    end
  end
end
