module Jedi
  module TradingLife
    class Operation
      enum Type
        Buy  =  1
        Sell = -1
      end

      enum Mode
        Market
        Limit
        Stop
        StopLoss
      end
      #  Name and type of fields read from the operation table
      alias Fields = NamedTuple(id: PkId, timestamp: Time, type: String,
        mode: String, quantity: Int32, price: Float64, buy: Int32, sell: Int32,
        trade_invest: Int32, global_invest: Int32, fees: Int32, stock: Int32,
        position: String, ksp: Float64, kcp: Float64, settings_id: PkId)

      @record : Fields? = nil
      private getter ref = ""

      def initialize(@conn_db : DB::Connection, @ident : PkId)
      end

      def id : PkId
        record[:id]
      end

      def timestamp : Time
        record[:timestamp].to_local
      end

      def type : Type
        Type.parse(record[:type])
      end

      def mode : Mode
        Mode.parse(record[:mode])
      end

      def quantity : Int32
        record[:quantity]
      end

      def price : Float64
        record[:price]
      end

      def buy : Int32
        record[:buy]
      end

      def sell : Int32
        record[:sell]
      end

      def trade_invest : Int32
        record[:trade_invest]
      end

      def global_invest : Int32
        record[:global_invest]
      end

      def fees : Int32
        record[:fees]
      end

      def stock : Int32
        record[:stock]
      end

      def position : TradingRules::Position
        TradingRules::Position.new(record[:position])
      end

      def ksp : Float64
        record[:ksp]
      end

      def kcp : Float64
        record[:kcp]
      end

      def settings_id : PkId
        record[:settings_id]
      end

      def record : Fields
        if cached = @record
          return cached
        end
        sql = "SELECT * FROM operation WHERE id = ?"
        begin
          @record = @conn_db.query_one(sql, @ident, as: Fields.types)
        rescue ex
          @ref = Core::Utils.ref(@ident)
          raise LowLevelError.new(
            key: "operation.query_failed",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            cause: ex)
        end
      end

      def settings
        TradingSystem::Settings.new(@conn_db, settings_id)
      end

      def trade
        TradingSystem::Trade.new(@conn_db, settings.trade_id)
      end

      def scale
        TradingRules::Scale.new(@conn_db, settings.scale_id)
      end
    end
  end
end
