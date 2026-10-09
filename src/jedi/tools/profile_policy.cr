module Jedi
  module Tools
    class ProfilePolicy
      getter minimum_history_years : Float64
      getter minimum_trading_days_per_year : Float64
      getter minimum_median_traded_value : Float64
      getter analysis_period_sessions : Int32
      getter maximum_low_liquidity_ratio_pct : Float64
      getter maximum_zero_volume_ratio_pct : Float64
      getter maximum_flat_close_ratio_pct : Float64
      getter maximum_invalid_ohlc_count : Int32
      getter maximum_quote_lag_sessions : Int32
      getter target_moves_per_year_min : Float64
      getter target_moves_per_year_max : Float64
      getter downtrend_rejection_threshold_pct_per_year : Float64
      getter minimum_atr_pct_20 : Float64
      getter high_atr_warning_threshold_pct_20 : Float64
      getter minimum_swings_5_per_year_warning : Float64
      getter maximum_large_gap_ratio_pct_3_warning : Float64
      getter maximum_drawdown_pct_warning : Float64
      getter step_candidates_pct : Array(Float64)

      def initialize(
        @minimum_history_years : Float64 = 3.0,
        @minimum_trading_days_per_year : Float64 = 180.0,
        @minimum_median_traded_value : Float64 = 100_000.0,
        @analysis_period_sessions : Int32 = 252,
        @maximum_low_liquidity_ratio_pct : Float64 = 30.0,
        @maximum_zero_volume_ratio_pct : Float64 = 5.0,
        @maximum_flat_close_ratio_pct : Float64 = 30.0,
        @maximum_invalid_ohlc_count : Int32 = 0,
        @maximum_quote_lag_sessions : Int32 = 2,
        @target_moves_per_year_min : Float64 = 8.0,
        @target_moves_per_year_max : Float64 = 15.0,
        @downtrend_rejection_threshold_pct_per_year : Float64 = -12.0,
        @minimum_atr_pct_20 : Float64 = 1.5,
        @high_atr_warning_threshold_pct_20 : Float64 = 6.0,
        @minimum_swings_5_per_year_warning : Float64 = 4.0,
        @maximum_large_gap_ratio_pct_3_warning : Float64 = 3.0,
        @maximum_drawdown_pct_warning : Float64 = 45.0,
        @step_candidates_pct : Array(Float64) = [
          3.0, 3.5, 4.0, 4.5, 5.0, 6.0, 7.0, 8.0,
        ],
      )
      end
    end
  end
end
