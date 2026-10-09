module Jedi
  module MarketData
    module QuoteHistoryIndicators
      TRADING_DAYS_PER_YEAR = 252.0
      SECONDS_PER_YEAR      = 365.25 * 24.0 * 60.0 * 60.0

      # ----------------------------------------------------------------------
      # 1. Données générales
      # ----------------------------------------------------------------------

      def quote_count : Int32
        quotes.size
      end

      def first_close : Float64
        quotes.first[:close]
      end

      def last_close : Float64
        quotes.last[:close]
      end

      def calendar_days : Float64
        seconds = (date_last - date_first).total_seconds
        seconds / 86_400.0
      end

      def history_years : Float64
        calendar_days / 365.25
      end

      def trading_days_per_year : Float64?
        years = history_years
        return nil if years <= 0.0

        num_trading_days.to_f / years
      end

      def total_return_pct : Float64?
        first = first_close
        last = last_close
        return nil if first <= 0.0

        (last / first - 1.0) * 100.0
      end

      def cagr_pct : Float64?
        first = first_close
        last = last_close
        years = history_years

        return nil if first <= 0.0 || last <= 0.0 || years <= 0.0

        ((last / first) ** (1.0 / years) - 1.0) * 100.0
      end

      # ----------------------------------------------------------------------
      # 2. Qualité des cotations
      # ----------------------------------------------------------------------

      def invalid_ohlc_count : Int32
        quotes.count do |q|
          open = q[:open]
          high = q[:high]
          low = q[:low]
          close = q[:close]

          open <= 0.0 ||
            high <= 0.0 ||
            low <= 0.0 ||
            close <= 0.0 ||
            high < low ||
            open < low ||
            open > high ||
            close < low ||
            close > high
        end
      end

      def zero_volume_ratio_pct : Float64
        return 0.0 if quotes.empty?

        count = quotes.count { |q| q[:volume] <= 0 }
        count.to_f / quotes.size.to_f * 100.0
      end

      def flat_close_ratio_pct : Float64?
        return nil if quotes.size < 2

        flat = 0
        total = 0

        i = 1
        while i < quotes.size
          flat += 1 if quotes[i][:close] == quotes[i - 1][:close]
          total += 1
          i += 1
        end

        flat.to_f / total.to_f * 100.0
      end

      # ----------------------------------------------------------------------
      # 3. Liquidité
      # ----------------------------------------------------------------------

      def volumes : Array(Float64)
        quotes.map { |q| q[:volume].to_f }
      end

      def traded_values(period : Int32? = nil) : Array(Float64)
        selected_quotes = period.nil? ? quotes : quotes.last(period.not_nil!)
        selected_quotes.map { |q| q[:close] * q[:volume].to_f }
      end

      def mean_volume : Float64?
        mean(volumes)
      end

      def median_volume : Float64?
        median(volumes)
      end

      def mean_traded_value(period : Int32? = nil) : Float64?
        mean(traded_values(period))
      end

      def median_traded_value(period : Int32? = nil) : Float64?
        median(traded_values(period))
      end

      def low_liquidity_ratio_pct(
        min_traded_value : Float64,
        period : Int32? = nil,
      ) : Float64?
        values = traded_values(period)
        return nil if values.empty?

        count = values.count { |v| v < min_traded_value }
        count.to_f / values.size.to_f * 100.0
      end

      # ----------------------------------------------------------------------
      # 4. Rendements
      # ----------------------------------------------------------------------

      def returns_pct : Array(Float64)
        result = [] of Float64
        return result if quotes.size < 2

        i = 1
        while i < quotes.size
          previous = quotes[i - 1][:close]
          current = quotes[i][:close]

          result << ((current / previous) - 1.0) * 100.0 if previous > 0.0

          i += 1
        end

        result
      end

      def log_returns : Array(Float64)
        result = [] of Float64
        return result if quotes.size < 2

        i = 1
        while i < quotes.size
          previous = quotes[i - 1][:close]
          current = quotes[i][:close]

          result << Math.log(current / previous) if previous > 0.0 && current > 0.0

          i += 1
        end

        result
      end

      def mean_daily_return_pct : Float64?
        mean(returns_pct)
      end

      def daily_volatility_pct : Float64?
        sd = stddev(log_returns)
        return nil if sd.nil?

        sd * 100.0
      end

      def annualized_volatility_pct : Float64?
        sd = stddev(log_returns)
        return nil if sd.nil?

        sd * Math.sqrt(TRADING_DAYS_PER_YEAR) * 100.0
      end

      # ----------------------------------------------------------------------
      # 5. Amplitude journalière
      # ----------------------------------------------------------------------

      def daily_range_pct_values : Array(Float64)
        values = [] of Float64

        quotes.each do |q|
          close = q[:close]
          next if close <= 0.0

          values << ((q[:high] - q[:low]) / close) * 100.0
        end

        values
      end

      def mean_daily_range_pct : Float64?
        mean(daily_range_pct_values)
      end

      def median_daily_range_pct : Float64?
        median(daily_range_pct_values)
      end

      def percentile_daily_range_pct(p : Float64) : Float64?
        percentile(daily_range_pct_values, p)
      end

      # ----------------------------------------------------------------------
      # 6. ATR
      # ----------------------------------------------------------------------

      def true_ranges : Array(Float64)
        result = [] of Float64
        return result if quotes.empty?

        result << (quotes.first[:high] - quotes.first[:low])

        i = 1
        while i < quotes.size
          q = quotes[i]
          previous_close = quotes[i - 1][:close]

          tr1 = q[:high] - q[:low]
          tr2 = (q[:high] - previous_close).abs
          tr3 = (q[:low] - previous_close).abs

          result << max3(tr1, tr2, tr3)

          i += 1
        end

        result
      end

      def atr(period : Int32 = 20) : Float64?
        return nil if period <= 0

        ranges = true_ranges
        return nil if ranges.size < period

        sum = 0.0
        i = ranges.size - period

        while i < ranges.size
          sum += ranges[i]
          i += 1
        end

        sum / period.to_f
      end

      def atr_pct(period : Int32 = 20) : Float64?
        value = atr(period)
        close = last_close

        return nil if value.nil? || close <= 0.0

        value / close * 100.0
      end

      def suggested_step_pct_from_atr(period : Int32 = 20, multiplier : Float64 = 1.5) : Float64?
        value = atr_pct(period)
        return nil if value.nil?

        value * multiplier
      end

      # ----------------------------------------------------------------------
      # 7. Gaps
      # ----------------------------------------------------------------------

      def gap_pct_values(period : Int32? = nil) : Array(Float64)
        selected = quotes_for_period(period)
        result = [] of Float64
        return result if selected.size < 2

        i = 1
        while i < selected.size
          previous_close = selected[i - 1][:close]
          open = selected[i][:open]

          result << ((open / previous_close) - 1.0) * 100.0 if previous_close > 0.0

          i += 1
        end

        result
      end

      def abs_gap_pct_values(period : Int32? = nil) : Array(Float64)
        gap_pct_values(period).map(&.abs)
      end

      def mean_abs_gap_pct(period : Int32? = nil) : Float64?
        mean(abs_gap_pct_values(period))
      end

      def percentile_abs_gap_pct(p : Float64 = 90.0, period : Int32? = nil) : Float64?
        percentile(abs_gap_pct_values(period), p)
      end

      def large_gap_ratio_pct(
        threshold_pct : Float64 = 3.0,
        period : Int32? = nil,
      ) : Float64?
        gaps = abs_gap_pct_values(period)
        return nil if gaps.empty?

        threshold = threshold_pct.abs
        count = gaps.count { |g| g >= threshold }

        count.to_f / gaps.size.to_f * 100.0
      end

      # ----------------------------------------------------------------------
      # 8. Amplitude de prix
      # ----------------------------------------------------------------------

      def period_high : Float64
        max_value(quotes.map { |q| q[:high] })
      end

      def period_low : Float64
        min_value(quotes.map { |q| q[:low] })
      end

      def price_range_pct : Float64?
        low = period_low
        high = period_high

        return nil if low <= 0.0

        ((high / low) - 1.0) * 100.0
      end

      def current_position_in_range_pct : Float64?
        low = period_low
        high = period_high
        close = last_close

        return nil if high <= low

        (close - low) / (high - low) * 100.0
      end

      def rolling_range_pct(period : Int32) : Float64?
        return nil if period <= 0
        return nil if quotes.size < period

        start = quotes.size - period
        high = quotes[start][:high]
        low = quotes[start][:low]

        i = start + 1
        while i < quotes.size
          high = quotes[i][:high] if quotes[i][:high] > high
          low = quotes[i][:low] if quotes[i][:low] < low
          i += 1
        end

        return nil if low <= 0.0

        ((high / low) - 1.0) * 100.0
      end

      def theoretical_steps_in_range(step_pct : Float64, period : Int32? = nil) : Float64?
        return nil if step_pct <= 0.0

        range = if period.nil?
                  price_range_pct
                else
                  rolling_range_pct(period)
                end

        return nil if range.nil?

        range / step_pct
      end

      # ----------------------------------------------------------------------
      # 9. Drawdown
      # ----------------------------------------------------------------------

      def max_drawdown_pct(period : Int32? = nil) : Float64?
        selected = quotes_for_period(period)
        return nil if selected.empty?

        peak = selected.first[:close]
        return nil if peak <= 0.0

        max_dd = 0.0

        selected.each do |q|
          close = q[:close]
          next if close <= 0.0

          peak = close if close > peak

          dd = (peak - close) / peak * 100.0
          max_dd = dd if dd > max_dd
        end

        max_dd
      end

      def current_drawdown_pct : Float64?
        return nil if quotes.empty?

        peak = quotes.first[:close]

        quotes.each do |q|
          close = q[:close]
          peak = close if close > peak
        end

        return nil if peak <= 0.0

        (peak - last_close) / peak * 100.0
      end

      # ----------------------------------------------------------------------
      # 10. Moyennes mobiles / tendance
      # ----------------------------------------------------------------------

      def sma(period : Int32) : Float64?
        return nil if period <= 0
        return nil if quotes.size < period

        sum = 0.0
        i = quotes.size - period

        while i < quotes.size
          sum += quotes[i][:close]
          i += 1
        end

        sum / period.to_f
      end

      def ma_distance_pct(period : Int32) : Float64?
        average = sma(period)
        return nil if average.nil? || average <= 0.0

        ((last_close / average) - 1.0) * 100.0
      end

      def close_above_sma_ratio_pct(period : Int32) : Float64?
        return nil if period <= 0
        return nil if quotes.size < period

        sum = 0.0

        i = 0
        while i < period
          sum += quotes[i][:close]
          i += 1
        end

        above = 0
        total = 0

        i = period - 1
        while i < quotes.size
          if i > period - 1
            sum += quotes[i][:close]
            sum -= quotes[i - period][:close]
          end

          average = sum / period.to_f
          above += 1 if quotes[i][:close] > average
          total += 1

          i += 1
        end

        above.to_f / total.to_f * 100.0
      end

      def linear_trend_pct_per_year(period : Int32? = nil) : Float64?
        regression = regression_log_close(period)
        return nil if regression.nil?

        (Math.exp(regression[:slope]) - 1.0) * 100.0
      end

      def trend_r2(period : Int32? = nil) : Float64?
        regression = regression_log_close(period)
        return nil if regression.nil?

        regression[:r2]
      end

      # ----------------------------------------------------------------------
      # 11. Oscillations utiles à Jedi
      # ----------------------------------------------------------------------

      def swing_count(threshold_pct : Float64, period : Int32? = nil) : Int32?
        selected = quotes_for_period(period)
        return nil if selected.size < 2
        return nil if threshold_pct <= 0.0

        threshold = threshold_pct.abs

        pivot = selected.first[:close]
        return nil if pivot <= 0.0

        direction = 0
        swings = 0

        i = 1
        while i < selected.size
          close = selected[i][:close]
          i += 1

          next if close <= 0.0

          if direction == 0
            change = ((close / pivot) - 1.0) * 100.0

            if change >= threshold
              direction = 1
              swings += 1
              pivot = close
            elsif change <= -threshold
              direction = -1
              swings += 1
              pivot = close
            end

            next
          end

          if direction > 0
            if close > pivot
              pivot = close
            else
              reversal = ((pivot - close) / pivot) * 100.0

              if reversal >= threshold
                direction = -1
                swings += 1
                pivot = close
              end
            end
          else
            if close < pivot
              pivot = close
            else
              reversal = ((close / pivot) - 1.0) * 100.0

              if reversal >= threshold
                direction = 1
                swings += 1
                pivot = close
              end
            end
          end
        end

        swings
      end

      def swings_per_year(threshold_pct : Float64, period : Int32? = nil) : Float64?
        selected = quotes_for_period(period)
        count = swing_count(threshold_pct, period)
        years = history_years_for(selected)

        return nil if count.nil? || years <= 0.0

        count.to_f / years
      end

      # ----------------------------------------------------------------------
      # Méthodes privées
      # ----------------------------------------------------------------------

      private def mean(values : Array(Float64)) : Float64?
        return nil if values.empty?

        sum = 0.0
        values.each { |v| sum += v }

        sum / values.size.to_f
      end

      private def median(values : Array(Float64)) : Float64?
        return nil if values.empty?

        sorted = values.sort
        n = sorted.size
        mid = n // 2

        if n.odd?
          sorted[mid]
        else
          (sorted[mid - 1] + sorted[mid]) / 2.0
        end
      end

      private def percentile(values : Array(Float64), p : Float64) : Float64?
        return nil if values.empty?

        sorted = values.sort

        clipped = p
        clipped = 0.0 if clipped < 0.0
        clipped = 100.0 if clipped > 100.0

        pos = clipped / 100.0 * (sorted.size - 1).to_f
        low = pos.floor.to_i
        high = pos.ceil.to_i

        return sorted[low] if low == high

        weight = pos - low.to_f
        sorted[low] * (1.0 - weight) + sorted[high] * weight
      end

      private def stddev(values : Array(Float64)) : Float64?
        return nil if values.size < 2

        average = mean(values)
        return nil if average.nil?

        sum = 0.0

        values.each do |v|
          diff = v - average
          sum += diff * diff
        end

        Math.sqrt(sum / (values.size - 1).to_f)
      end

      private def max_value(values : Array(Float64)) : Float64
        max = values.first
        values.each { |v| max = v if v > max }
        max
      end

      private def min_value(values : Array(Float64)) : Float64
        min = values.first
        values.each { |v| min = v if v < min }
        min
      end

      private def max3(a : Float64, b : Float64, c : Float64) : Float64
        max = a > b ? a : b
        c > max ? c : max
      end

      private def quotes_for_period(period : Int32? = nil) : Array(Quote)
        return quotes if period.nil? || period.not_nil! >= quotes.size
        return [] of Quote if period.not_nil! <= 0

        quotes.last(period.not_nil!)
      end

      private def history_years_for(selected : Array(Quote)) : Float64
        return 0.0 if selected.size < 2

        seconds = (selected.last[:date] - selected.first[:date]).total_seconds
        seconds / SECONDS_PER_YEAR
      end

      private def regression_log_close(period : Int32? = nil) : NamedTuple(slope: Float64, r2: Float64)?
        selected = quotes_for_period(period)
        return nil if selected.size < 2

        first_date = selected.first[:date]
        n = 0.0
        sum_x = 0.0
        sum_y = 0.0
        sum_x2 = 0.0
        sum_y2 = 0.0
        sum_xy = 0.0

        selected.each do |q|
          close = q[:close]
          next if close <= 0.0

          x = (q[:date] - first_date).total_seconds / SECONDS_PER_YEAR
          y = Math.log(close)

          n += 1.0
          sum_x += x
          sum_y += y
          sum_x2 += x * x
          sum_y2 += y * y
          sum_xy += x * y
        end

        return nil if n < 2.0

        den_x = n * sum_x2 - sum_x * sum_x
        den_y = n * sum_y2 - sum_y * sum_y
        num = n * sum_xy - sum_x * sum_y

        return nil if den_x == 0.0

        slope = num / den_x

        r2 = if den_y <= 0.0
               0.0
             else
               (num * num) / (den_x * den_y)
             end

        {slope: slope, r2: r2}
      end
    end
  end
end
