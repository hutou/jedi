module Jedi
  module TradingSystem
    class TradeContextQueries
      def initialize(@conn_db : DB::Connection)
      end

      # =========================
      # SETTINGS
      # =========================
      def settings_sql : String
        <<-SQL
            SELECT id
            FROM settings
            WHERE trade_id = ?
            ORDER BY timestamp ASC, id ASC
            SQL
      end

      def last_settings_id(trade_id : PkId) : PkId?
        sql = <<-SQL
          SELECT id
          FROM settings
          WHERE trade_id = ?
          ORDER BY timestamp DESC, id DESC
          LIMIT 1
        SQL

        @conn_db.query_one?(sql, trade_id, as: PkId)
      end

      # =========================
      # OPERATIONS
      # =========================

      def operations_sql : String
        <<-SQL
            SELECT A.id
            FROM operation A
            JOIN settings B ON A.settings_id = B.id
            WHERE B.trade_id = ?
            ORDER BY A.timestamp ASC, A.id ASC
            SQL
      end

      def last_operation_id(trade_id : PkId) : PkId?
        sql = <<-SQL
          SELECT A.id
          FROM operation A
          JOIN settings B ON A.settings_id = B.id
          WHERE B.trade_id = ?
          ORDER BY A.timestamp DESC, A.id DESC
          LIMIT 1
        SQL

        @conn_db.query_one?(sql, trade_id, as: PkId)
      end

      # =========================
      # HELPERS (optionnel mais utile)
      # =========================

      def has_operations?(trade_id : PkId) : Bool
        sql = <<-SQL
          SELECT 1
          FROM operation A
          JOIN settings B ON A.settings_id = B.id
          WHERE B.trade_id = ?
          LIMIT 1
        SQL

        !@conn_db.query_one?(sql, trade_id, as: Int32).nil?
      end

      def operations_count(trade_id : PkId) : Int64
        sql = <<-SQL
          SELECT COUNT(*)
          FROM operation A
          JOIN settings B ON A.settings_id = B.id
          WHERE B.trade_id = ?
        SQL

        @conn_db.scalar(sql, trade_id).as(Int64)
      end
    end
  end
end
