module Jedi
  module Tools
    enum ProfileLevel
      Excellent
      Good
      Acceptable
      Weak
      Poor
      Unknown
    end

    enum ProfileTrendDirection
      StronglyNegative
      Negative
      SlightlyNegative
      Flat
      SlightlyPositive
      Positive
      StronglyPositive
      Unknown
    end

    enum ProfileStatus
      Retained
      Warning
      Rejected
    end

    enum ProfileIssue
      ShortHistory
      SparseHistory
      InvalidOhlc
      ZeroVolume
      FlatClose
      LowLiquidity
      FrequentLowLiquidity
      LowVolatility
      ExcessiveVolatility
      WeakOscillation
      FrequentLargeGaps
      HighDrawdown
      ProlongedDowntrend
      DelayedQuotation
      StaleQuotation
      MissingMetric
    end

    struct ProfileFreshness
      getter last_quote_date : Time
      getter reference_date : Time
      getter lag_sessions : Int32

      def initialize(
        @last_quote_date : Time,
        @reference_date : Time,
        @lag_sessions : Int32,
      )
      end

      def self.from_market_dates(
        last_quote_date : Time,
        market_dates : Array(Time),
      ) : self?
        reference_date = market_dates.last?
        return nil if reference_date.nil?

        lag_sessions = market_dates.count { |date| date > last_quote_date }
        new(last_quote_date, reference_date, lag_sessions)
      end
    end

    struct ProfileAssessment
      getter level : ProfileLevel

      def initialize(@level : ProfileLevel)
      end
    end

    struct ProfileTrend
      getter direction : ProfileTrendDirection
      getter annual_rate_pct : Float64?
      getter r2 : Float64?
      getter rejection_threshold_pct_per_year : Float64?

      def initialize(
        @direction : ProfileTrendDirection,
        @annual_rate_pct : Float64?,
        @r2 : Float64?,
        @rejection_threshold_pct_per_year : Float64? = nil,
      )
      end
    end

    struct ProfileMetrics
      getter quote_count : Int32
      getter history_years : Float64
      getter trading_days_per_year : Float64?
      getter invalid_ohlc_count : Int32
      getter zero_volume_ratio_pct : Float64
      getter flat_close_ratio_pct : Float64?
      getter median_traded_value : Float64?
      getter low_liquidity_ratio_pct : Float64?
      getter atr_pct_20 : Float64?
      getter annual_range_pct : Float64?
      getter swings_5_per_year : Float64?
      getter swings_8_per_year : Float64?
      getter max_drawdown_pct : Float64?
      getter large_gap_ratio_pct_3 : Float64?
      getter trend_pct_per_year : Float64?
      getter trend_r2 : Float64?

      def initialize(
        @quote_count : Int32,
        @history_years : Float64,
        @trading_days_per_year : Float64?,
        @invalid_ohlc_count : Int32,
        @zero_volume_ratio_pct : Float64,
        @flat_close_ratio_pct : Float64?,
        @median_traded_value : Float64?,
        @low_liquidity_ratio_pct : Float64?,
        @atr_pct_20 : Float64?,
        @annual_range_pct : Float64?,
        @swings_5_per_year : Float64?,
        @swings_8_per_year : Float64?,
        @max_drawdown_pct : Float64?,
        @large_gap_ratio_pct_3 : Float64?,
        @trend_pct_per_year : Float64?,
        @trend_r2 : Float64?,
      )
      end
    end

    class JediProfile
      getter metrics : ProfileMetrics
      getter history_quality : ProfileAssessment
      getter liquidity : ProfileAssessment
      getter volatility : ProfileAssessment
      getter oscillation : ProfileAssessment
      getter gap_risk : ProfileAssessment
      getter drawdown_risk : ProfileAssessment
      getter trend : ProfileTrend
      getter suggested_step_pct : Float64?
      getter estimated_moves_per_year : Float64?
      getter rejection_reasons : Array(ProfileIssue)
      getter warnings : Array(ProfileIssue)
      getter freshness : ProfileFreshness?

      def initialize(
        @metrics : ProfileMetrics,
        @history_quality : ProfileAssessment,
        @liquidity : ProfileAssessment,
        @volatility : ProfileAssessment,
        @oscillation : ProfileAssessment,
        @gap_risk : ProfileAssessment,
        @drawdown_risk : ProfileAssessment,
        @trend : ProfileTrend,
        @suggested_step_pct : Float64?,
        @estimated_moves_per_year : Float64?,
        @rejection_reasons : Array(ProfileIssue),
        @warnings : Array(ProfileIssue),
        @freshness : ProfileFreshness? = nil,
      )
      end

      def rejected? : Bool
        !rejection_reasons.empty?
      end

      def status : ProfileStatus
        return ProfileStatus::Rejected if rejected?
        return ProfileStatus::Warning unless warnings.empty?

        ProfileStatus::Retained
      end
    end
  end
end
