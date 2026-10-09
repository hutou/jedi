require "../spec_helper"

private def profile_history(
  count : Int32,
  amplitude : Float64,
  cycle : Float64,
  volume : Int64,
  invalid_first_quote : Bool = false,
) : Jedi::MarketData::QuoteHistory
  first_date = Time.utc(2020, 1, 1)
  previous_close = 100.0
  quotes = Array(Jedi::MarketData::Quote).new(count)

  count.times do |index|
    close = 100.0 + amplitude * Math.sin(2.0 * Math::PI * index.to_f / cycle)
    open = index.zero? ? close : previous_close
    high = (open > close ? open : close) * 1.005
    low = (open < close ? open : close) * 0.995

    if invalid_first_quote && index.zero?
      high = close - 1.0
    end

    quotes << {
      date:   first_date + index.days,
      open:   open,
      high:   high,
      low:    low,
      close:  close,
      volume: volume,
    }
    previous_close = close
  end

  security = Jedi::MarketData::SecurityInfo.new(
    "FR4487601001",
    "TEST",
    "Test security",
  )
  Jedi::MarketData::QuoteHistory.new(security, quotes)
end

private def liquidity_profile_history(
  count : Int32,
  recent_period : Int32,
  low_recent_sessions : Int32,
  old_volume : Int64 = 100_i64,
  low_volume : Int64 = 100_i64,
  high_volume : Int64 = 1_000_000_i64,
) : Jedi::MarketData::QuoteHistory
  first_date = Time.utc(2020, 1, 1)
  previous_close = 100.0
  quotes = Array(Jedi::MarketData::Quote).new(count)
  recent_start = count - recent_period

  count.times do |index|
    close = 100.0 + 20.0 * Math.sin(2.0 * Math::PI * index.to_f / 60.0)
    open = index.zero? ? close : previous_close
    high = (open > close ? open : close) * 1.005
    low = (open < close ? open : close) * 0.995

    volume = if index < recent_start
               old_volume
             elsif index - recent_start < low_recent_sessions
               low_volume
             else
               high_volume
             end

    quotes << {
      date:   first_date + index.days,
      open:   open,
      high:   high,
      low:    low,
      close:  close,
      volume: volume,
    }
    previous_close = close
  end

  security = Jedi::MarketData::SecurityInfo.new(
    "FR4487601001",
    "LIQ",
    "Liquidity security",
  )
  Jedi::MarketData::QuoteHistory.new(security, quotes)
end

private def trending_profile_history(
  count : Int32,
  annual_rate_pct : Float64,
  volume : Int64 = 1_000_000_i64,
) : Jedi::MarketData::QuoteHistory
  first_date = Time.utc(2020, 1, 1)
  annual_factor = 1.0 + annual_rate_pct / 100.0
  previous_close = 100.0
  quotes = Array(Jedi::MarketData::Quote).new(count)

  count.times do |index|
    years = index.to_f / 365.0
    close = 100.0 * annual_factor ** years
    open = index.zero? ? close : previous_close
    high = (open > close ? open : close) * 1.005
    low = (open < close ? open : close) * 0.995

    quotes << {
      date:   first_date + index.days,
      open:   open,
      high:   high,
      low:    low,
      close:  close,
      volume: volume,
    }
    previous_close = close
  end

  security = Jedi::MarketData::SecurityInfo.new(
    "FR4487601001",
    "TREND",
    "Trending security",
  )
  Jedi::MarketData::QuoteHistory.new(security, quotes)
end

private def recent_window_profile_history : Jedi::MarketData::QuoteHistory
  first_date = Time.utc(2020, 1, 1)
  previous_close = 300.0
  quotes = Array(Jedi::MarketData::Quote).new(1_200)
  recent_start = 1_200 - 252

  1_200.times do |index|
    close = if index < recent_start
              300.0 - 200.0 * index.to_f / recent_start.to_f
            else
              recent_index = index - recent_start
              100.0 + 30.0 * recent_index.to_f / 251.0 +
                10.0 * Math.sin(2.0 * Math::PI * recent_index.to_f / 30.0)
            end
    open = index.zero? ? close : previous_close
    high = (open > close ? open : close) * 1.005
    low = (open < close ? open : close) * 0.995

    quotes << {
      date:   first_date + index.days,
      open:   open,
      high:   high,
      low:    low,
      close:  close,
      volume: 1_000_000_i64,
    }
    previous_close = close
  end

  security = Jedi::MarketData::SecurityInfo.new(
    "FR4487601001",
    "RECENT",
    "Recent-window security",
  )
  Jedi::MarketData::QuoteHistory.new(security, quotes)
