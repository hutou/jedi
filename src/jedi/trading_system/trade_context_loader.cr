module Jedi
  module TradingSystem
    class TradeContextLoader
      def initialize(@conn_db : DB::Connection)
      end

      def load!(trade_ident : PkId | String) : TradeContext
        trade = Trade.new(@conn_db, trade_ident)
        settings_chain = SettingsChain.new(@conn_db)
          .fetch("SELECT id FROM settings WHERE trade_id = ? ORDER BY id", trade.id)

        current_settings = settings_chain.empty? ? nil : settings_chain.last
        operations = load_operations(trade.id, current_settings)

        TradeContext.new(
          trade: trade,
          settings_chain: settings_chain,
          current_settings: current_settings,
          operations: operations,
          last_operation: operations.empty? ? nil : operations.last
        )
      end

      private def load_operations(trade_id : PkId,
                                  current_settings : Settings?) : TradingLife::Operations
        return TradingLife::Operations.new(@conn_db) if current_settings.nil?
        sql = "SELECT A.id FROM operation A " \
              "JOIN settings B ON A.settings_id = B.id " \
              "JOIN trade C ON B.trade_id = C.id " \
              "WHERE C.id = ? " \
              "ORDER BY A.timestamp ASC, A.id ASC"
        TradingLife::Operations.new(@conn_db).fetch(sql, trade_id)
      end
    end
  end
end
