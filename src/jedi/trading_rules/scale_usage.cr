module Jedi
  module TradingRules
    # Read-only query object describing how a scale is used by trades.
    class ScaleUsage
      def initialize(@scale : Scale)
      end

      def used? : Bool
        count = scale.conn_db.scalar(
          "SELECT count(*) FROM settings WHERE scale_id = ?",
          scale.id).as(PkId)
        !count.zero?
      end

      def status : Scale::Status
        maximum = trade_ids.reduce(Scale::Status::NotUsed) do |current, trade_id|
          trade_status = status_for(TradingSystem::Trade.new(scale.conn_db, trade_id))
          current.value >= trade_status.value ? current : trade_status
        end
        maximum
      end

      private getter scale

      private def trade_ids : Array(PkId)
        sql = <<-SQL
          SELECT trade.id
          FROM settings
          JOIN trade ON trade.id = settings.trade_id
          WHERE settings.scale_id = ?
          GROUP BY trade.id
          SQL
        scale.conn_db.query_all(sql, scale.id, as: PkId)
      end

      private def status_for(trade : TradingSystem::Trade) : Scale::Status
        operations = trade.operations
        return Scale::Status::NotUsed if operations.empty?
        return Scale::Status::Used if operations.last.stock.zero?

        Scale::Status::InUse
      end
    end
  end
end
