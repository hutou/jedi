module Jedi
  module TradingSystem
    class SettingsRepository
      def initialize(@conn_db : DB::Connection)
      end

      def insert!(
        timestamp : Time,
        state : SettingsState,
        trade_id : Int64,
        scale_id : Int64,
      ) : Int64
        exec_result = @conn_db.exec(
          "INSERT INTO settings " \
          "(rank, timestamp, split, sync, reinit, q0, c0, position, kspc, kcpc, trade_id, scale_id) " \
          "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          state.rank,
          timestamp,
          state.split.to_s,
          state.sync.to_s,
          state.reinit.to_s,
          state.q0,
          state.c0,
          state.position.to_s,
          state.kspc,
          state.kcpc,
          trade_id,
          scale_id
        )
        exec_result.last_insert_id
      end

      def update_q0_c0!(settings_id : Int64, q0 : Float64, c0 : Float64) : Nil
        @conn_db.exec(
          "UPDATE settings SET q0 = ?, c0 = ? WHERE id = ?",
          q0,
          c0,
          settings_id
        )
      end
    end
  end
end
