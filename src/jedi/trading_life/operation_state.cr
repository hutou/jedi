module Jedi
  module TradingLife
    struct OperationState
      getter timestamp : Time
      getter type : Operation::Type
      getter mode : Operation::Mode
      getter quantity : Int32
      getter price : Float64
      getter buy : Int32
      getter sell : Int32
      getter trade_invest : Int32
      getter global_invest : Int32
      getter fees : Int32
      getter stock : Int32
      getter position : TradingRules::Position
      getter ksp : Float64
      getter kcp : Float64
      getter q0 : Float64?
      getter c0 : Float64?

      def initialize(
        @timestamp : Time,
        @type : Operation::Type,
        @mode : Operation::Mode,
        @quantity : Int32,
        @price : Float64,
        @buy : Int32,
        @sell : Int32,
        @trade_invest : Int32,
        @global_invest : Int32,
        @fees : Int32,
        @stock : Int32,
        @position : TradingRules::Position,
        @ksp : Float64,
        @kcp : Float64,
        @q0 : Float64? = nil,
        @c0 : Float64? = nil,
      )
      end
    end
  end
end
