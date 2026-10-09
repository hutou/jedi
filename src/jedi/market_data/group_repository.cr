module Jedi
  module MarketData
    class GroupRepository
      getter conn : DB::Connection

      def initialize(@conn : DB::Connection)
      end

      def find(code : String) : MarketGroupInfo?
        result = nil.as(MarketGroupInfo?)

        conn.query(
          <<-SQL,
            SELECT code, reference_source, reference_date, synchronized_at
            FROM market_groups
            WHERE code = ? COLLATE NOCASE
            LIMIT 1
          SQL
          code
        ) do |rs|
          rs.each do
            result = MarketGroupInfo.new(
              code: rs.read(String),
              reference_source: rs.read(String?),
              reference_date: stored_date(rs.read(Int64?)),
              synchronized_at: rs.read(String?),
            )
          end
        end

        result
      rescue ex
        raise repository_error("cannot find market group '#{code}'", ex, code)
      end

      def fetch!(code : String) : MarketGroupInfo
        find(code) || raise LowLevelError.new(
          "market group '#{code}' not found",
          key: "market.group_not_found",
          context: {:group => code},
          log_context: {
            :error_code => "group_not_found",
            :group_code => code,
          }
        )
      end

      def all : Array(MarketGroupInfo)
        groups = [] of MarketGroupInfo

        conn.query(
          <<-SQL
            SELECT code, reference_source, reference_date, synchronized_at
            FROM market_groups
            ORDER BY code COLLATE NOCASE
          SQL
        ) do |rs|
          rs.each do
            groups << MarketGroupInfo.new(
              code: rs.read(String),
              reference_source: rs.read(String?),
              reference_date: stored_date(rs.read(Int64?)),
              synchronized_at: rs.read(String?),
            )
          end
        end

        groups
      rescue ex
        raise repository_error("cannot list market groups", ex)
      end

      def upsert(
        code : String,
        reference_source : String?,
        reference_date : Time?,
        synchronized_at : String,
      ) : String
        conn.exec(
          <<-SQL,
            INSERT INTO market_groups(
              code, reference_source, reference_date, synchronized_at
            ) VALUES (?, ?, ?, ?)
            ON CONFLICT(code) DO UPDATE SET
              reference_source = excluded.reference_source,
              reference_date = excluded.reference_date,
              synchronized_at = excluded.synchronized_at
          SQL
          code,
          reference_source,
          reference_date.try { |date| date.to_s("%Y%m%d").to_i64 },
          synchronized_at,
        )

        find(code).try(&.code) || code
      rescue ex
        raise repository_error("cannot store market group '#{code}'", ex, code)
      end

      def members(code : String) : Array(String)
        canonical = fetch!(code).code
        isins = [] of String

        conn.query(
          <<-SQL,
            SELECT isin
            FROM security_groups
            WHERE group_code = ? COLLATE NOCASE
            ORDER BY isin
          SQL
          canonical
        ) do |rs|
          rs.each { isins << rs.read(String) }
        end

        isins
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error(
          "cannot list members of market group '#{code}'",
          ex,
          code
        )
      end

      def member?(code : String, isin : String) : Bool
        fetch!(code)
        conn.query_one(
          <<-SQL,
            SELECT EXISTS(
              SELECT 1
              FROM security_groups
              WHERE group_code = ? COLLATE NOCASE AND isin = ?
            )
          SQL
          code,
          isin,
          as: Int64
        ) != 0
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error(
          "cannot test membership in market group '#{code}'",
          ex,
          code
        )
      end

      def replace_members(code : String, isins : Enumerable(String)) : Nil
        canonical = fetch!(code).code
        conn.exec(
          "DELETE FROM security_groups WHERE group_code = ? COLLATE NOCASE",
          canonical
        )
        isins.each do |isin|
          conn.exec(
            <<-SQL,
              INSERT INTO security_groups(group_code, isin)
              VALUES (?, ?)
            SQL
            canonical,
            isin
          )
        end
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error(
          "cannot replace members of market group '#{code}'",
          ex,
          code
        )
      end

      def add_member(code : String, isin : String) : Bool
        canonical = fetch!(code).code
        conn.exec(
          <<-SQL,
            INSERT OR IGNORE INTO security_groups(group_code, isin)
            VALUES (?, ?)
          SQL
          canonical,
          isin
        ).rows_affected > 0
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error(
          "cannot add '#{isin}' to market group '#{code}'",
          ex,
          code
        )
      end

      def remove_member(code : String, isin : String) : Bool
        canonical = fetch!(code).code
        conn.exec(
          <<-SQL,
            DELETE FROM security_groups
            WHERE group_code = ? COLLATE NOCASE AND isin = ?
          SQL
          canonical,
          isin
        ).rows_affected > 0
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error(
          "cannot remove '#{isin}' from market group '#{code}'",
          ex,
          code
        )
      end

      def codes_for_security(isin : String) : Array(String)
        codes = [] of String

        conn.query(
          <<-SQL,
            SELECT group_code
            FROM security_groups
            WHERE isin = ?
            ORDER BY group_code COLLATE NOCASE
          SQL
          isin
        ) do |rs|
          rs.each { codes << rs.read(String) }
        end

        codes
      rescue ex
        raise repository_error(
          "cannot list market groups for '#{isin}'",
          ex
        )
      end

      def count_members(code : String) : Int64
        canonical = fetch!(code).code
        conn.query_one(
          <<-SQL,
            SELECT COUNT(*)
            FROM security_groups
            WHERE group_code = ? COLLATE NOCASE
          SQL
          canonical,
          as: Int64
        )
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise repository_error(
          "cannot count members of market group '#{code}'",
          ex,
          code
        )
      end

      private def stored_date(value : Int64?) : Time?
        return nil unless value

        year = (value // 10_000).to_i
        month = ((value // 100) % 100).to_i
        day = (value % 100).to_i
        Time.utc(year, month, day)
      end

      private def repository_error(
        message : String,
        cause : Exception,
        code : String? = nil,
      ) : LowLevelError
        context = LogContext.new
        context[:group_code] = code if code

        LowLevelError.new(
          "#{message}: #{cause.message || cause.class.name}",
          log_context: context,
          cause: cause
        )
      end
    end
  end
end
