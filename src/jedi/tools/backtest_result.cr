module Jedi
  module Tools
    # Daily valuation reconstructed from quotations and the latest operation
    # known at each quotation date.
    record BacktestValuation,
      timestamp : Time,
      day : Float64,
      stock : Int32,
      investment_cents : Int64,
      fees_cents : Int64,
      gross_gain_cents : Int64,
      net_gain_cents : Int64

    # Immutable view of one completed historical simulation.
    #
    # The simulation itself is stored in the in-memory Jedi database. This
    # object exposes the aggregate values needed by textual and graphical
    # presenters without duplicating the trading rules.
    class BacktestResult
      getter quote_history : QuoteHistory
      getter scale : TradingRules::Scale
      getter security : Exchange::Security
      getter trades : TradingSystem::Trades
      getter operations : TradingLife::Operations
      getter sizing_policy : BacktestSizingPolicy
      getter sizing_events : Array(BacktestSizingEvent)
      getter execution_policy : BacktestExecutionPolicy
      getter execution_events : Array(BacktestExecutionEvent)

      @daily_valuations : Array(BacktestValuation)? = nil
      @indicators : Indicators? = nil

      def initialize(
        @quote_history : QuoteHistory,
        @scale : TradingRules::Scale,
        @security : Exchange::Security,
        @trades : TradingSystem::Trades,
        @operations : TradingLife::Operations,
        @sizing_policy : BacktestSizingPolicy,
        @sizing_events : Array(BacktestSizingEvent),
        @execution_policy : BacktestExecutionPolicy,
        @execution_events : Array(BacktestExecutionEvent),
      )
      end

      # Only technical reports and plots need these statistical diagnostics.
      def indicators : Indicators
        @indicators ||= Indicators.new(quote_history)
      end

      def execution_mode : BacktestExecutionMode
        execution_policy.mode
      end

      def opening_day_policy : BacktestOpeningDayPolicy
        execution_policy.opening_day
      end

      def gap_execution_count : Int32
        execution_events.count { |event| event.gap }
      end

      def conflict_execution_count : Int32
        execution_events.count { |event| event.conflict }
      end

      def opening_day_execution_count : Int32
        execution_events.count { |event| event.opening_day }
      end

      def sizing_mode : BacktestSizingMode
        sizing_policy.mode
      end

      def accepted_sizing_events : Array(BacktestSizingEvent)
        sizing_events.select { |event| event.decision.operable? }
      end

      def rejected_sizing_events : Array(BacktestSizingEvent)
        sizing_events.reject { |event| event.decision.operable? }
      end

      def opening_rejection_count : Int32
        rejected_sizing_events.size
      end

      def first_opening_rejection_date : Time?
        rejected_sizing_events.first?.try(&.timestamp)
      end

      def last_opening_rejection_date : Time?
        rejected_sizing_events.last?.try(&.timestamp)
      end

      def first_accepted_sizing : BacktestSizingDecision?
        accepted_sizing_events.first?.try(&.decision)
      end

      # Compatibility accessor retained for presenters and callers which used
      # the step-A fixed amount. In capital mode it is the actual amount of the
      # first accepted opening.
      def initial_investment : Float64
        first_accepted_sizing.try(&.amount) || 0.0
      end

      def capital_sizing_policy : CapitalSizingPolicy?
        sizing_policy.as?(CapitalSizingPolicy)
      end

      # Reference used by normalized graphical series. It is the requested
      # fixed amount in fixed mode and the dedicated capital in capital mode.
      def reference_capital_cents : Int32
        case policy = sizing_policy
        when FixedAmountSizingPolicy
          (policy.amount * 100.0).round.to_i
        when CapitalSizingPolicy
          (policy.capital * 100.0).round.to_i
        else
          initial_buy_cents
        end
      end

      def trade_count : Int32
        trades.size
      end

      def operation_count : Int32
        operations.size
      end

      def first_operation_date : Time?
        operation = operations.first?
        operation.nil? ? nil : operation.timestamp
      end

      def last_operation_date : Time?
        operation = operations.last?
        operation.nil? ? nil : operation.timestamp
      end

      def num_calendar_days : Int32
        first = first_operation_date
        return 0 if first.nil?
        days = (quote_history.date_last - first).total_days.to_i
        days < 1 ? 1 : days
      end

      def simulation_trading_day_count : Int32
        first = first_operation_date
        return 0 if first.nil?
        quote_history.quotes.count { |quote| quote[:date] >= first }
      end

      def average_operations_per_month : Float64
        days = simulation_trading_day_count
        return 0.0 if days.zero?
        operation_count.to_f / days.to_f * 21.0
      end

      def timeline : String
        monthly = {} of {Int32, Int32} => Int32
        operations.each do |operation|
          key = {operation.timestamp.year, operation.timestamp.month}
          monthly[key] = (monthly[key]? || 0) + 1
        end

        year = quote_history.date_first.year
        month = quote_history.date_first.month
        end_key = {quote_history.date_last.year, quote_history.date_last.month}

        String.build do |io|
          while {year, month} <= end_key
            count = monthly[{year, month}]? || 0
            case count
            when 0    then io << '-'
            when 1..9 then io << count
            else           io << '+'
            end

            month += 1
            if month == 13
              month = 1
              year += 1
            end
          end
        end
      end

      def initial_buy_cents : Int32
        operation = operations.first?
        operation.nil? ? 0 : operation.buy
      end

      def total_buys_cents : Int32
        total = 0
        operations.each { |operation| total += operation.buy }
        total
      end

      def total_sells_cents : Int32
        total = 0
        operations.each { |operation| total += operation.sell }
        total
      end

      def total_fees_cents : Int32
        total = 0
        operations.each { |operation| total += operation.fees }
        total
      end

      def current_investment_cents : Int32
        # Cumulative net purchases minus sales, including settled trades.
        operation = operations.last?
        operation.nil? ? 0 : operation.global_invest
      end

      def maximum_investment_cents : Int32
        # Trades are sequential, so their largest individual peak is the
        # simulation peak. global_invest also carries gains and losses from
        # closed trades and must remain available for cumulative accounting.
        maximum = 0
        operations.each do |operation|
          maximum = operation.trade_invest if operation.trade_invest > maximum
        end
        maximum
      end

      def final_stock : Int32
        operation = operations.last?
        operation.nil? ? 0 : operation.stock
      end

      def portfolio_cents : Int32
        (quote_history.quotes.last[:close] * final_stock * 100.0).round.to_i
      end

      def gross_gain_cents : Int32
        portfolio_cents + total_sells_cents - total_buys_cents
      end

      def net_gain_cents : Int32
        gross_gain_cents - total_fees_cents
      end

      # Performance measures suitable for a multi-trade simulation. The common
      # denominator is the maximum amount of capital actually tied up during
      # the whole backtest, rather than the first purchase of the first trade.
      def gross_return_on_maximum_investment : Float64
        percentage(gross_gain_cents, maximum_investment_cents)
      end

      def net_return_on_maximum_investment : Float64
        percentage(net_gain_cents, maximum_investment_cents)
      end

      def gross_annualized_return : Float64
        annualized_return_for(gross_gain_cents)
      end

      def net_annualized_return : Float64
        annualized_return_for(net_gain_cents)
      end

      def current_investment_to_maximum_percent : Float64
        percentage(current_investment_cents, maximum_investment_cents)
      end

      def capital_utilization_percent : Float64?
        policy = capital_sizing_policy
        return nil if policy.nil? || policy.capital <= 0.0
        maximum_investment_cents.to_f / (policy.capital * 100.0) * 100.0
      end

      # Reconstruct a daily mark-to-market series. global_invest already
      # contains purchases minus sales across all trades, so subtracting it
      # from the current portfolio value yields the cumulative gross result.
      def daily_valuations : Array(BacktestValuation)
        if cached = @daily_valuations
          return cached
        end

        values = [] of BacktestValuation
        operation_items = operations.to_a
        operation_index = 0
        current_stock = 0
        current_investment = 0
        cumulative_fees = 0

        quote_history.quotes.each_with_index do |quote, index|
          while operation_index < operation_items.size &&
                operation_items[operation_index].timestamp <= quote[:date]
            operation = operation_items[operation_index]
            current_stock = operation.stock
            current_investment = operation.global_invest
            cumulative_fees += operation.fees
            operation_index += 1
          end

          portfolio = (quote[:close] * current_stock * 100.0).round.to_i64
          investment = current_investment.to_i64
          fees = cumulative_fees.to_i64
          gross_gain = portfolio - investment

          values << BacktestValuation.new(
            timestamp: quote[:date],
            day: quote_history.trading_days[index],
            stock: current_stock,
            investment_cents: investment,
            fees_cents: fees,
            gross_gain_cents: gross_gain,
            net_gain_cents: gross_gain - fees,
          )
        end

        @daily_valuations = values
      end

      # Compatibility measures retained for callers from step A. They keep the
      # historical denominator: the first purchase of the first trade.
      def gross_fitness : Float64
        ratio(gross_gain_cents, initial_buy_cents)
      end

      def net_fitness : Float64
        ratio(net_gain_cents, initial_buy_cents)
      end

      # Historical accessor retained for compatibility. This is not a cash-flow
      # based XIRR; it is the gross annualized return on maximum investment.
      def annualized_return : Float64
        gross_annualized_return
      end

      def current_investment_ratio : Float64
        ratio(current_investment_cents, initial_buy_cents)
      end

      def maximum_investment_ratio : Float64
        ratio(maximum_investment_cents, initial_buy_cents)
      end

      def final_position : String
        operation = operations.last?
        operation.nil? ? "" : operation.position.to_s
      end

      def quotation_density : Float64
        days = num_calendar_days
        return 0.0 if days.zero?
        simulation_trading_day_count.to_f / days.to_f
      end

      private def annualized_return_for(gain_cents : Int32) : Float64
        maximum = maximum_investment_cents
        days = num_calendar_days
        return 0.0 if maximum <= 0 || days <= 0

        base = (gain_cents + maximum).to_f / maximum.to_f
        return -100.0 if base <= 0.0
        (base ** (365.0 / days.to_f) - 1.0) * 100.0
      end

      private def percentage(numerator : Int32, denominator : Int32) : Float64
        ratio(numerator, denominator) * 100.0
      end

      private def ratio(numerator : Int32, denominator : Int32) : Float64
        return 0.0 if denominator.zero?
        numerator.to_f / denominator.to_f
      end
    end
  end
end
