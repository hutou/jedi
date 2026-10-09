module Jedi
  module Exchange
    class Security
      alias Fields = NamedTuple(id: PkId, isin: String,
        name: String, ticker: String, tick_buy: Float64,
        tick_sell: Float64, tax: Float64, quotation_date: Time?, quotation_website: String?,
        quotation_mode: String?, quotation_price: Float64?, quotation_variation: Float64?)

      @record : Fields? = nil
      private getter ref = ""
      getter conn_db

      def initialize(@conn_db : DB::Connection, @ident : PkId | String)
        @ref = Core::Utils.ref(@ident).upcase
      end

      def id : PkId
        record[:id]
      end

      def isin : String
        record[:isin]
      end

      def name : String
        record[:name]
      end

      def ticker : String
        record[:ticker]
      end

      def tick_buy : Tick
        Exchange::Security::Tick.new(record[:tick_buy])
      end

      def tick_sell : Tick
        Exchange::Security::Tick.new(record[:tick_sell])
      end

      def tax : Float64
        record[:tax]
      end

      def quotation_date : Time?
        (x = record[:quotation_date]).nil? ? nil : x.to_local
      end

      def quotation_website : String?
        record[:quotation_website]
      end

      def quotation_mode : String?
        record[:quotation_mode]
      end

      def quotation_price : Float64?
        record[:quotation_price]
      end

      def quotation_variation : Float64?
        record[:quotation_variation]
      end

      def record : Fields
        if cached = @record
          return cached
        end
        key = @ident.is_a?(PkId) ? "id" : "isin"
        sql = "SELECT * FROM security WHERE #{key} = ?"
        begin
          @record = @conn_db.query_one(sql, @ident, as: Fields.types)
        rescue ex
          raise LowLevelError.new(
            key: "security.query_failed",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            cause: ex)
        end
      end

      def reload! : Nil
        @record = nil
      end

      def reload!(id : PkId) : Nil
        @ident = id
        reload!
      end
    end
  end
end
