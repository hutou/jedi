module Jedi
  module Tools
    class ProfileReporter
      getter history : MarketData::QuoteHistory
      getter profile : JediProfile
      getter source_description : String
      getter policy : ProfilePolicy

      def initialize(
        @history : MarketData::QuoteHistory,
        @profile : JediProfile,
        @source_description : String,
        @policy : ProfilePolicy = ProfilePolicy.new,
      )
      end

      def render : String
        String.build do |io|
          io << I18n.t("tools.profile.title") << '\n'
          io << separator << '\n'
          line(io, "tools.profile.labels.security", security_label)
          line(io, "tools.profile.labels.source", source_description)
          line(io, "tools.profile.labels.period", period_label)
          line(io, "tools.profile.labels.analysis_period", analysis_period_label)
          line(io, "tools.profile.labels.quotations", profile.metrics.quote_count.to_s)
          io << '\n'

          section(io, "tools.profile.sections.history")
          assessment_line(io, "tools.profile.labels.history_quality", profile.history_quality)
          metric_line(io, "tools.profile.labels.history_years", profile.metrics.history_years, 2, "tools.profile.units.years")
          metric_line(io, "tools.profile.labels.trading_days_per_year", profile.metrics.trading_days_per_year, 1)
          integer_line(io, "tools.profile.labels.invalid_ohlc", profile.metrics.invalid_ohlc_count)
          metric_line(io, "tools.profile.labels.zero_volume", profile.metrics.zero_volume_ratio_pct, 2, "tools.profile.units.percent")
          metric_line(io, "tools.profile.labels.flat_close", profile.metrics.flat_close_ratio_pct, 2, "tools.profile.units.percent")
          metric_line(io, "tools.profile.labels.minimum_history_years", policy.minimum_history_years, 1, "tools.profile.units.years")
          metric_line(io, "tools.profile.labels.minimum_trading_days_per_year", policy.minimum_trading_days_per_year, 0)
          integer_line(io, "tools.profile.labels.maximum_invalid_ohlc", policy.maximum_invalid_ohlc_count)
          metric_line(io, "tools.profile.labels.maximum_zero_volume", policy.maximum_zero_volume_ratio_pct, 1, "tools.profile.units.percent")
          metric_line(io, "tools.profile.labels.maximum_flat_close", policy.maximum_flat_close_ratio_pct, 1, "tools.profile.units.percent")
          freshness_lines(io)
          io << '\n'

          section(io, "tools.profile.sections.liquidity")
          assessment_line(io, "tools.profile.labels.liquidity", profile.liquidity)
          money_line(io, "tools.profile.labels.median_traded_value", profile.metrics.median_traded_value)
          money_line(
            io,
            "tools.profile.labels.minimum_median_traded_value",
            policy.minimum_median_traded_value,
          )
          metric_line(io, "tools.profile.labels.low_liquidity_ratio", profile.metrics.low_liquidity_ratio_pct, 2, "tools.profile.units.percent")
          metric_line(
            io,
            "tools.profile.labels.maximum_low_liquidity_ratio",
            policy.maximum_low_liquidity_ratio_pct,
            2,
            "tools.profile.units.percent",
          )
          io << '\n'

          section(io, "tools.profile.sections.potential")
          assessment_line(io, "tools.profile.labels.volatility", profile.volatility)
          metric_line(io, "tools.profile.labels.atr20", profile.metrics.atr_pct_20, 2, "tools.profile.units.percent")
          metric_line(
            io,
            "tools.profile.labels.minimum_atr20",
            policy.minimum_atr_pct_20,
            2,
            "tools.profile.units.percent",
          )
          metric_line(
            io,
            "tools.profile.labels.high_atr_warning_threshold",
            policy.high_atr_warning_threshold_pct_20,
            2,
            "tools.profile.units.percent",
          )
          assessment_line(io, "tools.profile.labels.oscillation", profile.oscillation)
          metric_line(io, "tools.profile.labels.annual_range", profile.metrics.annual_range_pct, 2, "tools.profile.units.percent")
          metric_line(io, "tools.profile.labels.swings5", profile.metrics.swings_5_per_year, 2, "tools.profile.units.per_year")
          metric_line(
            io,
            "tools.profile.labels.minimum_swings5_warning",
            policy.minimum_swings_5_per_year_warning,
            1,
            "tools.profile.units.per_year",
          )
          metric_line(io, "tools.profile.labels.swings8", profile.metrics.swings_8_per_year, 2, "tools.profile.units.per_year")
          io << '\n'

          section(io, "tools.profile.sections.risk")
          assessment_line(io, "tools.profile.labels.gap_risk", profile.gap_risk)
          metric_line(io, "tools.profile.labels.large_gap_ratio", profile.metrics.large_gap_ratio_pct_3, 2, "tools.profile.units.percent")
          metric_line(
            io,
            "tools.profile.labels.maximum_large_gap_warning",
            policy.maximum_large_gap_ratio_pct_3_warning,
            1,
            "tools.profile.units.percent",
          )
          assessment_line(io, "tools.profile.labels.drawdown_risk", profile.drawdown_risk)
          metric_line(io, "tools.profile.labels.max_drawdown", profile.metrics.max_drawdown_pct, 2, "tools.profile.units.percent")
          metric_line(
            io,
            "tools.profile.labels.maximum_drawdown_warning",
            policy.maximum_drawdown_pct_warning,
            1,
            "tools.profile.units.percent",
          )
          io << '\n'

          section(io, "tools.profile.sections.trend")
          line(io, "tools.profile.labels.trend", trend_label)
          metric_line(io, "tools.profile.labels.trend_rate", profile.trend.annual_rate_pct, 2, "tools.profile.units.percent_per_year")
          metric_line(
            io,
            "tools.profile.labels.downtrend_rejection_threshold",
            profile.trend.rejection_threshold_pct_per_year,
            2,
            "tools.profile.units.percent_per_year",
          )
          metric_line(io, "tools.profile.labels.trend_r2", profile.trend.r2, 4)
          io << '\n'

          section(io, "tools.profile.sections.summary")
          metric_line(io, "tools.profile.labels.suggested_step", profile.suggested_step_pct, 2, "tools.profile.units.percent")
          metric_line(io, "tools.profile.labels.estimated_moves", profile.estimated_moves_per_year, 2, "tools.profile.units.per_year")
          line(io, "tools.profile.labels.status", status_label)

          unless profile.rejection_reasons.empty?
            io << '\n'
            section(io, "tools.profile.sections.rejection_reasons")
            profile.rejection_reasons.each do |issue|
              io << "  - " << issue_label(issue) << '\n'
            end
          end

          unless profile.warnings.empty?
            io << '\n'
            section(io, "tools.profile.sections.warnings")
            profile.warnings.each do |issue|
              io << "  - " << issue_label(issue) << '\n'
            end
          end
        end.rstrip
      end

      private def security_label : String
        ticker = history.ticker.empty? ? "" : " (#{history.ticker})"
        "#{history.isin} - #{history.name}#{ticker}"
      end

      private def period_label : String
        "#{history.date_first.to_s("%Y-%m-%d")} -> #{history.date_last.to_s("%Y-%m-%d")}"
      end

      private def analysis_period_label : String
        quotes = history.quotes.last(policy.analysis_period_sessions)
        I18n.t(
          "tools.profile.analysis_period_value",
          {
            :count => quotes.size.to_s,
            :start => quotes.first[:date].to_s("%Y-%m-%d"),
            :end   => quotes.last[:date].to_s("%Y-%m-%d"),
          },
        )
      end

      private def freshness_lines(io : IO) : Nil
        if freshness = profile.freshness
          line(io, "tools.profile.labels.last_quote_date", freshness.last_quote_date.to_s("%Y-%m-%d"))
          line(io, "tools.profile.labels.market_reference_date", freshness.reference_date.to_s("%Y-%m-%d"))
          integer_line(io, "tools.profile.labels.quote_lag_sessions", freshness.lag_sessions)
          integer_line(io, "tools.profile.labels.maximum_quote_lag_sessions", policy.maximum_quote_lag_sessions)
        else
          line(io, "tools.profile.labels.freshness", I18n.t("tools.profile.freshness.unavailable"))
        end
      end

      private def assessment_line(
        io : IO,
        key : String,
        assessment : ProfileAssessment,
      ) : Nil
        line(io, key, level_label(assessment.level))
      end

      private def metric_line(
        io : IO,
        key : String,
        value : Float64?,
        decimals : Int32,
        unit_key : String? = nil,
      ) : Nil
        rendered = if value.nil?
                     unavailable
                   else
                     text = value.round(decimals).to_s
                     unit_key.nil? ? text : "#{text} #{I18n.t(unit_key)}"
                   end
        line(io, key, rendered)
      end

      private def integer_line(io : IO, key : String, value : Int32) : Nil
        line(io, key, value.to_s)
      end

      private def money_line(io : IO, key : String, value : Float64?) : Nil
        rendered = value.nil? ? unavailable : "%.0f %s" % [value, I18n.t("tools.profile.units.currency")]
        line(io, key, rendered)
      end

      private def line(io : IO, key : String, value : String) : Nil
        io << "%-34s %s" % [I18n.t(key), value] << '\n'
      end

      private def section(io : IO, key : String) : Nil
        io << I18n.t(key) << '\n'
      end

      private def separator : String
        "-" * 72
      end

      private def unavailable : String
        I18n.t("tools.profile.unavailable")
      end

      private def level_label(level : ProfileLevel) : String
        I18n.t("tools.profile.levels.#{level.to_s.downcase}")
      end

      private def trend_label : String
        I18n.t("tools.profile.trends.#{trend_key(profile.trend.direction)}")
      end

      private def trend_key(direction : ProfileTrendDirection) : String
        case direction
        when ProfileTrendDirection::StronglyNegative
          "strongly_negative"
        when ProfileTrendDirection::Negative
          "negative"
        when ProfileTrendDirection::SlightlyNegative
          "slightly_negative"
        when ProfileTrendDirection::Flat
          "flat"
        when ProfileTrendDirection::SlightlyPositive
          "slightly_positive"
        when ProfileTrendDirection::Positive
          "positive"
        when ProfileTrendDirection::StronglyPositive
          "strongly_positive"
        else
          "unknown"
        end
      end

      private def status_label : String
        I18n.t("tools.profile.statuses.#{profile.status.to_s.downcase}")
      end

      private def issue_label(issue : ProfileIssue) : String
        key = case issue
              when ProfileIssue::ShortHistory
                "short_history"
              when ProfileIssue::SparseHistory
                "sparse_history"
              when ProfileIssue::InvalidOhlc
                "invalid_ohlc"
              when ProfileIssue::ZeroVolume
                "zero_volume"
              when ProfileIssue::FlatClose
                "flat_close"
              when ProfileIssue::LowLiquidity
                "low_liquidity"
              when ProfileIssue::FrequentLowLiquidity
                "frequent_low_liquidity"
              when ProfileIssue::LowVolatility
                "low_volatility"
              when ProfileIssue::ExcessiveVolatility
                "excessive_volatility"
              when ProfileIssue::WeakOscillation
                "weak_oscillation"
              when ProfileIssue::FrequentLargeGaps
                "frequent_large_gaps"
              when ProfileIssue::HighDrawdown
                "high_drawdown"
              when ProfileIssue::ProlongedDowntrend
                "prolonged_downtrend"
              when ProfileIssue::DelayedQuotation
                "delayed_quotation"
              when ProfileIssue::StaleQuotation
                "stale_quotation"
              else
                "missing_metric"
              end
        I18n.t("tools.profile.issues.#{key}")
      end
    end
  end
end
