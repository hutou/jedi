module Jedi
  module Tools
    record FundingProjection,
      current_investment : Float64,
      maximum_investment : Float64,
      reserve : Float64,
      step_limit : Int32

    # Pure projection of the maximum net investment reachable from a current
    # Jedi state over the same operational horizon used by the diagnostics.
    #
    # Both upward and downward branches are explored. Therefore optimized and
    # non-optimized scales are handled by the same rules: a future buy raises
    # net investment, while a future sell lowers it. Fees are deliberately
    # excluded, consistently with trade_invest/global_invest.
    class FundingProjector
      private record Context,
        scale : TradingRules::Scale::Operational,
        q0 : Float64,
        c0 : Float64,
        kcpc : Float64,
        kspc : Float64,
        tick_buy : Exchange::Security::Tick?,
        tick_sell : Exchange::Security::Tick?

      private record State,
        position : TradingRules::Position,
        price : Float64,
        stock : Int32,
        kcp : Float64,
        investment_cents : Int64,
        settings_operations_count : Int32

      def initialize(@step_limit : Int32)
        if @step_limit <= 0
          raise LowLevelError.new(
            "invalid funding projection step limit '#{@step_limit}'",
            kind: LowLevelError::Kind::Technical,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
      end

      def candidate(
        *,
        scale : TradingRules::Scale::Operational,
        quantity : Int32,
        price : Float64,
      ) : FundingProjection
        return empty_projection if quantity <= 0

        context = Context.new(
          scale: scale,
          q0: quantity.to_f,
          c0: price,
          kcpc: 1.0,
          kspc: 1.0,
          tick_buy: nil,
          tick_sell: nil,
        )
        investment_cents = amount_cents(quantity, price)
        state = State.new(
          position: TradingRules::Position.new(0, 0, 0),
          price: price,
          stock: quantity,
          kcp: 1.0,
          investment_cents: investment_cents,
          settings_operations_count: 1,
        )
        build_projection(context, state)
      end

      def trade(trade : TradingSystem::Trade) : FundingProjection
        settings = trade.last_settings
        operation = trade.last_operation
        return empty_projection if settings.nil? || operation.nil? || operation.stock <= 0

        lastdata = TradingRules::LastData.new(settings, operation)
        start_position = if settings.operations.empty?
                           settings.position
                         else
                           operation.position
                         end
        if start_position.nil?
          raise LowLevelError.new(
            "missing trade position for funding projection",
            kind: LowLevelError::Kind::Technical,
            log_context: {
              :trade  => trade.id.to_s,
              :source => Core::Utils.source(__FILE__, __LINE__),
            },
          )
        end

        security = trade.security
        context = Context.new(
          scale: settings.scale.operational,
          q0: settings.q0,
          c0: settings.c0,
          kcpc: settings.kcpc,
          kspc: settings.kspc,
          tick_buy: security.tick_buy,
          tick_sell: security.tick_sell,
        )
        state = State.new(
          position: start_position,
          price: lastdata.maybe_splitted_price,
          stock: lastdata.maybe_splitted_stock,
          kcp: operation.kcp,
          investment_cents: operation.trade_invest.to_i64,
          settings_operations_count: settings.operations.size,
        )
        build_projection(context, state)
      end

      private def empty_projection : FundingProjection
        FundingProjection.new(
          current_investment: 0.0,
          maximum_investment: 0.0,
          reserve: 0.0,
          step_limit: @step_limit,
        )
      end

      private def build_projection(context : Context, state : State) : FundingProjection
        maximum = explore(context, state, @step_limit)
        reserve = maximum - state.investment_cents
        reserve = 0_i64 if reserve < 0_i64

        FundingProjection.new(
          current_investment: cents_to_amount(state.investment_cents),
          maximum_investment: cents_to_amount(maximum),
          reserve: cents_to_amount(reserve),
          step_limit: @step_limit,
        )
      end

      private def explore(context : Context, state : State, remaining : Int32) : Int64
        maximum = state.investment_cents
        return maximum if remaining <= 0 || state.stock <= 0

        each_direction do |direction|
          next_state = project_state(context, state, direction)
          next if next_state.nil?

          branch_maximum = explore(context, next_state, remaining - 1)
          maximum = branch_maximum if branch_maximum > maximum
        end
        maximum
      end

      private def each_direction(&) : Nil
        yield TradingRules::Direction::UpWard
        yield TradingRules::Direction::DownWard
      end

      private def project_state(
        context : Context,
        state : State,
        direction : TradingRules::Direction,
      ) : State?
        next_position = move(state.position, direction, context.scale)
        order_coeff = TradingRules::Coefficient.new(
          opscale: context.scale,
          q0: context.q0,
          c0: context.c0,
          kcpc: context.kcpc,
          kspc: context.kspc,
          start_position: state.position,
          next_position: next_position,
          price: state.price,
          kcp: state.kcp,
          origin: TradingRules::Origin::FromOrder,
          price_direction: direction,
          settings_operations_count: state.settings_operations_count,
        )

        next_stock = order_coeff.spe.round.to_i
        signed_quantity = next_stock - state.stock
        return nil if signed_quantity == 0 || next_stock < 0

        order_price = rounded_price(context, direction, signed_quantity, order_coeff.cpe)
        delta_cents = amount_cents(signed_quantity.abs, order_price)
        investment_cents = if signed_quantity >= 0
                             state.investment_cents + delta_cents
                           else
                             state.investment_cents - delta_cents
                           end

        execution_coeff = TradingRules::Coefficient.new(
          opscale: context.scale,
          q0: context.q0,
          c0: context.c0,
          kcpc: context.kcpc,
          kspc: context.kspc,
          start_position: state.position,
          next_position: next_position,
          price: state.price,
          kcp: state.kcp,
          origin: TradingRules::Origin::FromOperation,
          price_direction: direction,
          settings_operations_count: state.settings_operations_count,
          operation_price: order_price,
        )

        State.new(
          position: next_position,
          price: order_price,
          stock: next_stock,
          kcp: execution_coeff.kcp,
          investment_cents: investment_cents,
          settings_operations_count: state.settings_operations_count + 1,
        )
      end

      private def move(
        position : TradingRules::Position,
        direction : TradingRules::Direction,
        scale : TradingRules::Scale::Operational,
      ) : TradingRules::Position
        case direction
        in TradingRules::Direction::UpWard
          position.upmove(scale.emax)
        in TradingRules::Direction::DownWard
          position.downmove(scale.emin)
        in TradingRules::Direction::None
          raise LowLevelError.new(
            "invalid funding projection direction",
            kind: LowLevelError::Kind::Technical,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
      end

      private def rounded_price(
        context : Context,
        direction : TradingRules::Direction,
        signed_quantity : Int32,
        price : Float64,
      ) : Float64
        tick_buy = context.tick_buy
        tick_sell = context.tick_sell
        return price if tick_buy.nil? || tick_sell.nil?

        case direction
        in TradingRules::Direction::UpWard
          signed_quantity < 0 ? tick_sell.round_up(price) : tick_buy.round_up(price)
        in TradingRules::Direction::DownWard
          signed_quantity > 0 ? tick_buy.round_down(price) : tick_sell.round_down(price)
        in TradingRules::Direction::None
          price
        end
      end

      private def amount_cents(quantity : Int32, price : Float64) : Int64
        (quantity.to_i64 * price * 100.0).round.to_i64
      end

      private def cents_to_amount(value : Int64) : Float64
        value / 100.0
      end
    end
  end
end
