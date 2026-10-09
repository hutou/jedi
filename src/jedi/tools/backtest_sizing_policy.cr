require "./position_sizer"

module Jedi
  module Tools
    enum BacktestSizingMode
      FixedAmount
      Capital
    end

    # Sizing decision for one attempted trade opening.
    class BacktestSizingDecision
      getter mode : BacktestSizingMode
      getter quantity : Int32
      getter amount : Float64
      getter position_sizing : PositionSizing?

      def initialize(
        @mode : BacktestSizingMode,
        @quantity : Int32,
        @amount : Float64,
        @position_sizing : PositionSizing? = nil,
      )
      end

      def operable? : Bool
        quantity > 0
      end
    end

    record BacktestSizingEvent,
      timestamp : Time,
      decision : BacktestSizingDecision

    # Supplies the initial quantity for every trade opening. The simulation
    # engine deliberately knows nothing about the underlying sizing formula.
    abstract class BacktestSizingPolicy
      abstract def mode : BacktestSizingMode

      abstract def calculate(
        entry_price : Float64,
        scale : TradingRules::Scale::Operational,
      ) : BacktestSizingDecision
    end

    # Historical behavior: the same target amount is converted into a whole
    # number of shares at every trade opening.
    class FixedAmountSizingPolicy < BacktestSizingPolicy
      getter amount : Float64

      def initialize(@amount : Float64)
        if amount <= 0.0
          raise LowLevelError.new(
            "fixed-amount sizing requires a strictly positive amount",
            kind: LowLevelError::Kind::Technical,
            log_context: {
              :amount => amount.to_s,
              :source => Core::Utils.source(__FILE__, __LINE__),
            },
          )
        end
      end

      def mode : BacktestSizingMode
        BacktestSizingMode::FixedAmount
      end

      def calculate(
        entry_price : Float64,
        scale : TradingRules::Scale::Operational,
      ) : BacktestSizingDecision
        quantity = (amount / entry_price).floor.to_i
        if quantity <= 0
          raise LowLevelError.new(
            "initial quantity is zero for fixed-amount sizing",
            key: "tools.backtest.initial_quantity_zero",
            kind: LowLevelError::Kind::Domain,
            context: {
              :amount => amount.to_s,
              :price  => entry_price.to_s,
            } of Symbol => String,
            log_context: {
              :initial_investment => amount.to_s,
              :opening_price      => entry_price.to_s,
              :source             => Core::Utils.source(__FILE__, __LINE__),
            },
          )
        end

        BacktestSizingDecision.new(
          mode: mode,
          quantity: quantity,
          amount: quantity * entry_price,
        )
      end
    end

    # Dynamic sizing: every new trade is recalculated from its own opening
    # price. Risk and capital are upper bounds; operability is a lower bound.
    class CapitalSizingPolicy < BacktestSizingPolicy
      getter capital : Float64
      getter risk_rate : Float64
      getter stop_steps : Int32
      getter minimum_quantity : Int32
      getter operability_steps : Int32

      def initialize(
        @capital : Float64,
        @risk_rate : Float64,
        @stop_steps : Int32,
        @minimum_quantity : Int32,
        @operability_steps : Int32,
      )
      end

      def mode : BacktestSizingMode
        BacktestSizingMode::Capital
      end

      def calculate(
        entry_price : Float64,
        scale : TradingRules::Scale::Operational,
      ) : BacktestSizingDecision
        useful_directions = Array.new(
          operability_steps,
          TradingRules::Direction::UpWard,
        )

        sizing = PositionSizer.new(scale).calculate(
          capital: capital,
          risk_rate: risk_rate,
          entry_price: entry_price,
          stop_steps: stop_steps,
          minimum_quantity: minimum_quantity,
          useful_directions: useful_directions,
        )

        BacktestSizingDecision.new(
          mode: mode,
          quantity: sizing.quantity,
          amount: sizing.initial_amount,
          position_sizing: sizing,
        )
      end
    end
  end
end
