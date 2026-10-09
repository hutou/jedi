module Jedi
  module TradingSystem
    class OrderEngine
      record Order,
        type : TradingLife::Operation::Type,
        mode : TradingLife::Operation::Mode,
        position : TradingRules::Position,
        quantity : Int32,
        price : Float64,
        spe : Float64,
        cpe : Float64,
        last_stock : Int32,
        operation_id : PkId,
        original_quantity : Int32? = nil,
        kind : TradeStop::Kind? = nil,
        debug_line : String = "" do
        setter quantity : Int32
        setter original_quantity : Int32?
        setter debug_line : String
      end

      enum OperatingStatus
        Normal
        Degraded
        Blocked
      end

      record OperatingWarning,
        order_key : Symbol,
        message : String

      DEGRADED_QUANTITY_THRESHOLD = 1
      WARNING_QUANTITY_THRESHOLD  = 2

      private getter trade
      getter operating_status : OperatingStatus = OperatingStatus::Normal
      getter operating_warning_details = [] of OperatingWarning

      def operating_warnings : Array(String)
        operating_warning_details.map(&.message)
      end

      property calculated_orders = {} of Symbol => Order

      record Context,
        option_net_stop : Bool,
        risk_amount : Float64,
        money : TradingSystem::Money,
        step_moves : Array(StepMove),
        steps_down_gain : Float64,
        up_order : Order,
        down_order : Order

      def initialize(@trade : TradingSystem::Trade, *, @capital : Float64? = nil)
      end

      def orders(option_net_stop : Bool = false, option_update_now : Bool = false)
        calculated_orders.clear

        reset_operating_diagnostic

        return calculated_orders if (settings = @trade.last_settings).nil? ||
                                    (operation = @trade.last_operation).nil?
        lastdata = TradingRules::LastData.new(settings, operation)
        # last_operation does not necessarily belong to last_settings
        # (a new settings may have been created since !)
        up_order, down_order = calculate_standard_orders(lastdata)

        stoploss_order = nil

        active_money = if @trade.money
                         @trade.money
                       else
                         nil
                       end
        if active_money
          # Money management is on
          #
          # Preliminary calculations
          step_moves = step_moves(lastdata, active_money.steps_down)
          risk_amount = active_money.risk_amount(reference_capital)
          steps_down_gain = calculate_steps_down_gain(lastdata, active_money.steps_down)
          context = Context.new(
            option_net_stop: option_net_stop,
            risk_amount: risk_amount,
            money: active_money,
            step_moves: step_moves,
            steps_down_gain: steps_down_gain,
            up_order: up_order,
            down_order: down_order)
          guaranteed_gain, stoploss_price, stop_kind = stoploss_context(lastdata, context)
          #
          #
          if stoploss_price.nil?
            # Jedi is on its own!
            @trade.stop_clear if @trade.stop
          else
            # Ok, we have a stoploss price
            #
            # But is it already outdated?
            if current_price = obtain_current_price(lastdata, option_update_now)
              current_gain_loss = calculate_current_gain_loss(lastdata, current_price)
              # too late, maybe
              if current_gain_loss < -risk_amount
                App.warn(key: "trade.orders.out_of_control", params: {
                  :trade   => trade.name,
                  :maxloss => "#{-risk_amount}",
                  :curloss => "#{current_gain_loss}",
                })
              elsif current_price < stoploss_price
                App.warn(key: "trade.orders.stoploss_exceeded", params: {
                  :trade     => trade.name,
                  :current   => "#{current_price}",
                  :stoploss  => "#{"%.4f" % stoploss_price}",
                  :operation => "#{trade.last_operation.as(TradingLife::Operation).id}",
                })
                @trade.stop_clear if @trade.stop
              else
                # Ok, are standard orders still valid ?
                down_order = nil unless down_order.price > stoploss_price
                up_order = nil unless up_order.price > stoploss_price
                #
                # All is ok, let's build the stoploss order
                stoploss_order = build_stoploss_order(lastdata, context, stoploss_price,
                  guaranteed_gain, stop_kind, current_price)
              end
            else
              # no current price !
              # consequence: stoploss price cannot be validated, so no stoploss order
              # but what if a trade.stop exists ?
              # consequence: a previous price should have existed, so a missing current price is an anomaly
              # that needs to be investigated. Best decision : do nothing (above all, do *not* clear trade.stop)!
              # but alert user !!!
              if @trade.stop
                App.error(key: "trade.orders.trade_stop_price_anomaly", params: {
                  :trade => @trade.name,
                  :stop  => @trade.stop.to_s,
                })
              end
            end
          end
        else
          # No money management, jedi is on its own!
          @trade.stop_clear if @trade.stop
        end
        add_calculated_order(:down, down_order) if down_order
        add_calculated_order(:up, up_order) if up_order
        add_calculated_order(:loss, stoploss_order) if stoploss_order
        # If order quantities are too low, alert the user that
        # Jedi will soon be inapplicable
        check_trade_conditions(lastdata)

        # Return orders and current price !
        calculated_orders
      end

      def build_stoploss_order(lastdata, context, stoploss_price, guaranteed_gain, stop_kind, current_price)
        quantity = original_quantity = lastdata.operation.stock
        quantity -= context.up_order.quantity if context.option_net_stop
        stoploss_price_formatted = @trade.security.tick_sell.as(Exchange::Security::Tick)
          .round_down(stoploss_price)
        new_stop = TradeStop.new(lastdata.operation.id,
          stop_kind.as(TradeStop::Kind),
          lastdata.operation.stock,
          stoploss_price_formatted,
          guaranteed_gain.as(Float64))
        debug_line = String.build do |io|
          if read_stop = @trade.stop
            io << "previous_stop=" << read_stop.to_s << " "
          end
          io << "new_stop=" << new_stop.to_s << " "
          io << "steps_down_gain=" << context.steps_down_gain << " "
          io << "guaranteed_gain=" << guaranteed_gain << " "
          io << "stoploss_price=" << stoploss_price << " "
          io << "current_price=" << current_price # << " "
        end
        @trade.stop_update(new_stop)
        Order.new(
          type: TradingLife::Operation::Type::Sell,
          mode: TradingLife::Operation::Mode::StopLoss,
          position: TradingRules::Position.new(0, 0, 0),
          quantity: quantity,
          price: stoploss_price_formatted,
          spe: 0.0,
          cpe: 0.0,
          last_stock: lastdata.operation.stock,
          operation_id: lastdata.operation.id,
          debug_line: debug_line,
          original_quantity: original_quantity,
          kind: stop_kind
        )
      end

      def stoploss_context(lastdata, context)
        # A buy stop (unoptimized sacles)
        if read_stop = @trade.stop
          # compare with stop
          guaranteed_gain, stoploss_price, stop_kind = process_stop(read_stop,
            context, lastdata)
        else
          # save GP/CL if appropriate
          minimum_objective_gain = context.money.target_amount(reference_capital)
          if context.steps_down_gain > minimum_objective_gain # G_n > O ==> GP
            guaranteed_gain = context.steps_down_gain
            stoploss_price = calculate_stoploss_price(lastdata.operation.stock,
              step_moves(lastdata, context.money.steps_down))
            stop_kind = TradeStop::Kind::GP
          elsif context.steps_down_gain < -context.risk_amount
            # Here, we must calculate the stoploss price to limit loss at -R
            guaranteed_gain = -context.risk_amount
            stoploss_price = (lastdata.operation.trade_invest/100 - context.risk_amount) /
                             lastdata.operation.stock
            stop_kind = TradeStop::Kind::CL
          else
            # No stoploss
            stop_kind = nil
            guaranteed_gain = nil
            stoploss_price = nil
          end
        end
        {guaranteed_gain, stoploss_price, stop_kind}
      end

      def process_stop(trade_stop, context, lastdata)
        case trade_stop.kind
        in TradeStop::Kind::GP
          # compare down_steps_gain with trade_stop guaranteed_gain
          if trade_stop.guaranteed_gain >= context.steps_down_gain
            # We keep trade_stop.guaranteed_gain, but we need to calculate
            # a new stoploss as stock has changed
            guaranteed_gain = trade_stop.guaranteed_gain
            stoploss_price = (guaranteed_gain + (lastdata.operation.trade_invest/100)) /
                             lastdata.operation.stock
          else
            # context.steps_down_gain become the new guaranteed_gain
            guaranteed_gain = context.steps_down_gain
            stoploss_price = calculate_stoploss_price(lastdata.operation.stock,
              context.step_moves)
          end
          stop_kind = TradeStop::Kind::GP
        in TradeStop::Kind::CL
          if context.steps_down_gain > -context.risk_amount
            # we have leaved critical area, Jedi is back on its own
            # No more trade stop, nor stoploss
            stoploss_price = nil
          else
            # We are still in critical area, but we must adapt stoploss_order
            # from last operation
            guaranteed_gain = trade_stop.guaranteed_gain
            stoploss_price = (guaranteed_gain + (lastdata.operation.trade_invest/100)) /
                             lastdata.operation.stock
          end
          stop_kind = TradeStop::Kind::CL
        end
        {guaranteed_gain, stoploss_price, stop_kind}
      end

      def calculate_current_gain_loss(lastdata, current_price)
        buys = sells = 0
        @trade.operations.each do |op|
          buys += op.buy
          sells += op.sell
        end
        (((lastdata.operation.stock * current_price * 100).to_i + sells - buys) / 100).round(2)
      end

      def calculate_steps_down_gain(lastdata, steps_down)
        wrk = step_moves(lastdata, steps_down).last
        # The gain at 'n' down steps further
        ((wrk.sells - wrk.buys) / 100 + wrk.stock * wrk.price).round(2)
      end

      def step_moves(lastdata, steps_down)
        steps_array(lastdata, steps_down)
      end

      def obtain_current_price(lastdata, option_update_now) : Float64?
        case App.simulation
        in SimulationMode::None
          Exchange::QuoteResolver.new(@trade.security).price(
            option_update_now: option_update_now)
        in SimulationMode::FromOperation
          # XXX
          # if stop = @trade.stop
          #   op_id = @trade.last_operation.as(TradingLife::Operation).id
          #   @trade.stop_clear if stop.operation_id > op_id
          # end
          # Probably better *not* to update price to present value
          # In simulation, we can use any operation in the past
          # Exchange::QuoteResolver.new(@trade.security).price(
          #   option_update_now: option_update_now)
          lastdata.maybe_splitted_price
          # XXX
        in SimulationMode::FromSeed
          lastdata.maybe_splitted_price
        end
      end

      private def reference_capital : Float64
        if capital = @capital
          capital
        elsif App.simulation.none? || App.capital <= 0
          App.dedicated_capital
        else
          App.capital.to_f
        end
      end

      private def check_trade_conditions(lastdata)
        # Check if trade is approaching a degraded condition
        if operating_warning_details.empty?
          # no alert from next orders, check further steps up
          upward_order_quantities(lastdata, App.diagnostic_steps).each do |quantity|
            if quantity <= WARNING_QUANTITY_THRESHOLD
              add_operating_warning(
                :up,
                I18n.t("trade.orders.operating_mode_warning")
              )
              break
            end
          end
        end
      end

      # Project only the quantities needed by the operability warning.
      #
      # This calculation is intentionally distinct from steps_array, whose
      # historical purpose is to value the successive downward movements used
      # by money management and the stop-loss calculation.
      private def upward_order_quantities(lastdata, step_count : Int32) : Array(Int32)
        settings = lastdata.settings
        operation = lastdata.operation
        opscale = settings.scale.operational
        position = if settings.operations.empty?
                     settings.position.as(TradingRules::Position)
                   else
                     operation.position
                   end
        price = lastdata.maybe_splitted_price
        stock = lastdata.maybe_splitted_stock
        kcp = operation.kcp
        settings_operations_count = settings.operations.size
        quantities = [] of Int32

        step_count.times do
          next_position = position.upmove(opscale.emax)
          order_coeffs = TradingRules::Coefficient.new(
            opscale: opscale,
            q0: settings.q0,
            c0: settings.c0,
            kcpc: settings.kcpc,
            kspc: settings.kspc,
            start_position: position,
            next_position: next_position,
            price: price,
            kcp: kcp,
            origin: TradingRules::Origin::FromOrder,
            price_direction: TradingRules::Direction::UpWard,
            settings_operations_count: settings_operations_count,
            operation_price: 0.0,
            sync: nil
          )
          next_stock = order_coeffs.spe.round.to_i
          signed_quantity = next_stock - stock
          order_type = if signed_quantity < 0
                         TradingLife::Operation::Type::Sell
                       else
                         TradingLife::Operation::Type::Buy
                       end
          order_price = rounded_order_price(
            TradingRules::Direction::UpWard,
            order_type,
            order_coeffs.cpe
          )

          operation_coeffs = TradingRules::Coefficient.new(
            opscale: opscale,
            q0: settings.q0,
            c0: settings.c0,
            kcpc: settings.kcpc,
            kspc: settings.kspc,
            start_position: position,
            next_position: next_position,
            price: price,
            kcp: kcp,
            origin: TradingRules::Origin::FromOperation,
            price_direction: TradingRules::Direction::UpWard,
            settings_operations_count: settings_operations_count,
            operation_price: order_price,
            sync: nil
          )

          quantities << signed_quantity.abs
          position = next_position
          price = order_price
          stock = next_stock
          kcp = operation_coeffs.kcp
          settings_operations_count += 1
        end

        quantities
      end

      private def calculate_standard_orders(lastdata)
        up_order = build_order(lastdata,
          TradingRules::Direction::UpWard
        )
        down_order = build_order(
          lastdata,
          TradingRules::Direction::DownWard
        )
        {up_order, down_order}
      end

      private def build_order(lastdata, direction : TradingRules::Direction) : Order
        last_stock = lastdata.maybe_splitted_stock

        coeffs = TradingRules::Coefficient.new(
          lastdata: lastdata,
          price_direction: direction,
          origin: TradingRules::Origin::FromOrder
        )
        quantity = coeffs.spe.round.to_i - last_stock

        type, mode =
          case direction
          when TradingRules::Direction::UpWard
            quantity < 0 ? {TradingLife::Operation::Type::Sell, TradingLife::Operation::Mode::Limit} : {
              TradingLife::Operation::Type::Buy, TradingLife::Operation::Mode::Stop,
            }
          else
            quantity < 0 ? {TradingLife::Operation::Type::Sell, TradingLife::Operation::Mode::Stop} : {
              TradingLife::Operation::Type::Buy, TradingLife::Operation::Mode::Limit,
            }
          end

        price = rounded_order_price(direction, type, coeffs.cpe)
        debug_line = String.build do |io|
          io << "cpe:" << coeffs.cpe << " "
          io << "spe:" << coeffs.spe << " "
          io << "kcp:" << coeffs.kcp << " "
          io << "ksp:" << coeffs.ksp << " "
          io << "kspc:" << lastdata.settings.kspc << " "
          io << "kcpc:" << lastdata.settings.kcpc << " "
        end
        Order.new(
          type: type,
          mode: mode,
          position: coeffs.next_position,
          quantity: quantity.abs,
          price: price,
          spe: coeffs.spe,
          cpe: coeffs.cpe,
          last_stock: last_stock,
          operation_id: lastdata.operation.id,
          debug_line: debug_line
        )
      end

      record StepMove,
        quantity : Int32,
        price : Float64,
        buys : Int32,
        sells : Int32,
        stock : Int32

      private def steps_array(
        lastdata,
        step_count,
      )
        last_settings = lastdata.settings
        last_operation = lastdata.operation
        # Prepare data that do not change inside the loop
        # Data from settings (= trade.last_settings)
        opscale = last_settings.scale.operational
        q0 = last_settings.q0
        c0 = last_settings.c0
        kcpc = last_settings.kcpc
        kspc = last_settings.kspc
        # Prepare data that will change inside the loop
        start_position = last_operation.position
        next_position = start_position.downmove(opscale.emin)
        price = lastdata.maybe_splitted_price # price and stock
        stock = lastdata.maybe_splitted_stock # are already splitted, if applicable
        buys = sells = 0
        @trade.operations.each do |op|
          buys += op.buy
          sells += op.sell
        end
        kcp = last_operation.kcp
        settings_operations_count = last_settings.operations.size
        step_moves = [] of StepMove
        step_count.times do
          coeffs = TradingRules::Coefficient.new(
            opscale: opscale,
            q0: q0,
            c0: c0,
            kcpc: kcpc,
            kspc: kspc,
            start_position: start_position,
            next_position: next_position,
            price: price,
            kcp: kcp,
            origin: TradingRules::Origin::FromOrder,
            price_direction: TradingRules::Direction::DownWard,
            settings_operations_count: settings_operations_count,
            operation_price: 0.0,
            sync: nil
          )
          price = trade.security.tick_buy.as(Exchange::Security::Tick).round_down(coeffs.cpe)
          work_stock = coeffs.spe.round.to_i
          quantity = work_stock - stock
          stock = work_stock
          amount = (quantity.abs * price * 100).round.to_i
          if quantity < 0
            sells += amount
          else
            buys += amount
          end
          step_moves << StepMove.new(quantity, price, buys, sells, stock)
          start_position = next_position
          next_position = start_position.downmove(opscale.emin)
        end
        step_moves
      end

      def calculate_stoploss_price(stock : Int32, step_moves : Array(StepMove)) : Float64
        raise LowLevelError.new(
          "Securities stock negative (#{stock}): cannot calculate stoploss",
          log_context: {
            :source => Core::Utils.source(__FILE__, __LINE__),
          }) if stock <= 0
        raise LowLevelError.new(
          "Empty steps_down list : cannot calculate stoploss",
          log_context: {
            :source => Core::Utils.source(__FILE__, __LINE__),
          }) if step_moves.empty?

        target_price = step_moves.last.price
        adjustment = step_moves.sum(0.0) do |step|
          (step.price - target_price) * step.quantity
        end
        (stock * target_price - adjustment) / stock
      end

      private def reset_operating_diagnostic : Nil
        @operating_status = OperatingStatus::Normal
        operating_warning_details.clear
      end

      private def add_calculated_order(key : Symbol, order : Order) : Nil
        diagnose_order_quantity(key, order)
        return if order.quantity <= 0

        calculated_orders[key] = order
      end

      private def diagnose_order_quantity(key : Symbol, order : Order) : Nil
        if order.quantity <= 0
          set_operating_status(OperatingStatus::Blocked)
          add_operating_warning(
            key,
            I18n.t("trade.orders.operating_mode_blocked",
              {key: key, quantity: "#{order.quantity}"})
          )
        elsif order.quantity <= DEGRADED_QUANTITY_THRESHOLD
          set_operating_status(OperatingStatus::Degraded)
          add_operating_warning(
            key,
            I18n.t("trade.orders.operating_mode_degraded",
              {key: key, quantity: "#{order.quantity}"})
          )
        end
      end

      private def add_operating_warning(order_key : Symbol, message : String) : Nil
        operating_warning_details << OperatingWarning.new(order_key, message)
      end

      private def set_operating_status(status : OperatingStatus) : Nil
        return if @operating_status == OperatingStatus::Blocked
        return if @operating_status == OperatingStatus::Degraded && status == OperatingStatus::Normal

        @operating_status = status
      end

      private def rounded_order_price(direction, type, work_price : Float64) : Float64
        case {direction, type}
        when {TradingRules::Direction::UpWard, TradingLife::Operation::Type::Sell}
          trade.security.tick_sell.as(Exchange::Security::Tick).round_up(work_price)
        when {TradingRules::Direction::UpWard, TradingLife::Operation::Type::Buy}
          trade.security.tick_buy.as(Exchange::Security::Tick).round_up(work_price)
        when {TradingRules::Direction::DownWard, TradingLife::Operation::Type::Buy}
          trade.security.tick_buy.as(Exchange::Security::Tick).round_down(work_price)
        else
          trade.security.tick_sell.as(Exchange::Security::Tick).round_down(work_price)
        end
      end

      # Implementation of 2 tick values : tick_buy and tick_sell
      # As their names say, tick_buy applies for buys and tick_sell for sells, but...
      #
      # | type and mode of orders:
      # | Sell Limit  |   Buy Stop            ==> Higher than jedi price) ==> up orders
      # |--^----------+----^-----------------> price calculated by jedi (full precision)
      # | Sell Stop   |   Buy Limit           ==> Lower than jedi price   ==> down orders
      #    ^               ^
      #    |               |
      #    |               +-----------------> use tick_buy
      #    +---------------------------------> use tick_sell

    end
  end
end
