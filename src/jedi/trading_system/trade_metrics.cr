module Jedi
  module TradingSystem
    class TradeMetrics
      record Data,
        buys : Int32, sells : Int32, fees : Int32, maximum_investment : Int32,
        current_investment : Int32, stock : Int32, operation_count : Int32,
        timeline : String, q0 : Float64, c0 : Float64, position : TradingRules::Position,
        duration : Int32

      private getter trade, now

      def initialize(@trade : TradingSystem::Trade, @now : Time = Time.local)
      end

      def calculate : Data?
        operations = trade.operations
        # At least, one mandatory operation : initial buy !
        return nil if operations.empty?

        max_invest, current_investment, sum_buys, sum_sells, sum_fees = compute_sums(operations)
        last_settings = trade.settings_chain.last
        first_operation = operations.first
        last_operation = operations.last
        lastdata = TradingRules::LastData.new(last_settings, last_operation)
        stock = lastdata.maybe_splitted_stock

        # Number of days between first operation timestamp (initial buy) and
        # either current time or timestamp of last operation if trade is closed (stock = 0)
        duration = ((stock == 0 ? last_operation.timestamp : now) -
                    first_operation.timestamp).total_days.to_i
        # Corner case, but we need to avoid division by 0
        duration = 1 if duration == 0

        tline = timeline(operations)

        Data.new buys: sum_buys, sells: sum_sells, fees: sum_fees,
          maximum_investment: max_invest, current_investment: current_investment, stock: stock,
          operation_count: operations.size, timeline: tline[-[tline.size, 12].min..-1],
          q0: last_settings.q0, c0: last_settings.c0, position: last_operation.position,
          duration: duration
      end

      private def compute_sums(operations)
        max_invest = current_investment = sum_buys = sum_sells = sum_fees = 0
        operations.each do |op|
          sum_buys += op.buy
          sum_sells += op.sell
          sum_fees += op.fees
          current_investment += op.buy - op.sell
          max_invest = [max_invest, current_investment].max
        end
        {max_invest, current_investment, sum_buys, sum_sells, sum_fees}
      end

      private def timeline(operations)
        tline = {} of {Int32, Int32} => Int32
        # Count monthly occurrences
        operations.each do |operation|
          year_month = {operation.timestamp.year, operation.timestamp.month}
          if tline.has_key?(year_month)
            tline[year_month] += 1
          else
            tline[year_month] = 1
          end
        end
        # Build output string for full date range
        year, month = operations.first.timestamp.year, operations.first.timestamp.month
        end_year, end_month = now.year, now.month
        String.build do |str|
          while (year < end_year) ||
                (year == end_year && month <= end_month)
            key = {year, month}
            if tline.has_key?(key)
              if 1 <= tline[key] <= 9
                str << tline[key]
              else
                str << '+'
              end
            else
              str << '-'
            end
            month += 1
            if month == 13
              year += 1
              month = 1
            end
          end
        end
      end
    end
  end
end
