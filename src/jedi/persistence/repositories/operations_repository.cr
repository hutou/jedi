module Jedi
  module TradingLife
    class OperationsRepository
      def initialize(@conn_db : DB::Connection)
      end

      def insert!(settings_id : Int64, state : OperationState) : Int64
        exec_result = @conn_db.exec(
          "INSERT INTO operation " \
          "(timestamp, type, mode, quantity, price, buy, sell, trade_invest, " \
          "global_invest, fees, stock, position, ksp, kcp, settings_id) " \
          "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          state.timestamp,
          state.type.to_s,
          state.mode.to_s,
          state.quantity,
          state.price,
          state.buy,
          state.sell,
          state.trade_invest,
          state.global_invest,
          state.fees,
          state.stock,
          state.position.to_s,
          state.ksp,
          state.kcp,
          settings_id
        )
        exec_result.last_insert_id
      end
    end
  end
end
