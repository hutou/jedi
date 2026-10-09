module Jedi
  module Tools
    # Controls how an OHLC candle is interpreted when one or more pending
    # orders are touched during the same trading session.
    enum BacktestExecutionMode
      Conservative
      Legacy
    end

    # Controls whether the orders generated immediately after the opening buy
    # may be executed during that same daily candle.
    enum BacktestOpeningDayPolicy
      NextSession
      SameSession
    end

    # One pending-order decision for a daily OHLC candle.
    record BacktestExecutionDecision,
      key : Symbol,
      order : TradingSystem::OrderEngine::Order,
      execution_price : Float64,
      gap : Bool,
      conflict : Bool

    # Persisted diagnostic attached to BacktestResult.
    record BacktestExecutionEvent,
      timestamp : Time,
      key : Symbol,
      order_type : TradingLife::Operation::Type,
      order_mode : TradingLife::Operation::Mode,
      order_price : Float64,
      execution_price : Float64,
      gap : Bool,
      conflict : Bool,
      opening_day : Bool

    class BacktestExecutionPolicy
      alias Order = TradingSystem::OrderEngine::Order
      alias Orders = Hash(Symbol, Order)

      getter mode : BacktestExecutionMode
      getter opening_day : BacktestOpeningDayPolicy

      def initialize(
        @mode : BacktestExecutionMode = BacktestExecutionMode::Conservative,
        @opening_day : BacktestOpeningDayPolicy = BacktestOpeningDayPolicy::NextSession,
      )
      end

      def orders_active_on_opening_day? : Bool
        opening_day.same_session?
      end

      def select(
        orders : Orders,
        quote : MarketData::Quote,
      ) : BacktestExecutionDecision?
        mode.legacy? ? select_legacy(orders, quote) : select_conservative(orders, quote)
      end

      private def select_legacy(
        orders : Orders,
        quote : MarketData::Quote,
      ) : BacktestExecutionDecision?
        # Preserve the exact step-A order selection, including its historical
        # behaviour when a stoploss exists but is not touched.
        key = if (up = orders[:up]?) && triggered?(:up, up, quote)
                :up
              elsif orders.has_key?(:loss)
                loss = orders[:loss]
                triggered?(:loss, loss, quote) ? :loss : nil
              elsif (down = orders[:down]?) && triggered?(:down, down, quote)
                :down
              else
                nil
              end

        return nil if key.nil?

        order = orders[key]
        build_decision(
          key,
          order,
          quote,
          conflict: triggered_orders(orders, quote).size > 1,
          gap_aware: false,
        )
      end

      private def select_conservative(
        orders : Orders,
        quote : MarketData::Quote,
      ) : BacktestExecutionDecision?
        candidates = triggered_orders(orders, quote)
        return nil if candidates.empty?

        # Opening executions have a known chronology. Only use the intraday
        # priority when no pending order is already executable at the open.
        opening_candidates = candidates.select do |candidate|
          executable_at_opening?(candidate[1], quote[:open])
        end
        selected = conservative_selection(
          opening_candidates.empty? ? candidates : opening_candidates,
          quote,
        )
        key = selected[0]
        order = selected[1]

        build_decision(
          key,
          order,
          quote,
          conflict: candidates.size > 1,
          gap_aware: true,
        )
      end

      private def executable_at_opening?(order : Order, opening : Float64) : Bool
        case order.mode
        when TradingLife::Operation::Mode::Limit
          order.type.buy? ? opening <= order.price : opening >= order.price
        when TradingLife::Operation::Mode::Stop,
             TradingLife::Operation::Mode::StopLoss
          order.type.buy? ? opening >= order.price : opening <= order.price
        else
          false
        end
      end

      private def triggered_orders(
        orders : Orders,
        quote : MarketData::Quote,
      ) : Array(Tuple(Symbol, Order))
        result = [] of Tuple(Symbol, Order)
        orders.each do |key, order|
          result << {key, order} if triggered?(key, order, quote)
        end
        result
      end

      private def triggered?(
        key : Symbol,
        order : Order,
        quote : MarketData::Quote,
      ) : Bool
        case key
        when :up
          quote[:high] >= order.price
        when :down, :loss
          quote[:low] <= order.price
        else
          triggered_from_order?(order, quote)
        end
      end

      private def triggered_from_order?(
        order : Order,
        quote : MarketData::Quote,
      ) : Bool
        case order.mode
        when TradingLife::Operation::Mode::Limit
          if order.type.buy?
            quote[:low] <= order.price
          else
            quote[:high] >= order.price
          end
        when TradingLife::Operation::Mode::Stop,
             TradingLife::Operation::Mode::StopLoss
          if order.type.buy?
            quote[:high] >= order.price
          else
            quote[:low] <= order.price
          end
        else
          false
        end
      end

      private def conservative_selection(
        candidates : Array(Tuple(Symbol, Order)),
        quote : MarketData::Quote,
      ) : Tuple(Symbol, Order)
        loss = candidates.find { |candidate| candidate[0] == :loss }
        down = candidates.find { |candidate| candidate[0] == :down }
        up = candidates.find { |candidate| candidate[0] == :up }

        if loss && down
          loss_order = loss[1]

          # Jedi's operational priority is preserved:
          # - loss-cut (CL): the lower buy-limit order is preferred while the
          #   session opens above the protective stop;
          # - gain-protection (GP): the stoploss remains preferred;
          # - a gap opening through the stop always executes the stop first.
          if loss_order.kind.try(&.cl?) && quote[:open] > loss_order.price
            return down
          end
          return loss
        end

        loss || down || up || candidates.first
      end

      private def build_decision(
        key : Symbol,
        order : Order,
        quote : MarketData::Quote,
        *,
        conflict : Bool,
        gap_aware : Bool,
      ) : BacktestExecutionDecision
        execution_price = gap_aware ? gap_execution_price(order, quote) : order.price

        BacktestExecutionDecision.new(
          key: key,
          order: order,
          execution_price: execution_price,
          gap: execution_price != order.price,
          conflict: conflict,
        )
      end

      # Limit orders benefit from a favourable opening gap. Stop orders and
      # stoplosses suffer an adverse opening gap. Otherwise, execution remains
      # at the theoretical order price.
      private def gap_execution_price(
        order : Order,
        quote : MarketData::Quote,
      ) : Float64
        opening = quote[:open]

        case order.mode
        when TradingLife::Operation::Mode::Limit
          if order.type.buy?
            opening < order.price ? opening : order.price
          else
            opening > order.price ? opening : order.price
          end
        when TradingLife::Operation::Mode::Stop,
             TradingLife::Operation::Mode::StopLoss
          if order.type.buy?
            opening > order.price ? opening : order.price
          else
            opening < order.price ? opening : order.price
          end
        else
          order.price
        end
      end
    end
  end
end