end

describe Jedi::Tools::ProfileAnalyzer do
  it "builds an explainable Jedi profile for an oscillating liquid security" do
    history = profile_history(
      count: 1_200,
      amplitude: 20.0,
      cycle: 60.0,
      volume: 1_000_000_i64,
    )

    profile = Jedi::Tools::ProfileAnalyzer.new(history).analyze

    profile.rejected?.should be_false
    profile.metrics.history_years.should be > 3.0
    profile.metrics.median_traded_value.not_nil!.should be > 100_000.0
    profile.metrics.atr_pct_20.not_nil!.should be > 0.0
    profile.metrics.swings_5_per_year.not_nil!.should be > 4.0
    profile.suggested_step_pct.should_not be_nil
    profile.estimated_moves_per_year.should_not be_nil
    profile.gap_risk.level.should eq(Jedi::Tools::ProfileLevel::Excellent)
    profile.status.should eq(Jedi::Tools::ProfileStatus::Retained)
  end

  it "rejects a short, illiquid and structurally invalid history" do
    history = profile_history(
      count: 400,
      amplitude: 0.0,
      cycle: 60.0,
      volume: 0_i64,
      invalid_first_quote: true,
    )

    profile = Jedi::Tools::ProfileAnalyzer.new(history).analyze

    profile.rejected?.should be_true
    profile.status.should eq(Jedi::Tools::ProfileStatus::Rejected)
    profile.rejection_reasons.should contain(Jedi::Tools::ProfileIssue::ShortHistory)
    profile.rejection_reasons.should contain(Jedi::Tools::ProfileIssue::InvalidOhlc)
    profile.rejection_reasons.should contain(Jedi::Tools::ProfileIssue::ZeroVolume)
    profile.rejection_reasons.should contain(Jedi::Tools::ProfileIssue::FlatClose)
    profile.rejection_reasons.should contain(Jedi::Tools::ProfileIssue::LowLiquidity)
  end

  it "allows the elimination thresholds to be changed explicitly" do
    history = profile_history(
      count: 800,
      amplitude: 15.0,
      cycle: 60.0,
      volume: 2_000_i64,
    )
    policy = Jedi::Tools::ProfilePolicy.new(
      minimum_history_years: 2.0,
      minimum_median_traded_value: 50_000.0,
    )

    profile = Jedi::Tools::ProfileAnalyzer.new(history, policy).analyze

    profile.rejection_reasons.should_not contain(Jedi::Tools::ProfileIssue::ShortHistory)
    profile.rejection_reasons.should_not contain(Jedi::Tools::ProfileIssue::LowLiquidity)
  end

  it "rejects a prolonged downtrend at the existing negative-trend boundary" do
    history = trending_profile_history(1_200, -20.0)

    profile = Jedi::Tools::ProfileAnalyzer.new(history).analyze

    profile.metrics.trend_pct_per_year.not_nil!.should be_close(-20.0, 0.1)
    profile.trend.direction.should eq(Jedi::Tools::ProfileTrendDirection::Negative)
    profile.trend.rejection_threshold_pct_per_year.should eq(-12.0)
    profile.rejected?.should be_true
    profile.status.should eq(Jedi::Tools::ProfileStatus::Rejected)
    profile.rejection_reasons.should contain(
      Jedi::Tools::ProfileIssue::ProlongedDowntrend
    )

    Jedi.init_i18n("fr")
    report = Jedi::Tools::ProfileReporter.new(history, profile, "spec").render
    report.should contain(I18n.t("tools.profile.labels.downtrend_rejection_threshold"))
    report.should contain("-12.0 % par an")
    report.should contain(I18n.t("tools.profile.issues.prolonged_downtrend"))
  end

  it "allows the downtrend rejection threshold to be changed explicitly" do
    history = trending_profile_history(1_200, -20.0)
    policy = Jedi::Tools::ProfilePolicy.new(
      downtrend_rejection_threshold_pct_per_year: -25.0,
      minimum_atr_pct_20: 0.5,
    )

    profile = Jedi::Tools::ProfileAnalyzer.new(history, policy).analyze

    profile.trend.rejection_threshold_pct_per_year.should eq(-25.0)
    profile.rejection_reasons.should_not contain(
      Jedi::Tools::ProfileIssue::ProlongedDowntrend
    )
    profile.rejected?.should be_false
  end
  it "rejects volatility below the explicit ATR20 minimum" do
    history = profile_history(
      count: 1_200,
      amplitude: 0.5,
      cycle: 60.0,
      volume: 1_000_000_i64,
    )

    profile = Jedi::Tools::ProfileAnalyzer.new(history).analyze

    profile.metrics.atr_pct_20.not_nil!.should be < 1.5
    profile.rejected?.should be_true
    profile.rejection_reasons.should contain(Jedi::Tools::ProfileIssue::LowVolatility)

    policy = Jedi::Tools::ProfilePolicy.new(minimum_atr_pct_20: 0.5)
    relaxed = Jedi::Tools::ProfileAnalyzer.new(history, policy).analyze
    relaxed.rejection_reasons.should_not contain(Jedi::Tools::ProfileIssue::LowVolatility)
  end

  it "keeps high volatility as an explicit warning rather than a rejection" do
    history = profile_history(
      count: 1_200,
      amplitude: 40.0,
      cycle: 20.0,
      volume: 1_000_000_i64,
    )

    profile = Jedi::Tools::ProfileAnalyzer.new(history).analyze

    profile.metrics.atr_pct_20.not_nil!.should be > 6.0
    profile.rejection_reasons.should_not contain(Jedi::Tools::ProfileIssue::ExcessiveVolatility)
    profile.warnings.should contain(Jedi::Tools::ProfileIssue::ExcessiveVolatility)

    relaxed_policy = Jedi::Tools::ProfilePolicy.new(
      high_atr_warning_threshold_pct_20: 20.0,
    )
    relaxed = Jedi::Tools::ProfileAnalyzer.new(history, relaxed_policy).analyze
    relaxed.warnings.should_not contain(Jedi::Tools::ProfileIssue::ExcessiveVolatility)

    Jedi.init_i18n("fr")
    report = Jedi::Tools::ProfileReporter.new(history, profile, "spec").render
    report.should contain(I18n.t("tools.profile.labels.minimum_atr20"))
    report.should contain("1.5 %")
    report.should contain(I18n.t("tools.profile.labels.high_atr_warning_threshold"))
    report.should contain("6.0 %")
  end

  it "uses the recent 252-session window for ranking metrics" do
    history = recent_window_profile_history

    history.linear_trend_pct_per_year.not_nil!.should be < -12.0
    history.max_drawdown_pct.not_nil!.should be > 50.0

    profile = Jedi::Tools::ProfileAnalyzer.new(history).analyze

    profile.metrics.history_years.should be > 3.0
    profile.metrics.trend_pct_per_year.not_nil!.should be > -12.0
    profile.metrics.max_drawdown_pct.not_nil!.should be < 50.0
    profile.rejection_reasons.should_not contain(
      Jedi::Tools::ProfileIssue::ProlongedDowntrend
    )

    Jedi.init_i18n("fr")
    report = Jedi::Tools::ProfileReporter.new(history, profile, "spec").render
    report.should contain(I18n.t("tools.profile.labels.analysis_period"))
    recent = history.quotes.last(252)
    report.should contain(
      I18n.t(
        "tools.profile.analysis_period_value",
        {
          :count => recent.size.to_s,
          :start => recent.first[:date].to_s("%Y-%m-%d"),
          :end   => recent.last[:date].to_s("%Y-%m-%d"),
        },
      )
    )
  end

  it "measures profile liquidity over the explicit recent-session period" do
    history = liquidity_profile_history(
      count: 1_200,
      recent_period: 252,
      low_recent_sessions: 0,
    )

    profile = Jedi::Tools::ProfileAnalyzer.new(history).analyze

    profile.metrics.median_traded_value.not_nil!.should be > 1_000_000.0
    profile.metrics.low_liquidity_ratio_pct.not_nil!.should eq(0.0)
    profile.rejection_reasons.should_not contain(Jedi::Tools::ProfileIssue::LowLiquidity)

    full_history_policy = Jedi::Tools::ProfilePolicy.new(
      analysis_period_sessions: 1_200,
    )
    full_history = Jedi::Tools::ProfileAnalyzer.new(
      history,
      full_history_policy,
    ).analyze
    full_history.metrics.median_traded_value.not_nil!.should be < 100_000.0
    full_history.rejection_reasons.should contain(Jedi::Tools::ProfileIssue::LowLiquidity)

    Jedi.init_i18n("fr")
    report = Jedi::Tools::ProfileReporter.new(history, profile, "spec").render
    report.should contain(I18n.t("tools.profile.labels.analysis_period"))
    liquidity_quotes = history.quotes.last(252)
    report.should contain(
      I18n.t(
        "tools.profile.analysis_period_value",
        {
          :count => liquidity_quotes.size.to_s,
          :start => liquidity_quotes.first[:date].to_s("%Y-%m-%d"),
          :end   => liquidity_quotes.last[:date].to_s("%Y-%m-%d"),
        },
      )
    )
    report.should contain(I18n.t("tools.profile.labels.minimum_median_traded_value"))
    report.should contain("100000 €")
    report.should contain(I18n.t("tools.profile.labels.maximum_low_liquidity_ratio"))
    report.should contain("30.0 %")
  end

  it "keeps frequent low-liquidity sessions as a configurable warning" do
    history = liquidity_profile_history(
      count: 1_200,
      recent_period: 252,
      low_recent_sessions: 100,
      old_volume: 1_000_000_i64,
    )

    profile = Jedi::Tools::ProfileAnalyzer.new(history).analyze

    profile.metrics.median_traded_value.not_nil!.should be > 100_000.0
    profile.metrics.low_liquidity_ratio_pct.not_nil!.should be > 30.0
    profile.rejection_reasons.should_not contain(Jedi::Tools::ProfileIssue::LowLiquidity)
    profile.warnings.should contain(Jedi::Tools::ProfileIssue::FrequentLowLiquidity)

    relaxed_policy = Jedi::Tools::ProfilePolicy.new(
      maximum_low_liquidity_ratio_pct: 45.0,
    )
    relaxed = Jedi::Tools::ProfileAnalyzer.new(history, relaxed_policy).analyze
    relaxed.warnings.should_not contain(Jedi::Tools::ProfileIssue::FrequentLowLiquidity)
  end
  it "warns for a quotation one or two market sessions behind" do
    history = profile_history(
      count: 1_200,
      amplitude: 20.0,
      cycle: 60.0,
      volume: 1_000_000_i64,
    )
    freshness = Jedi::Tools::ProfileFreshness.new(
      history.date_last,
      history.date_last + 2.days,
      2,
    )

    profile = Jedi::Tools::ProfileAnalyzer.new(
      history,
      Jedi::Tools::ProfilePolicy.new,
      freshness,
    ).analyze

    profile.rejected?.should be_false
    profile.status.should eq(Jedi::Tools::ProfileStatus::Warning)
    profile.warnings.should contain(Jedi::Tools::ProfileIssue::DelayedQuotation)
    profile.rejection_reasons.should_not contain(
      Jedi::Tools::ProfileIssue::StaleQuotation
    )
  end

  it "rejects a quotation more than two market sessions behind" do
    history = profile_history(
      count: 1_200,
      amplitude: 20.0,
      cycle: 60.0,
      volume: 1_000_000_i64,
    )
    freshness = Jedi::Tools::ProfileFreshness.new(
      history.date_last,
      history.date_last + 3.days,
      3,
    )

    profile = Jedi::Tools::ProfileAnalyzer.new(
      history,
      Jedi::Tools::ProfilePolicy.new,
      freshness,
    ).analyze

    profile.rejected?.should be_true
    profile.rejection_reasons.should contain(
      Jedi::Tools::ProfileIssue::StaleQuotation
    )

    relaxed = Jedi::Tools::ProfileAnalyzer.new(
      history,
      Jedi::Tools::ProfilePolicy.new(maximum_quote_lag_sessions: 3),
      freshness,
    ).analyze
    relaxed.rejection_reasons.should_not contain(
      Jedi::Tools::ProfileIssue::StaleQuotation
    )
    relaxed.warnings.should contain(Jedi::Tools::ProfileIssue::DelayedQuotation)

    Jedi.init_i18n("fr")
    report = Jedi::Tools::ProfileReporter.new(history, profile, "spec").render
    report.should contain(I18n.t("tools.profile.labels.market_reference_date"))
    report.should contain(I18n.t("tools.profile.labels.quote_lag_sessions"))
    report.should contain(I18n.t("tools.profile.issues.stale_quotation"))
  end
  it "keeps rejection reasons separate from warning reasons" do
    history = profile_history(
      count: 400,
      amplitude: 0.0,
      cycle: 60.0,
      volume: 0_i64,
      invalid_first_quote: true,
    )

    profile = Jedi::Tools::ProfileAnalyzer.new(history).analyze

    profile.rejected?.should be_true
    profile.rejection_reasons.should contain(Jedi::Tools::ProfileIssue::ShortHistory)
    profile.warnings.should_not contain(Jedi::Tools::ProfileIssue::ShortHistory)
    profile.warnings.should_not contain(Jedi::Tools::ProfileIssue::InvalidOhlc)
    profile.warnings.should_not contain(Jedi::Tools::ProfileIssue::LowLiquidity)
  end

  it "exposes configurable warning thresholds for oscillation gaps and drawdown" do
    policy = Jedi::Tools::ProfilePolicy.new(
      minimum_swings_5_per_year_warning: 100.0,
      maximum_large_gap_ratio_pct_3_warning: -1.0,
      maximum_drawdown_pct_warning: -1.0,
    )

    policy.minimum_swings_5_per_year_warning.should eq(100.0)
    policy.maximum_large_gap_ratio_pct_3_warning.should eq(-1.0)
    policy.maximum_drawdown_pct_warning.should eq(-1.0)

    history = profile_history(
      count: 1_200,
      amplitude: 20.0,
      cycle: 60.0,
      volume: 1_000_000_i64,
    )
    profile = Jedi::Tools::ProfileAnalyzer.new(history, policy).analyze
    profile.warnings.should contain(Jedi::Tools::ProfileIssue::WeakOscillation)
    profile.warnings.should contain(Jedi::Tools::ProfileIssue::FrequentLargeGaps)
    profile.warnings.should contain(Jedi::Tools::ProfileIssue::HighDrawdown)

    display_policy = Jedi::Tools::ProfilePolicy.new(
      minimum_swings_5_per_year_warning: 5.0,
      maximum_large_gap_ratio_pct_3_warning: 2.0,
      maximum_drawdown_pct_warning: 40.0,
    )
    displayed = Jedi::Tools::ProfileAnalyzer.new(history, display_policy).analyze

    Jedi.init_i18n("fr")
    report = Jedi::Tools::ProfileReporter.new(history, displayed, "spec", display_policy).render
    report.should contain(I18n.t("tools.profile.labels.minimum_swings5_warning"))
    report.should contain("5.0 par an")
    report.should contain(I18n.t("tools.profile.labels.maximum_large_gap_warning"))
    report.should contain("2.0 %")
    report.should contain(I18n.t("tools.profile.labels.maximum_drawdown_warning"))
    report.should contain("40.0 %")
  end
end
