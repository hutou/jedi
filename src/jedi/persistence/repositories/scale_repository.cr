module Jedi
  module TradingRules
    class ScaleRepository
      def initialize(@conn_db : DB::Connection)
      end

      def insert!(state : ScaleState) : PkId
        exec_result = @conn_db.exec "INSERT INTO scale (name, comment, " +
                                    "operational) VALUES(?, ?, ?)",
          state.name.downcase.capitalize,
          state.comment,
          state.opscale.to_json
        exec_result.last_insert_id
      end
    end
  end
end
