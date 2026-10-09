module Jedi
  module Tools
    enum PositionSizingConstraint
      Risk
      Capital
    end

    enum PositionSizingFailure
      RiskQuantityZero
      CapitalQuantityZero
      InsufficientOperability
    end

    # One theoretical move of the scale, calculated for an initial quantity
    # q0 = 1.0. Values therefore act as coefficients which can be multiplied
    # by the actual initial quantity selected by PositionSizer.
    record PositionSizingStep,
      direction : TradingRules::Direction,
      position : TradingRules::Position,
      price : Float64,
      price_coefficient : Float64,
      stock_coefficient : Float64,
      order_coefficient : Float64,
      unit_investment : Float64

    # Result of sizing one trade at its opening price.
    #
    # The upper quantity is constrained by:
    # - accepted loss at the theoretical stop;
    # - projected maximum investment down to that stop.
    #
    # The lower quantity is constrained by the rounded order quantity at
    # every position in useful_path. The trade can be opened only when this
    # lower bound does not exceed the two upper bounds.
    class PositionSizing
      getter capital : Float64
      getter risk_rate : Float64
      getter risk_amount : Float64
      getter entry_price : Float64
      getter stop_steps : Int32
      getter stop_price : Float64
      getter risk_distance : Float64
      getter maximum_quantity_by_risk : Int32
      getter maximum_quantity_by_capital : Int32
      getter maximum_quantity : Int32
      getter minimum_operable_quantity : Int32
      getter quantity : Int32
      getter initial_amount : Float64
      getter loss_at_stop : Float64
      getter maximum_projected_investment : Float64
      getter limiting_constraint : PositionSizingConstraint
      getter failure : PositionSizingFailure?
      getter risk_path : Array(PositionSizingStep)
      getter useful_path : Array(PositionSizingStep)

      def initialize(
        @capital : Float64,
        @risk_rate : Float64,
        @risk_amount : Float64,
        @entry_price : Float64,
        @stop_steps : Int32,
        @stop_price : Float64,
        @risk_distance : Float64,
        @maximum_quantity_by_risk : Int32,
        @maximum_quantity_by_capital : Int32,
        @maximum_quantity : Int32,
        @minimum_operable_quantity : Int32,
        @quantity : Int32,
        @initial_amount : Float64,
        @loss_at_stop : Float64,
        @maximum_projected_investment : Float64,
        @limiting_constraint : PositionSizingConstraint,
        @failure : PositionSizingFailure?,
        @risk_path : Array(PositionSizingStep),
        @useful_path : Array(PositionSizingStep),
      )
      end

      def operable? : Bool
        failure.nil?
      end
    end
  end
end
