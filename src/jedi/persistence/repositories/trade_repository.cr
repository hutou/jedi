module Jedi
  module TradingSystem
    class TradeRepository
      def initialize(@conn_db : DB::Connection)
      end

      def insert!(state : TradeState) : PkId
        exec_result = @conn_db.exec("INSERT INTO trade (name, money, stop, security_id) " \
                                    "VALUES(?, ?, ?, ?)",
          App.simulation.none? ? state.name.downcase.capitalize : state.name,
          state.money.to_s,
          state.stop.to_s,
          state.security_id)

        exec_result.last_insert_id
      end

      def clear_money_and_stop!(trade_id : PkId) : Nil
        @conn_db.exec("UPDATE trade SET money = NULL, stop = NULL WHERE id = ?",
          trade_id)
      end
    end
  end
end
