module Jedi
  module TradingSystem
    struct TradeStop
      enum Kind
        GP
        CL
      end

      getter operation_id : Int64
      getter kind : Kind
      getter quantity : Int32
      getter price : Float64
      getter guaranteed_gain : Float64

      def initialize(
        @operation_id : Int64,
        @kind : Kind,
        @quantity : Int32,
        @price : Float64,
        @guaranteed_gain : Float64,
      )
      end

      def self.parse(value : String?) : self?
        return nil if value.nil?
        value = value.strip
        return nil if value.empty?
        parse_value(value)
      end

      def self.parse_value(raw : String) : self
        value = raw.gsub(/\s+/, "").downcase
        parts = value.split(":")
        unless parts.size == 5
          generate_exception("Trade stop: '#{raw}' error, 2 or 5 parameters expected")
        end

        operation_id = parts[0].to_i64?
        kind = Kind.parse?(parts[1])
        quantity = parts[2].to_i?
        price = parts[3].to_f64?
        guaranteed_gain = parts[4].to_f64?

        if operation_id.nil?
          generate_exception("Trade stop: invalid operation id '#{parts[0]}'")
        end

        if kind.nil?
          generate_exception("Trade stop: invalid kind '#{parts[1]}'")
        end

        if quantity.nil?
          generate_exception("Trade stop: invalid quantity '#{parts[2]}'")
        end

        if price.nil?
          generate_exception("Trade stop: invalid price '#{parts[3]}'")
        end

        if guaranteed_gain.nil?
          generate_exception("Trade stop: invalid guaranteed gain '#{parts[4]}'")
        end

        new(
          operation_id: operation_id,
          kind: kind,
          quantity: quantity,
          price: price,
          guaranteed_gain: guaranteed_gain,
        )
      end

      def self.generate_exception(reason) : NoReturn
        raise LowLevelError.new(reason,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      def to_s(io : IO)
        io << @operation_id
        io << ":" << @kind
        io << ":" << @quantity
        io << ":" << @price
        io << ":" << @guaranteed_gain
      end

      def better_than?(other : TradeStop) : Bool
        guaranteed_gain > other.guaranteed_gain
      end
    end
  end
end
