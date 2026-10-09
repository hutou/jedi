require "./backtest_sizing_policy"
require "./backtest_execution_policy"

module Jedi
  module Tools
    # Runs the historical simulation and writes its trades, settings and
    # operations to the in-memory Jedi database.
    #
    # Sizing and OHLC execution are delegated to explicit policies so the
    # engine remains independent from CLI and presentation concerns.
    class BacktestEngine
      alias Orders = Hash(Symbol, TradingSystem::OrderEngine::Order)

      getter conn_main : DB::Connection
      getter conn_memory : DB::Connection
      getter quote_history : QuoteHistory
      getter scaledef : String
      getter money : TradingSystem::Money?
      getter sizing_policy : BacktestSizingPolicy
      getter execution_policy : BacktestExecutionPolicy

      def initialize(
        @conn_main : DB::Connection,
        @conn_memory : DB::Connection,
        @quote_history : QuoteHistory,
        @scaledef : String,
        @money : TradingSystem::Money?,
        @sizing_policy : BacktestSizingPolicy,
        @execution_policy : BacktestExecutionPolicy,
      )
      end

      def run : BacktestResult
        prepare_memory_database!

        security = create_security
        scale = Helpers.scale(conn_main, conn_memory, scaledef)
        sizing_events = [] of BacktestSizingEvent
        execution_events = [] of BacktestExecutionEvent
        simulate(scale, sizing_events, execution_events)

        # TradingSystem::TradeResults evaluates the last open position using the
        # quotation stored on the simulated security. Never query a live source
        # during an historical simulation.
        # security.set_quote(quote_history.quotes.last[:close])
        Exchange::QuoteSetter.new(security).set(quote_history.quotes.last[:close])

        BacktestResult.new(
          quote_history: quote_history,
          scale: scale,
          security: security,
          trades: TradingSystem::Trades.new(conn_memory).fetch,
          operations: TradingLife::Operations.new(conn_memory).fetch,
          sizing_policy: sizing_policy,
          sizing_events: sizing_events,
          execution_policy: execution_policy,
          execution_events: execution_events,
        )
      end

      private def prepare_memory_database! : Nil
        database = Database::Main.new(conn_memory)

        # Drop dependants first so the method remains safe if the same memory
        # connection has already hosted another simulation.
        database.drop_table_operation
        database.drop_table_settings
        database.drop_table_trade
        database.drop_table_security
        database.drop_table_scale

        database.create_table_security
        database.create_table_trade
        database.create_table_scale
        database.create_table_settings
        database.create_table_operation
      end

      private def create_security : Exchange::Security
        security_id = Exchange::SecurityCreator.new(conn_memory).call(
          isin: quote_history.isin,
          ticker: quote_history.ticker,
          name: quote_history.name,
          tick_buy: quote_history.tick,
          tick_sell: quote_history.tick,
          tax: 0.0,
        )
        Exchange::Security.new(conn_memory, security_id)
      end

      private def simulate(
        scale : TradingRules::Scale,
        sizing_events : Array(BacktestSizingEvent),
        execution_events : Array(BacktestExecutionEvent),
      ) : Nil
        new_trade = true
        trade_count = 0
        trade_id = 0_i64
        orders = Orders.new

        quote_history.quotes.each do |quote|
          opening_day = false

          if new_trade
            decision = sizing_policy.calculate(
              quote[:open],
              scale.operational,
            )
            sizing_events << BacktestSizingEvent.new(
              timestamp: quote[:date],
              decision: decision,
            )

            # In capital mode, an opening can be postponed until the security
            # becomes compatible with risk, capital and operability bounds.
            next unless decision.operable?

            trade_count += 1
            trade_id, orders = open_trade(
              trade_count,
              quote,
              scale,
              decision.quantity,
            )
            new_trade = false
            opening_day = true

            # The historical behaviour remains available explicitly. The
            # default policy activates pending orders on the next session.
            next unless execution_policy.orders_active_on_opening_day?
          end

          execution = execution_policy.select(orders, quote)
          next if execution.nil?

          order = execution.order
          execution_events << BacktestExecutionEvent.new(
            timestamp: quote[:date],
            key: execution.key,
            order_type: order.type,
            order_mode: order.mode,
            order_price: order.price,
            execution_price: execution.execution_price,
            gap: execution.gap,
            conflict: execution.conflict,
            opening_day: opening_day,
          )

          operation_id = TradingLife::OperationCreator.new(conn_memory).call(
            trade_ident: trade_id,
            timestamp: quote[:date],
            type: order.type,
            mode: order.mode,
            quantity: order.quantity,
            price: execution.execution_price,
            cfees: App.fees,
            tickcheck: false,
          )

          operation = TradingLife::Operation.new(conn_memory, operation_id)
          if operation.stock.zero?
            new_trade = true
            orders.clear
          else
            trade = TradingSystem::Trade.new(conn_memory, trade_id)
            orders = orders_for(trade)
          end
        end
      end

      private def open_trade(
        trade_count : Int32,
        quote : MarketData::Quote,
        scale : TradingRules::Scale,
        quantity : Int32,
      ) : {PkId, Orders}
        trade_name = "Trade_%02d" % trade_count
        trade_id = TradingSystem::TradeCreator.new(conn_memory).call(
          name: trade_name,
          security_ident: quote_history.isin,
          money: money,
        )

        TradingSystem::SettingsCreator.new(conn_memory).call(
          trade_ident: trade_id,
          scale_ident: scale.id,
          timestamp: quote[:date],
        )

        TradingLife::OperationCreator.new(conn_memory).call(
          trade_ident: trade_id,
          timestamp: quote[:date],
          type: TradingLife::Operation::Type::Buy,
          mode: TradingLife::Operation::Mode::Market,
          quantity: quantity,
          price: quote[:open],
          cfees: App.fees,
          tickcheck: false,
        )

        trade = TradingSystem::Trade.new(conn_memory, trade_id)
        {trade_id, orders_for(trade)}
      end

      private def orders_for(trade : TradingSystem::Trade) : Orders
        # Keep sizing, stoploss risk and profit objectives on the same exact
        # simulation capital, including its cents.
        capital = sizing_policy.as?(CapitalSizingPolicy).try(&.capital)
        TradingSystem::OrderEngine.new(trade, capital: capital).orders(false)
      end
    end
  end
end
