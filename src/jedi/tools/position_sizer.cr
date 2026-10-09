require "./position_sizing"

module Jedi
  module Tools
    # Pure trade-sizing service. It does not write to the Jedi database and
    # does not depend on a quotation source.
    #
    # Every calculation starts at position 0:0:0, with q0 = 1.0 and c0 equal
    # to the proposed opening price. TradingRules::Coefficient is then used to
    # follow the real type-I or type-II scale calculations.
    class PositionSizer
      getter scale : TradingRules::Scale::Operational

      private record ProjectionState,
        position : TradingRules::Position,
        price : Float64,
        stock_coefficient : Float64,
        kcp : Float64,
        unit_investment : Float64

      def initialize(@scale : TradingRules::Scale::Operational)
      end

      # useful_directions describes every useful scale position which must
      # remain operable before the next recentering/reset. It is deliberately
      # supplied by the caller: PositionSizer must not replace that business
      # horizon with one arbitrary level, a fixed number of steps, or the
      # maximum quotation of the whole historical file.
      def calculate(
        *,
        capital : Float64,
        risk_rate : Float64,
        entry_price : Float64,
        stop_steps : Int32,
        minimum_quantity : Int32 = 1,
        useful_directions : Array(TradingRules::Direction) = [] of TradingRules::Direction,
      ) : PositionSizing
        validate!(
          capital: capital,
          risk_rate: risk_rate,
          entry_price: entry_price,
          stop_steps: stop_steps,
          minimum_quantity: minimum_quantity,
          useful_directions: useful_directions,
        )

        risk_directions = Array.new(
          stop_steps,
          TradingRules::Direction::DownWard,
        )
        risk_path = project(entry_price, risk_directions)
        useful_path = project(entry_price, useful_directions)

        stop_price = risk_path.last.price
        price_loss = entry_price - stop_price
        risk_distance = price_loss / entry_price
        if price_loss <= 0.0 || risk_distance <= 0.0
          raise LowLevelError.new(
            "invalid risk distance computed by position sizing",
            kind: LowLevelError::Kind::Technical,
            log_context: {
              :entry_price => entry_price.to_s,
              :stop_price  => stop_price.to_s,
              :steps       => stop_steps.to_s,
              :source      => Core::Utils.source(__FILE__, __LINE__),
            },
          )
        end

        risk_amount = capital * risk_rate
        maximum_quantity_by_risk = (risk_amount / price_loss).floor.to_i

        unit_maximum_investment = maximum_unit_investment(
          entry_price,
          risk_path,
        )
        maximum_quantity_by_capital =
          (capital / unit_maximum_investment).floor.to_i

        maximum_quantity = if maximum_quantity_by_risk <= maximum_quantity_by_capital
                             maximum_quantity_by_risk
                           else
                             maximum_quantity_by_capital
                           end

        minimum_operable_quantity = minimum_initial_quantity(
          minimum_quantity,
          useful_path,
        )

        limiting_constraint =
          if maximum_quantity_by_risk <= maximum_quantity_by_capital
            PositionSizingConstraint::Risk
          else
            PositionSizingConstraint::Capital
          end

        failure = failure_for(
          maximum_quantity_by_risk,
          maximum_quantity_by_capital,
          maximum_quantity,
          minimum_operable_quantity,
        )

        quantity = failure.nil? ? maximum_quantity : 0

        PositionSizing.new(
          capital: capital,
          risk_rate: risk_rate,
          risk_amount: risk_amount,
          entry_price: entry_price,
          stop_steps: stop_steps,
          stop_price: stop_price,
          risk_distance: risk_distance,
          maximum_quantity_by_risk: maximum_quantity_by_risk,
          maximum_quantity_by_capital: maximum_quantity_by_capital,
          maximum_quantity: maximum_quantity,
          minimum_operable_quantity: minimum_operable_quantity,
          quantity: quantity,
          initial_amount: quantity * entry_price,
          loss_at_stop: quantity * price_loss,
          maximum_projected_investment: quantity * unit_maximum_investment,
          limiting_constraint: limiting_constraint,
          failure: failure,
          risk_path: risk_path,
          useful_path: useful_path,
        )
      end

      # Returns the smallest opening quantity for which every order generated
      # along useful_directions reaches minimum_quantity. This is useful for
      # fixed-amount candidate evaluation as well as capital sizing.
      def minimum_operable_quantity(
        *,
        entry_price : Float64,
        minimum_quantity : Int32 = 1,
        useful_directions : Array(TradingRules::Direction) = [] of TradingRules::Direction,
      ) : Int32
        validate_positive!("entry_price", entry_price)
        if minimum_quantity <= 0
          invalid_argument!("minimum_quantity", minimum_quantity)
        end
        if useful_directions.any? { |direction| direction.none? }
          invalid_argument!("useful_directions", "None")
        end
        minimum_initial_quantity(
          minimum_quantity,
          project(entry_price, useful_directions),
        )
      end

      # Projects a sequence of adjacent scale movements for q0 = 1.0.
      # This method is public to let the backtest probe build and inspect the
      # useful positions reached before a reset without duplicating the scale
      # calculations.
      def project(
        entry_price : Float64,
        directions : Array(TradingRules::Direction),
      ) : Array(PositionSizingStep)
        state = ProjectionState.new(
          position: TradingRules::Position.new(0, 0, 0),
          price: entry_price,
          stock_coefficient: 1.0,
          kcp: 1.0,
          unit_investment: entry_price,
        )
        result = [] of PositionSizingStep

        directions.each_with_index do |direction, index|
          next_position = move(state.position, direction)
          coefficient = TradingRules::Coefficient.new(
            opscale: scale,
            q0: 1.0,
            c0: entry_price,
            kcpc: 1.0,
            kspc: 1.0,
            start_position: state.position,
            next_position: next_position,
            price: state.price,
            kcp: state.kcp,
            origin: TradingRules::Origin::FromOrder,
            price_direction: direction,
            settings_operations_count: index + 1,
          )

          next_price = coefficient.cpe
          next_stock = coefficient.spe
          order_coefficient = (next_stock - state.stock_coefficient).abs
          unit_investment = state.unit_investment +
                            (next_stock - state.stock_coefficient) * next_price

          result << PositionSizingStep.new(
            direction: direction,
            position: next_position,
            price: next_price,
            price_coefficient: next_price / entry_price,
            stock_coefficient: next_stock,
            order_coefficient: order_coefficient,
            unit_investment: unit_investment,
          )

          state = ProjectionState.new(
            position: next_position,
            price: next_price,
            stock_coefficient: next_stock,
            kcp: coefficient.kcp,
            unit_investment: unit_investment,
          )
        end

        result
      end

      private def validate!(
        *,
        capital : Float64,
        risk_rate : Float64,
        entry_price : Float64,
        stop_steps : Int32,
        minimum_quantity : Int32,
        useful_directions : Array(TradingRules::Direction),
      ) : Nil
        validate_positive!("capital", capital)
        validate_positive!("entry_price", entry_price)

        unless 0.0 < risk_rate < 1.0
          invalid_argument!("risk_rate", risk_rate)
        end
        if stop_steps <= 0
          invalid_argument!("stop_steps", stop_steps)
        end
        if minimum_quantity <= 0
          invalid_argument!("minimum_quantity", minimum_quantity)
        end
        if useful_directions.any? { |direction| direction.none? }
          invalid_argument!("useful_directions", "None")
        end
      end

      private def validate_positive!(name : String, value : Float64) : Nil
        invalid_argument!(name, value) unless value > 0.0
      end

      private def invalid_argument!(name : String, value) : NoReturn
        raise LowLevelError.new(
          "invalid position-sizing argument '#{name}=#{value}'",
          kind: LowLevelError::Kind::Technical,
          log_context: {
            :name   => name,
            :value  => value.to_s,
            :source => Core::Utils.source(__FILE__, __LINE__),
          },
        )
      end

      private def move(
        position : TradingRules::Position,
        direction : TradingRules::Direction,
      ) : TradingRules::Position
        case direction
        in TradingRules::Direction::UpWard
          position.upmove(scale.emax)
        in TradingRules::Direction::DownWard
          position.downmove(scale.emin)
        in TradingRules::Direction::None
          invalid_argument!("direction", direction)
        end
      end

      private def maximum_unit_investment(
        entry_price : Float64,
        path : Array(PositionSizingStep),
      ) : Float64
        maximum = entry_price
        path.each do |step|
          maximum = step.unit_investment if step.unit_investment > maximum
        end
        maximum
      end

      # Operability concerns the quantity of every generated order, not the
      # total stock remaining at the corresponding position. The real order
      # engine rounds each theoretical stock independently and then subtracts
      # the preceding rounded stock. Reproduce that rule exactly here.
      private def minimum_initial_quantity(
        minimum_quantity : Int32,
        path : Array(PositionSizingStep),
      ) : Int32
        path.each do |step|
          coefficient = step.order_coefficient
          if coefficient <= 0.0
            raise LowLevelError.new(
              "invalid order coefficient computed by position sizing",
              kind: LowLevelError::Kind::Technical,
              log_context: {
                :position    => step.position.to_s,
                :coefficient => coefficient.to_s,
                :source      => Core::Utils.source(__FILE__, __LINE__),
              },
            )
          end
        end

        quantity = minimum_quantity
        loop do
          return quantity if path_operable?(quantity, minimum_quantity, path)
          quantity += 1
        end
      end

      private def path_operable?(
        initial_quantity : Int32,
        minimum_quantity : Int32,
        path : Array(PositionSizingStep),
      ) : Bool
        last_stock = initial_quantity

        path.each do |step|
          next_stock = (initial_quantity * step.stock_coefficient).round.to_i
          order_quantity = (next_stock - last_stock).abs
          return false if order_quantity < minimum_quantity
          last_stock = next_stock
        end

        true
      end

      private def failure_for(
        maximum_quantity_by_risk : Int32,
        maximum_quantity_by_capital : Int32,
        maximum_quantity : Int32,
        minimum_operable_quantity : Int32,
      ) : PositionSizingFailure?
        return PositionSizingFailure::RiskQuantityZero if maximum_quantity_by_risk <= 0
        return PositionSizingFailure::CapitalQuantityZero if maximum_quantity_by_capital <= 0
        if maximum_quantity < minimum_operable_quantity
          return PositionSizingFailure::InsufficientOperability
        end
        nil
      end
    end
  end
end
