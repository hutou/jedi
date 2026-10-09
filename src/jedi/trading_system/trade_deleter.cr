module Jedi
  module TradingSystem
    class TradeDeleter
      private getter ref = ""

      def initialize(@conn_db : DB::Connection)
      end

      def call(ident : String | PkId)
        @ref = Core::Utils.ref(ident)
        trade_id = validate_delete(ident)
        if confirm_delete?
          delete(trade_id)
          App.info(key: "trade.delete.success", params: {:ref => ref})
        else
          App.info(key: "infra.cancelled")
        end
      end

      def validate_delete(ident)
        trade = Trade.new(@conn_db, ident) # raise if not found
        unless trade.settings_chain.empty?
          raise LowLevelError.new(
            key: "trade.delete.in_use",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        trade.id
      end

      def confirm_delete?
        if App.noconfirm? ||
           App.confirm I18n.t("trade.delete.confirm",
             ref: ref), I18n.t("infra.no_chars")[0].upcase
          true
        else
          false
        end
      end

      def delete(trade_id)
        @conn_db.exec "DELETE FROM trade WHERE id=?", trade_id
      end
    end
  end
end
