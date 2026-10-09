module Jedi
  module Tools
    class ProfileAnalyzer
      getter history : MarketData::QuoteHistory
      getter policy : ProfilePolicy
      getter freshness : ProfileFreshness?

      def initialize(
        @history : MarketData::QuoteHistory,
        @policy : ProfilePolicy = ProfilePolicy.new,
        @freshness : ProfileFreshness? = nil,
      )
      end

      def analyze : JediProfile
        metrics = build_metrics
        rejection_reasons = build_rejection_reasons(metrics)
        warnings = build_warnings(metrics, rejection_reasons)
        suggested_step, estimated_moves = suggest_step

        history_quality = assess_history(metrics)
        liquidity = assess_liquidity(metrics)
        volatility = assess_volatility(metrics)
        oscillation = assess_oscillation(metrics)
        gap_risk = assess_gap_risk(metrics)
        drawdown_risk = assess_drawdown_risk(metrics)
        trend = assess_trend(metrics)

        JediProfile.new(
          metrics,
          history_quality,
          liquidity,
          volatility,
          oscillation,
          gap_risk,
          drawdown_risk,
          trend,
          suggested_step,
          estimated_moves,
          rejection_reasons,
          warnings,
          freshness,
        )
      end

      private def build_metrics : ProfileMetrics
        ProfileMetrics.new(
          history.quote_count,
          history.history_years,
          history.trading_days_per_year,
          history.invalid_ohlc_count,
          history.zero_volume_ratio_pct,
          history.flat_close_ratio_pct,
          history.median_traded_value(policy.analysis_period_sessions),
          history.low_liquidity_ratio_pct(
            policy.minimum_median_traded_value,
            policy.analysis_period_sessions,
          ),
          history.atr_pct(20),
          history.rolling_range_pct(policy.analysis_period_sessions),
          history.swings_per_year(5.0, policy.analysis_period_sessions),
          history.swings_per_year(8.0, policy.analysis_period_sessions),
          history.max_drawdown_pct(policy.analysis_period_sessions),
          history.large_gap_ratio_pct(3.0, policy.analysis_period_sessions),
          history.linear_trend_pct_per_year(policy.analysis_period_sessions),
          history.trend_r2(policy.analysis_period_sessions),
        )
      end

      private def build_rejection_reasons(metrics : ProfileMetrics) : Array(ProfileIssue)
        reasons = [] of ProfileIssue

        reasons << ProfileIssue::ShortHistory if metrics.history_years < policy.minimum_history_years

        if value = metrics.trading_days_per_year
          reasons << ProfileIssue::SparseHistory if value < policy.minimum_trading_days_per_year
        else
          reasons << ProfileIssue::MissingMetric
        end

        reasons << ProfileIssue::InvalidOhlc if metrics.invalid_ohlc_count > policy.maximum_invalid_ohlc_count

        reasons << ProfileIssue::ZeroVolume if metrics.zero_volume_ratio_pct > policy.maximum_zero_volume_ratio_pct

        if value = metrics.flat_close_ratio_pct
          reasons << ProfileIssue::FlatClose if value > policy.maximum_flat_close_ratio_pct
        else
          reasons << ProfileIssue::MissingMetric
        end

        if value = metrics.median_traded_value
          reasons << ProfileIssue::LowLiquidity if value < policy.minimum_median_traded_value
        else
          reasons << ProfileIssue::MissingMetric
        end

        if value = metrics.atr_pct_20
          reasons << ProfileIssue::LowVolatility if value < policy.minimum_atr_pct_20
        else
          reasons << ProfileIssue::MissingMetric
        end

        if value = metrics.trend_pct_per_year
          if value <= policy.downtrend_rejection_threshold_pct_per_year
            reasons << ProfileIssue::ProlongedDowntrend
          end
        else
          reasons << ProfileIssue::MissingMetric
        end

        if current = freshness
          if current.lag_sessions > policy.maximum_quote_lag_sessions
            reasons << ProfileIssue::StaleQuotation
          end
        end

        reasons.uniq
      end

      private def build_warnings(
        metrics : ProfileMetrics,
        rejection_reasons : Array(ProfileIssue),
      ) : Array(ProfileIssue)
        warnings = [] of ProfileIssue

        if value = metrics.low_liquidity_ratio_pct
          warnings << ProfileIssue::FrequentLowLiquidity if value > policy.maximum_low_liquidity_ratio_pct
        end

        if value = metrics.atr_pct_20
          warnings << ProfileIssue::ExcessiveVolatility if value > policy.high_atr_warning_threshold_pct_20
        end

        if value = metrics.swings_5_per_year
          warnings << ProfileIssue::WeakOscillation if value < policy.minimum_swings_5_per_year_warning
        end

        if value = metrics.large_gap_ratio_pct_3
          warnings << ProfileIssue::FrequentLargeGaps if value > policy.maximum_large_gap_ratio_pct_3_warning
        end

        if value = metrics.max_drawdown_pct
          warnings << ProfileIssue::HighDrawdown if value > policy.maximum_drawdown_pct_warning
        end

        if current = freshness
          if current.lag_sessions > 0 &&
             current.lag_sessions <= policy.maximum_quote_lag_sessions
            warnings << ProfileIssue::DelayedQuotation
          end
        end

        warnings.uniq
      end

      private def assess_history(metrics : ProfileMetrics) : ProfileAssessment
        level = if metrics.invalid_ohlc_count > policy.maximum_invalid_ohlc_count
                  ProfileLevel::Poor
                elsif metrics.history_years < policy.minimum_history_years
                  ProfileLevel::Poor
                elsif value = metrics.trading_days_per_year
                  if value < policy.minimum_trading_days_per_year
                    ProfileLevel::Poor
                  elsif metrics.history_years >= 5.0
                    ProfileLevel::Excellent
                  else
                    ProfileLevel::Good
                  end
                else
                  ProfileLevel::Unknown
                end

        ProfileAssessment.new(level)
      end

      private def assess_liquidity(metrics : ProfileMetrics) : ProfileAssessment
        median = metrics.median_traded_value
        low_ratio = metrics.low_liquidity_ratio_pct

        level = if median.nil? || low_ratio.nil?
                  ProfileLevel::Unknown
                elsif median < policy.minimum_median_traded_value ||
                      metrics.zero_volume_ratio_pct > policy.maximum_zero_volume_ratio_pct
                  ProfileLevel::Poor
                elsif median >= 1_000_000.0 && low_ratio <= 5.0
                  ProfileLevel::Excellent
                elsif median >= 500_000.0 && low_ratio <= 15.0
                  ProfileLevel::Good
                elsif median >= 250_000.0 && low_ratio <= policy.maximum_low_liquidity_ratio_pct
                  ProfileLevel::Acceptable
                else
                  ProfileLevel::Weak
                end

        ProfileAssessment.new(level)
      end

      private def assess_volatility(metrics : ProfileMetrics) : ProfileAssessment
        value = metrics.atr_pct_20
        level = if value.nil?
                  ProfileLevel::Unknown
                elsif value < policy.minimum_atr_pct_20
                  ProfileLevel::Poor
                elsif 2.0 <= value && value <= 5.0
                  ProfileLevel::Good
                elsif 1.5 <= value && value <= 6.0
                  ProfileLevel::Acceptable
                elsif 1.0 <= value && value <= 8.0
                  ProfileLevel::Weak
                else
                  ProfileLevel::Poor
                end

        ProfileAssessment.new(level)
      end

      private def assess_oscillation(metrics : ProfileMetrics) : ProfileAssessment
        swings = metrics.swings_5_per_year
        range = metrics.annual_range_pct

        level = if swings.nil? || range.nil?
                  ProfileLevel::Unknown
                elsif swings >= 8.0 && 40.0 <= range && range <= 100.0
                  ProfileLevel::Excellent
                elsif swings >= 4.0 && 40.0 <= range && range <= 100.0
                  ProfileLevel::Good
                elsif swings >= 3.0 && 30.0 <= range && range <= 120.0
                  ProfileLevel::Acceptable
                elsif swings >= 1.0
                  ProfileLevel::Weak
                else
                  ProfileLevel::Poor
                end

        ProfileAssessment.new(level)
      end

      private def assess_gap_risk(metrics : ProfileMetrics) : ProfileAssessment
        value = metrics.large_gap_ratio_pct_3
        level = if value.nil?
                  ProfileLevel::Unknown
                elsif value <= 0.5
                  ProfileLevel::Excellent
                elsif value <= 1.5
                  ProfileLevel::Good
                elsif value <= 3.0
                  ProfileLevel::Acceptable
                elsif value <= 5.0
                  ProfileLevel::Weak
                else
                  ProfileLevel::Poor
                end

        ProfileAssessment.new(level)
      end

      private def assess_drawdown_risk(metrics : ProfileMetrics) : ProfileAssessment
        value = metrics.max_drawdown_pct
        level = if value.nil?
                  ProfileLevel::Unknown
                elsif value <= 25.0
                  ProfileLevel::Excellent
                elsif value <= 35.0
                  ProfileLevel::Good
                elsif value <= 45.0
                  ProfileLevel::Acceptable
                elsif value <= 60.0
                  ProfileLevel::Weak
                else
                  ProfileLevel::Poor
                end

        ProfileAssessment.new(level)
      end

      private def assess_trend(metrics : ProfileMetrics) : ProfileTrend
        value = metrics.trend_pct_per_year
        direction = if value.nil?
                      ProfileTrendDirection::Unknown
                    elsif value <= -30.0
                      ProfileTrendDirection::StronglyNegative
                    elsif value <= -12.0
                      ProfileTrendDirection::Negative
                    elsif value <= -3.0
                      ProfileTrendDirection::SlightlyNegative
                    elsif value < 3.0
                      ProfileTrendDirection::Flat
                    elsif value < 12.0
                      ProfileTrendDirection::SlightlyPositive
                    elsif value < 30.0
                      ProfileTrendDirection::Positive
                    else
                      ProfileTrendDirection::StronglyPositive
                    end

        ProfileTrend.new(
          direction,
          value,
          metrics.trend_r2,
          policy.downtrend_rejection_threshold_pct_per_year,
        )
      end

      private def suggest_step : {Float64?, Float64?}
        atr = history.atr_pct(20)
        midpoint = (policy.target_moves_per_year_min + policy.target_moves_per_year_max) / 2.0

        candidates = [] of Tuple(Float64, Float64, Float64)
        policy.step_candidates_pct.each do |step|
          moves = history.swings_per_year(step, policy.analysis_period_sessions)
          next if moves.nil?

          gap_ratio = history.large_gap_ratio_pct(step, policy.analysis_period_sessions) || 0.0
          next if atr && step < atr * 1.25
          next if gap_ratio > 3.0

          penalty = (moves - midpoint).abs
          if moves < policy.target_moves_per_year_min
            penalty += (policy.target_moves_per_year_min - moves) * 2.0
          elsif moves > policy.target_moves_per_year_max
            penalty += (moves - policy.target_moves_per_year_max) * 2.0
          end

          candidates << {step, moves, penalty}
        end

        return {nil, nil} if candidates.empty?

        selected = candidates.min_by { |candidate| candidate[2] }
        {selected[0], selected[1]}
      end
    end
  end
end
