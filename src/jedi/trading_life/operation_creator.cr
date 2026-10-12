module Jedi
  module TradingLife
    class OperationCreator
      private getter ref = ""
      @conn_db : DB::Connection

      def initialize(@transaction_source : DB::Connection | DB::Transaction)
        @conn_db = if transaction_source.is_a?(DB::Transaction)
                     transaction_source.connection
                   else
                     transaction_source
                   end
        @context_loader = TradingSystem::TradeContextLoader.new(@conn_db)
      end

      def call(*,
               trade_ident : String | PkId,
               timestamp : Time,
               type : Operation::Type,
               mode : Operation::Mode,
               quantity : Int32,
               price : Float64,
               cfees : Float64 | NamedTuple(rate: Float64, min: Float64),
               tickcheck : Bool) : PkId
        @ref = Core::Utils.ref(trade_ident)
        validate_inputs!(type, quantity, price, cfees)
        validate_timestamp!(timestamp)

        context = @context_loader.load!(trade_ident)

        unless (last_op = context.last_operation).nil? || last_op.stock > 0
          raise LowLevelError.new(
            key: "operation.create.trade_is_closed",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        orders = String.build do |io|
          TradingSystem::OrderEngine.new(context.trade)
            .orders.each_with_index do |(key, order), idx|
            io << " | " unless idx.zero?
            io << key << ": " << order.type << " " << order.mode << " "
            io << order.quantity << " @ " << order.price
          end
        end
        operation_prerecording_context = {
          :trade  => context.trade.name + " - " + context.trade.security.name,
          :orders => orders,
          :money  => context.trade.money.to_s,
          :stop   => context.trade.stop.to_s,
        }

        settings = context.current_settings

        if settings.nil?
          raise LowLevelError.new(
            key: "operation.create.no_settings",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        validate_tick_price!(context.trade, type, price, tickcheck)

        last_global_invest = fetch_last_global_invest

        state =
          if !context.has_operations?
            build_initial_state(settings, timestamp, type, mode, quantity, price, cfees,
              context.trade.security.tax, last_global_invest)
          elsif (reinit = reinit_option_of(settings)) && reinit.merge? && settings.operations.empty?
            build_reinit_state(settings, context.last_operation.not_nil!,
              timestamp, type, mode, quantity, price, cfees,
              context.trade.security.tax, last_global_invest)
          elsif price.zero?
            build_zero_price_liquidation_state(settings,
              context.last_operation.not_nil!, timestamp, type, mode,
              quantity, price, cfees, context.trade.security.tax,
              last_global_invest)
          else
            build_standard_state(settings, context.last_operation.not_nil!,
              timestamp, type, mode, quantity, price, cfees,
              context.trade.security.tax, last_global_invest)
          end

        validate_zero_price_liquidation!(state)
        operation_id = persist_operation!(settings.id, state)

        if App.simulation.none?
          App.log_info(:operation_creator_context, "", operation_prerecording_context)
        end
        @ref = Core::Utils.ref(operation_id)
        App.info(key: "operation.create.success", params: {:ref => ref})
        operation_id
      end

      private def persist_operation!(settings_id : PkId, state : OperationState) : PkId
        operation_id = @transaction_source.transaction do |transaction|
          connection = transaction.connection
          id = OperationsRepository.new(connection).insert!(settings_id, state)

          q0 = state.q0
          c0 = state.c0
          if q0 && c0
            TradingSystem::SettingsRepository.new(connection)
              .update_q0_c0!(settings_id, q0, c0)
          end

          id
        end

        return operation_id if operation_id

        raise LowLevelError.new(
          "Operation persistence transaction was rolled back",
          kind: LowLevelError::Kind::Technical,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def validate_inputs!(
        type : Operation::Type,
        quantity : Int32,
        price : Float64,
        cfees : Float64 | NamedTuple(rate: Float64, min: Float64),
      ) : Nil
        unless quantity > 0
          raise LowLevelError.new(
            key: "operation.create.quantity_must_be_positive",
            context: {:quantity => quantity.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        unless price.finite? && price >= 0.0
          raise LowLevelError.new(
            key: "operation.create.price_must_be_positive",
            context: {:price => price.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        if price.zero? && !type.sell?
          raise LowLevelError.new(
            key: "operation.create.zero_price_requires_full_liquidation",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        fees_valid = case cfees
                     in Float64
                       cfees.finite? && cfees >= 0.0
                     in NamedTuple(rate: Float64, min: Float64)
                       cfees[:rate].finite? && cfees[:rate] >= 0.0 &&
                         cfees[:min].finite? && cfees[:min] >= 0.0
                     end
        return if fees_valid

        raise LowLevelError.new(
          key: "operation.create.invalid_fees",
          context: {:fees => cfees.to_s},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def validate_zero_price_liquidation!(state : OperationState) : Nil
        return unless state.price.zero?
        return if state.type.sell? && state.stock.zero?

        raise LowLevelError.new(
          key: "operation.create.zero_price_requires_full_liquidation",
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def reinit_option_of(settings) : TradingSystem::ReInitOption?
        raw = settings.reinit
        return nil if raw.nil?
        str = raw.to_s.strip
        return nil if str.empty?
        TradingSystem::ReInitOption.parse(str)
      end

      private def validate_timestamp!(timestamp : Time) : Nil
        last_operation = Operations.new(@conn_db)
          .fetch("SELECT id FROM operation ORDER BY timestamp DESC, id DESC LIMIT 1")
          .last?

        if !last_operation.nil? && last_operation.timestamp > timestamp
          raise LowLevelError.new(
            key: "operation.create.date_exceeded_last_operation",
            context: {:date => "#{timestamp}"},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        last_settings = TradingSystem::SettingsChain.new(@conn_db)
          .fetch("SELECT id FROM settings ORDER BY timestamp DESC LIMIT 1")
          .last?

        return if last_settings.nil?

        ok = if App.simulation.from_operation? || App.simulation.from_seed?
               last_settings.timestamp <= timestamp
             else
               last_settings.timestamp < timestamp
             end

        return if ok

        raise LowLevelError.new(
          key: "operation.create.date_exceeded_last_settings",
          context: {:date => "#{timestamp}"},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def validate_tick_price!(trade, type, price, tickcheck) : Nil
        # A full liquidation at zero has no meaningful quotation tick.
        return if price.zero?
        return unless tickcheck

        tick = if type == Operation::Type::Buy
                 trade.security.tick_buy
               else
                 trade.security.tick_sell
               end

        return if tick.price_valid?(price)

        raise LowLevelError.new(
          key: "operation.create.tick_control",
          context: {:tick => "#{tick.value}"},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def fetch_last_global_invest : Int32
        last_operation = Operations.new(@conn_db)
          .fetch("SELECT id FROM operation ORDER BY timestamp DESC, id DESC LIMIT 1")
          .last?

        last_operation.nil? ? 0 : last_operation.global_invest
      end

      private def build_initial_state(settings, timestamp, type, mode, quantity, price,
                                      cfees, tax, last_global_invest) : OperationState
        unless type == Operation::Type::Buy &&
               (mode == Operation::Mode::Market || mode == Operation::Mode::Limit)
          raise LowLevelError.new(
            key: "operation.create.buy_required",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        buy, sell, fees, stock = account_entry(type, quantity, price, cfees, tax, 0)

        OperationState.new(
          timestamp: timestamp,
          type: type,
          mode: mode,
          quantity: quantity.to_i,
          price: price,
          buy: buy,
          sell: sell,
          trade_invest: buy - sell,
          global_invest: last_global_invest + buy - sell,
          fees: fees,
          stock: stock.to_i,
          position: settings.position,
          ksp: 1.0,
          kcp: 1.0,
          q0: quantity.to_f,
          c0: price
        )
      end

      private def build_reinit_state(settings,
                                     lastop,
                                     timestamp : Time,
                                     type,
                                     mode,
                                     quantity : Int32,
                                     price,
                                     cfees,
                                     tax,
                                     last_global_invest) : OperationState
        # test below useless, I think, and raise should never happen
        # as test on reinit already done at call site !
        reinit = reinit_option_of(settings) ||
                 raise LowLevelError.new(
                   key: "operation.create.missing_reinit_option",
                   log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})

        # Convert the held stock once. Both the reinit reference price and the
        # execution price are supplied in the post-split unit.
        q0_part = TradingRules::LastData.new(settings, lastop).maybe_splitted_stock.to_f
        c0_part = reinit.c0
        base_amount = (q0_part * c0_part * 100).round.to_i
        amount = (quantity * price * 100).round.to_i
        case type
        in Operation::Type::Buy
          buy = amount
          sell = 0
          stock = q0_part + quantity
          adjusted_tax = tax
          signed_qty = quantity.to_f
        in Operation::Type::Sell
          if quantity > q0_part.to_i
            raise LowLevelError.new(
              key: "operation.create.short_selling_forbidden",
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
          buy = 0
          sell = amount
          stock = q0_part - quantity
          adjusted_tax = 0.0
          signed_qty = -quantity.to_f
        end
        fees = calculate_fees(cfees, amount, adjusted_tax)
        q0 = q0_part + signed_qty
        merged_amount = base_amount + buy - sell
        c0 = q0 == 0.0 ? 0.0 : (merged_amount / (q0 * 100.0)).round(4)
        OperationState.new(
          timestamp: timestamp,
          type: type,
          mode: mode,
          quantity: quantity.to_i,
          price: price,
          buy: buy,
          sell: sell,
          trade_invest: lastop.trade_invest + buy - sell,
          global_invest: last_global_invest + buy - sell,
          fees: fees,
          stock: stock.to_i, # NOTE Nombre entier attendu, rompu possible
          position: settings.position,
          ksp: 1.0,
          kcp: 1.0,
          q0: q0,
          c0: c0
        )
      end

      private def build_standard_state(settings, last_operation, timestamp, type, mode,
                                       quantity, price, cfees, tax,
                                       last_global_invest) : OperationState
        pd = price_direction(type, mode)
        lastdata = TradingRules::LastData.new(settings, last_operation)
        last_stock = lastdata.maybe_splitted_stock

        coeffs = TradingRules::Coefficient.new(
          lastdata: lastdata,
          price_direction: pd,
          origin: TradingRules::Origin::FromOperation,
          operation_price: price
        )

        buy, sell, fees, stock = account_entry(type, quantity, price,
          cfees, tax, last_stock)

        OperationState.new(
          timestamp: timestamp,
          type: type,
          mode: mode,
          quantity: quantity.to_i,
          price: price,
          buy: buy,
          sell: sell,
          trade_invest: last_operation.trade_invest + buy - sell,
          global_invest: last_global_invest + buy - sell,
          fees: fees,
          stock: stock.to_i,
          position: coeffs.next_position,
          ksp: coeffs.ksp,
          kcp: coeffs.kcp
        )
      end

      private def build_zero_price_liquidation_state(
        settings,
        last_operation,
        timestamp,
        type,
        mode,
        quantity,
        price,
        cfees,
        tax,
        last_global_invest,
      ) : OperationState
        lastdata = TradingRules::LastData.new(settings, last_operation)
        buy, sell, fees, stock = account_entry(type, quantity, price,
          cfees, tax, lastdata.maybe_splitted_stock)

        if settings.operations.empty?
          position = settings.position
          ksp = 1.0
          kcp = 1.0
        else
          position = last_operation.position
          ksp = last_operation.ksp
          kcp = last_operation.kcp
        end

        OperationState.new(
          timestamp: timestamp,
          type: type,
          mode: mode,
          quantity: quantity.to_i,
          price: price,
          buy: buy,
          sell: sell,
          trade_invest: last_operation.trade_invest + buy - sell,
          global_invest: last_global_invest + buy - sell,
          fees: fees,
          stock: stock.to_i,
          position: position,
          ksp: ksp,
          kcp: kcp
        )
      end

      private def price_direction(type, mode)
        if (type == Operation::Type::Buy && mode == Operation::Mode::Stop ||
           type == Operation::Type::Sell && (mode == Operation::Mode::Limit ||
           mode == Operation::Mode::Market))
          TradingRules::Direction::UpWard
        elsif (type == Operation::Type::Sell && mode == Operation::Mode::Stop ||
              type == Operation::Type::Sell && mode == Operation::Mode::StopLoss ||
              type == Operation::Type::Buy && (mode == Operation::Mode::Limit ||
              mode == Operation::Mode::Market))
          TradingRules::Direction::DownWard
        else
          raise LowLevelError.new(
            key: "operation.create.type_mode_invalid",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end

      private def account_entry(type, quantity, price, cfees, tax, stock)
        amount = (quantity * price * 100).round.to_i

        case type
        in Operation::Type::Buy
          buy = amount
          sell = 0
          stock += quantity
        in Operation::Type::Sell
          if quantity > stock
            raise LowLevelError.new(
              key: "operation.create.short_selling_forbidden",
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
          buy = 0
          sell = amount
          stock -= quantity
          tax = 0.0
        end

        fees = calculate_fees(cfees, amount, tax)
        {buy, sell, fees, stock}
      end

      private def calculate_fees(cfees, amount, tax)
        case cfees
        when nil
          0
        when NamedTuple(rate: Float64, min: Float64)
          [amount * (cfees[:rate] + tax), cfees[:min] * 100].max.round.to_i
        else
          (cfees * 100).round.to_i
        end
      end
    end
  end
end
