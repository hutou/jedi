require "../market_data/spec_helper"

JediMarketSpec.initialize_i18n

private def p2_quotes(
  count : Int32,
  amplitude : Float64,
  cycle : Float64,
  volume : Int64,
) : Array(Jedi::MarketData::Quote)
  first_date = Time.utc(2020, 1, 1)
  previous_close = 100.0
  quotes = Array(Jedi::MarketData::Quote).new(count)

  count.times do |index|
    close = 100.0 + amplitude * Math.sin(2.0 * Math::PI * index.to_f / cycle)
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

  quotes
end

private def p2_profile_item(
  isin : String,
  ticker : String,
  trend : Float64,
  liquidity : Float64,
  atr : Float64,
  swings : Float64,
  drawdown : Float64,
  gaps : Float64,
  step : Float64,
) : Jedi::Tools::ProfileCollectionItem
  metrics = Jedi::Tools::ProfileMetrics.new(
    1_200,
    5.0,
    240.0,
    0,
    0.0,
    0.0,
    liquidity,
    0.0,
    atr,
    60.0,
    swings,
    swings / 2.0,
    drawdown,
    gaps,
    trend,
    0.8,
  )
  good = Jedi::Tools::ProfileAssessment.new(Jedi::Tools::ProfileLevel::Good)
  profile = Jedi::Tools::JediProfile.new(
    metrics,
    good,
    good,
    good,
    good,
    good,
    good,
    Jedi::Tools::ProfileTrend.new(
      Jedi::Tools::ProfileTrendDirection::Positive,
      trend,
      0.8,
    ),
    step,
    6.0,
    [] of Jedi::Tools::ProfileIssue,
    [] of Jedi::Tools::ProfileIssue,
  )

  Jedi::Tools::ProfileCollectionItem.new(
    Jedi::MarketData::SecurityInfo.new(isin, ticker, "#{ticker} security"),
    profile,
  )
end

describe Jedi::Tools::ProfileCollectionSelection do
  it "normalizes the optional group name" do
    selection = Jedi::Tools::ProfileCollectionSelection.new(
      source: "abcbourse",
      universe: "france",
      dataset: "Euronext_A",
      group: "pea",
    )

    selection.group.should eq("PEA")
    selection.database_name.should eq("abcbourse_france")
  end
end

private def p2_seed_security(
  conn : DB::Connection,
  dataset : String,
  security : Jedi::MarketData::SecurityInfo,
  quotes : Array(Jedi::MarketData::Quote),
) : Nil
  security_repository = Jedi::MarketData::SecurityRepository.new(conn)
  quote_repository = Jedi::MarketData::QuoteRepository.new(conn)

  security_repository.insert(security)
  security_repository.link_dataset(security.isin, dataset)
  quotes.each do |quote|
    quote_repository.insert(security.isin, quote)
    quote_repository.link_dataset(dataset, security.isin, quote[:date])
  end
end

private def p2_seed_group(
  conn : DB::Connection,
  code : String,
  isins : Array(String),
) : Nil
  repository = Jedi::MarketData::GroupRepository.new(conn)
  repository.upsert(code, "test", Time.utc(2026, 1, 1), "2026-01-01T00:00:00Z")
  repository.replace_members(code, isins)
end

private def p2_seed_database(
  source : String,
) : Jedi::MarketData::Database
  database = JediMarketSpec.initialized_database(source)

  database.with_connection do |conn|
    conn.transaction do |tx|
      tx_conn = tx.connection

      Jedi::MarketData::DatasetRepository.new(tx_conn).insert(
        "eurolist_a",
        "Eurolist A",
        nil,
        "quotes.csv",
        "labels.csv",
      )

      p2_seed_security(
        tx_conn,
        "eurolist_a",
        Jedi::MarketData::SecurityInfo.new(
          "FR4487601001", "GOOD", "Good security",
        ),
        p2_quotes(1_200, 20.0, 60.0, 1_000_000_i64),
      )

      p2_seed_security(
        tx_conn,
        "eurolist_a",
        Jedi::MarketData::SecurityInfo.new(
          "FR0000000002", "BAD", "Bad security",
        ),
        p2_quotes(1_200, 0.0, 60.0, 0_i64),
      )

      p2_seed_security(
        tx_conn,
        "eurolist_a",
        Jedi::MarketData::SecurityInfo.new(
          "FR0000000003", "OUTSIDE", "Outside group",
        ),
        p2_quotes(1_200, 20.0, 60.0, 1_000_000_i64),
      )

      repository = Jedi::MarketData::SecurityRepository.new(tx_conn)
      empty_security = Jedi::MarketData::SecurityInfo.new(
        "FR0000000004", "EMPTY", "Empty history",
      )
      repository.insert(empty_security)
      repository.link_dataset(empty_security.isin, "eurolist_a")
      p2_seed_group(
        tx_conn,
        "PEA",
        ["FR4487601001", "FR0000000002", "FR0000000004"],
      )

      security_repository = Jedi::MarketData::SecurityRepository.new(tx_conn)
      quote_repository = Jedi::MarketData::QuoteRepository.new(tx_conn)
      date_first, date_last = quote_repository.date_range_for_dataset("eurolist_a")
      Jedi::MarketData::DatasetRepository.new(tx_conn).update_stats(
        "eurolist_a",
        security_repository.count_for_dataset("eurolist_a"),
        quote_repository.count_for_dataset("eurolist_a"),
        date_first,
        date_last,
      )
    end
  end

  database
end

private def p2_updated_freshness_database(
  workspace : JediMarketSpec::Workspace,
  source : String,
) : Jedi::MarketData::Database
  database = JediMarketSpec.initialized_database(source)
  quotes = p2_quotes(1_206, 20.0, 60.0, 1_000_000_i64)
  date = Time.utc(2026, 10, 5)
  (quotes.size - 1).downto(0) do |index|
    while date.day_of_week.saturday? || date.day_of_week.sunday?
      date -= 1.day
    end
    quotes[index] = quotes[index].merge({date: date})
    date -= 1.day
  end

  database.with_connection do |conn|
    conn.transaction do |tx|
      tx_conn = tx.connection
      datasets = Jedi::MarketData::DatasetRepository.new(tx_conn)
      datasets.insert("freshness", "Freshness", nil, "quotes.csv", "labels.csv")
      80.times do |index|
        p2_seed_security(
          tx_conn,
          "freshness",
          Jedi::MarketData::SecurityInfo.new("FR#{(index + 1).to_s.rjust(10, '0')}", "SEC#{index}", "Security #{index}"),
          quotes.first(1_200),
        )
      end
      datasets.update_stats("freshness", 80_i64, 96_000_i64, quotes.first[:date], quotes[1_199][:date])
    end
  end

  labels = workspace.write(
    "freshness_labels.csv",
    String.build do |io|
      io << "ISIN;nom;ticker\n"
      80.times { |index| io << "FR#{(index + 1).to_s.rjust(10, '0')};Security #{index};SEC#{index}\n" }
    end,
  )
  update = workspace.write(
    "freshness_update.csv",
    String.build do |io|
      80.times do |index|
        # 76 current securities, three lagging by 1/2/3 sessions and one ahead.
        last_index = case index
                     when 76 then 1_203
                     when 77 then 1_202
                     when 78 then 1_201
                     when 79 then 1_205
                     else         1_204
                     end
        quotes[1_200..last_index].each do |quote|
          io << "FR#{(index + 1).to_s.rjust(10, '0')}" << ';' << quote[:date].to_s("%Y%m%d") << ';'
          io << quote[:open] << ';' << quote[:high] << ';' << quote[:low] << ';'
          io << quote[:close] << ';' << quote[:volume] << '\n'
        end
      end
    end,
  )
  Jedi::MarketData::DatasetUpdater.new(
    database, "freshness", update, labels,
    date_order: Jedi::MarketData::DateOrder::Ymd,
  ).run
  database
end

private def old_p2_seed_database(
  source : String,
) : Jedi::MarketData::Database
  database = JediMarketSpec.initialized_database(source)

  database.with_connection do |conn|
    Jedi::MarketData::DatasetRepository.new(conn).insert(
      "eurolist_a",
      "Eurolist A",
      nil,
      "quotes.csv",
      "labels.csv",
    )

    p2_seed_security(
      conn,
      "eurolist_a",
      Jedi::MarketData::SecurityInfo.new(
        "FR4487601001", "GOOD", "Good security",
      ),
      p2_quotes(1_200, 20.0, 60.0, 1_000_000_i64),
    )

    p2_seed_security(
      conn,
      "eurolist_a",
      Jedi::MarketData::SecurityInfo.new(
        "FR0000000002", "BAD", "Bad security",
      ),
      p2_quotes(1_200, 0.0, 60.0, 0_i64),
    )

    p2_seed_security(
      conn,
      "eurolist_a",
      Jedi::MarketData::SecurityInfo.new(
        "FR0000000003", "OUTSIDE", "Outside group",
      ),
      p2_quotes(1_200, 20.0, 60.0, 1_000_000_i64),
    )

    repository = Jedi::MarketData::SecurityRepository.new(conn)
    empty_security = Jedi::MarketData::SecurityInfo.new(
      "FR0000000004", "EMPTY", "Empty history",
    )
    repository.insert(empty_security)
    repository.link_dataset(empty_security.isin, "eurolist_a")
    p2_seed_group(
      conn,
      "PEA",
      ["FR4487601001", "FR0000000002", "FR0000000004"],
    )
  end

  database
end

describe Jedi::Tools::ProfileCollectionAnalyzer do
  it "profiles a named group within a dataset one security at a time" do
    JediMarketSpec.with_workspace do
      p2_seed_database("profile_collection")
      selection = Jedi::Tools::ProfileCollectionSelection.new(
        source: "profile_collection",
        universe: "france",
        dataset: "eurolist_a",
        group: "PEA",
      )

      result = Jedi::Tools::ProfileCollectionAnalyzer.new(selection).analyze

      result.selected_count.should eq(3)
      result.analyzed_count.should eq(2)
      result.retained_count.should eq(1)
      result.rejected_count.should eq(1)
      result.failures.size.should eq(1)
      result.items.map { |item| item.security.ticker }.should contain("GOOD")
      result.items.map { |item| item.security.ticker }.should contain("BAD")
      result.items.map { |item| item.security.ticker }.should_not contain("OUTSIDE")
      result.failures.first.security.ticker.should eq("EMPTY")
    end
  end

  it "profiles a whole named group without requiring a dataset" do
    JediMarketSpec.with_workspace do
      p2_seed_database("profile_all_pea")
      selection = Jedi::Tools::ProfileCollectionSelection.new(
        source: "profile_all_pea",
        universe: "france",
        group: "PEA",
      )

      result = Jedi::Tools::ProfileCollectionAnalyzer.new(selection).analyze

      result.selected_count.should eq(3)
      result.analyzed_count.should eq(2)
      result.items.map { |item| item.security.ticker }.should contain("GOOD")
      result.items.map { |item| item.security.ticker }.should contain("BAD")
      result.items.map { |item| item.security.ticker }.should_not contain("OUTSIDE")
      result.failures.first.security.ticker.should eq("EMPTY")

      good = result.items.find { |item| item.security.ticker == "GOOD" }.not_nil!
      bad = result.items.find { |item| item.security.ticker == "BAD" }.not_nil!
    end
  end

  it "deduplicates an explicit list of securities" do
    JediMarketSpec.with_workspace do
      p2_seed_database("profile_idents")
      selection = Jedi::Tools::ProfileCollectionSelection.new(
        source: "profile_idents",
        universe: "france",
        securities: ["GOOD", "GOOD", "OUTSIDE"],
      )

      result = Jedi::Tools::ProfileCollectionAnalyzer.new(selection).analyze

      result.selected_count.should eq(2)
      result.analyzed_count.should eq(2)
      result.items.map { |item| item.security.ticker }.sort.should eq(["GOOD", "OUTSIDE"])
    end
  end

  it "excludes rejected securities from the summary by default" do
    JediMarketSpec.with_workspace do
      p2_seed_database("profile_report")
      selection = Jedi::Tools::ProfileCollectionSelection.new(
        source: "profile_report",
        universe: "france",
        dataset: "eurolist_a",
        group: "PEA",
      )
      result = Jedi::Tools::ProfileCollectionAnalyzer.new(selection).analyze

      default_report = Jedi::Tools::ProfileCollectionReporter.new(result).render
      complete_report = Jedi::Tools::ProfileCollectionReporter.new(
        result,
        Jedi::Tools::ProfileCollectionSort::Ticker,
        nil,
        true,
      ).render

      default_report.should contain("GOOD")
      default_report.should_not contain("BAD")
      default_report.should contain(I18n.t("tools.profile.collection.columns.status"))
      default_report.should contain(I18n.t("tools.profile.collection.labels.analysis_period"))
      default_report.should contain(
        I18n.t("tools.profile.collection.analysis_period_value", {:count => "252"})
      )
      default_report.should contain(I18n.t("tools.profile.collection.labels.liquidity_rule"))
      default_report.should contain(
        I18n.t(
          "tools.profile.collection.liquidity_rule_value",
          {:amount => "100k", :ratio => "30"},
        )
      )
      default_report.should_not contain("Opinion")
      complete_report.should contain("GOOD")
      complete_report.should contain("BAD")
    end
  end

  it "ranks globally by the unweighted sum of the seven transparent criterion ranks" do
    selection = Jedi::Tools::ProfileCollectionSelection.new(
      source: "profile_global_rank",
      universe: "france",
      securities: ["AAA", "BBB"],
    )
    trend_winner = p2_profile_item(
      "FR0000000010", "AAA", 30.0, 100_000.0, 4.0, 1.0, 50.0, 3.0, 5.0,
    )
    balanced_winner = p2_profile_item(
      "FR0000000011", "BBB", 20.0, 1_000_000.0, 2.0, 10.0, 20.0, 0.2, 2.0,
    )
    result = Jedi::Tools::ProfileCollectionResult.new(
      selection,
      2,
      [trend_winner, balanced_winner],
      [] of Jedi::Tools::ProfileCollectionFailure,
    )

    global_report = Jedi::Tools::ProfileCollectionReporter.new(result).render
    trend_report = Jedi::Tools::ProfileCollectionReporter.new(
      result,
      Jedi::Tools::ProfileCollectionSort::Trend,
    ).render
    trend_only_global_report = Jedi::Tools::ProfileCollectionReporter.new(
      result,
      Jedi::Tools::ProfileCollectionSort::Global,
      nil,
      false,
      Jedi::Tools::ProfilePolicy.new,
      1,
    ).render

    global_report.index("BBB").not_nil!.should be < global_report.index("AAA").not_nil!
    trend_report.index("AAA").not_nil!.should be < trend_report.index("BBB").not_nil!
    trend_only_global_report.index("AAA").not_nil!.should be < trend_only_global_report.index("BBB").not_nil!
    global_report.should contain("2/1/1/1/1/1/1")
    global_report.should contain("1/2/2/2/2/2/2")
    global_report.should contain(I18n.t("tools.profile.collection.columns.global_rank"))
    global_report.should contain(I18n.t("tools.profile.collection.columns.criterion_ranks"))
    global_report.should contain(I18n.t("tools.profile.collection.columns.trend"))
    global_report.should_not contain("Global-rank detail")
    trend_only_global_report.should contain("1 | 2/2/2/2/2/2")
    trend_only_global_report.should contain(
      I18n.t("tools.profile.collection.ranking_criteria_value", {:used => "1"})
    )
  end
  it "measures 0/1/2/3-session lags against global freshness after a dataset update" do
    JediMarketSpec.with_workspace do |workspace|
      database = p2_updated_freshness_database(workspace, "profile_freshness")
      dataset = Jedi::MarketData::MarketInfo.new(database).run.datasets.first
      dataset.import_date_last.should eq(Time.utc(2026, 9, 25))
      dataset.current_date_last.should eq(Time.utc(2026, 10, 5))
      dataset.freshness_date_last.should eq(Time.utc(2026, 10, 2))
      selection = Jedi::Tools::ProfileCollectionSelection.new(
        source: "profile_freshness",
        universe: "france",
        securities: ["SEC0", "SEC76", "SEC77", "SEC78", "SEC79"],
      )
      result = Jedi::Tools::ProfileCollectionAnalyzer.new(selection).analyze
      result.failures.should be_empty
      {"SEC0" => 0, "SEC76" => 1, "SEC77" => 2, "SEC78" => 3, "SEC79" => 0}.each do |ticker, lag|
        profile = result.items.find { |item| item.security.ticker == ticker }.not_nil!.profile
        freshness = profile.freshness.not_nil!
        freshness.reference_date.should eq(Time.utc(2026, 10, 2))
        freshness.lag_sessions.should eq(lag)
        profile.rejected?.should eq(lag > 2)
        if lag == 1 || lag == 2
          profile.status.should eq(Jedi::Tools::ProfileStatus::Warning)
          profile.warnings.should contain(Jedi::Tools::ProfileIssue::DelayedQuotation)
        elsif lag > 2
          profile.rejection_reasons.should contain(Jedi::Tools::ProfileIssue::StaleQuotation)
        else
          profile.warnings.should_not contain(Jedi::Tools::ProfileIssue::DelayedQuotation)
        end
      end

      report = Jedi::Tools::ProfileCollectionReporter.new(
        result,
        Jedi::Tools::ProfileCollectionSort::Ticker,
        nil,
        true,
      ).render
      report.should contain(I18n.t("tools.profile.collection.labels.freshness_reference"))
      report.should contain(I18n.t("tools.profile.collection.freshness_reference_value"))
      report.should contain(I18n.t("tools.profile.collection.columns.lag"))
      report.should contain("SEC78")
    end
  end

  it "uses the same validated freshness in the single-security profile" do
    JediMarketSpec.with_workspace do |workspace|
      p2_updated_freshness_database(workspace, "single_profile_freshness")
      JediMarketSpec.initialize_i18n
      input = Jedi::MarketData::DatabaseQuoteHistoryInput.new("single_profile_freshness", "SEC78", "france")
      report = Jedi::Tools::Profile.new(input).run
      reference_line = report.lines.find do |line|
        line.includes?(I18n.t("tools.profile.labels.market_reference_date"))
      end.not_nil!
      reference_line.should contain("2026-10-02")
      lag_line = report.lines.find do |line|
        line.includes?(I18n.t("tools.profile.labels.quote_lag_sessions"))
      end.not_nil!
      lag_line.split.last.should eq("3")
      report.should contain(I18n.t("tools.profile.issues.stale_quotation"))
    end
  end

  it "does not guess a freshness reference when a security belongs to several datasets" do
    JediMarketSpec.with_workspace do
      database = p2_seed_database("profile_ambiguous_dataset")
      database.with_connection do |conn|
        datasets = Jedi::MarketData::DatasetRepository.new(conn)
        datasets.insert(
          "eurolist_b",
          "Eurolist B",
          nil,
          "quotes_b.csv",
          "labels_b.csv",
        )
        Jedi::MarketData::SecurityRepository.new(conn).link_dataset(
          "FR4487601001",
          "eurolist_b",
        )
      end

      selection = Jedi::Tools::ProfileCollectionSelection.new(
        source: "profile_ambiguous_dataset",
        universe: "france",
        securities: ["GOOD"],
      )
      result = Jedi::Tools::ProfileCollectionAnalyzer.new(selection).analyze

      result.items.first.profile.freshness.should be_nil
    end
  end

  it "does not assess freshness for an explicitly filtered historical selection" do
    JediMarketSpec.with_workspace do
      p2_seed_database("profile_historical_freshness")
      selection = Jedi::Tools::ProfileCollectionSelection.new(
        source: "profile_historical_freshness",
        universe: "france",
        securities: ["GOOD", "OUTSIDE"],
      )
      history_selection = Jedi::MarketData::HistorySelection.new(records: "f1000")

      result = Jedi::Tools::ProfileCollectionAnalyzer.new(selection).analyze(
        history_selection,
      )

      result.items.each do |item|
        item.profile.freshness.should be_nil
        item.profile.rejection_reasons.should_not contain(
          Jedi::Tools::ProfileIssue::StaleQuotation
        )
      end

      report = Jedi::Tools::ProfileCollectionReporter.new(result).render
      report.should contain(I18n.t("tools.profile.collection.freshness_unavailable"))
    end
  end
end

it "does not let rejected securities change candidate global ranks" do
  selection = Jedi::Tools::ProfileCollectionSelection.new(
    source: "profile_rejected_rank",
    universe: "france",
    securities: ["AAA", "BBB", "REJ"],
  )
  aaa = p2_profile_item(
    "FR0000000020", "AAA", 20.0, 500_000.0, 3.0, 6.0, 30.0, 1.0, 4.0,
  )
  bbb = p2_profile_item(
    "FR0000000021", "BBB", 10.0, 400_000.0, 3.5, 5.0, 35.0, 1.5, 5.0,
  )
  rejected_base = p2_profile_item(
    "FR0000000022", "REJ", 50.0, 2_000_000.0, 2.5, 12.0, 10.0, 0.0, 3.0,
  )
  rejected_profile = Jedi::Tools::JediProfile.new(
    rejected_base.profile.metrics,
    rejected_base.profile.history_quality,
    rejected_base.profile.liquidity,
    rejected_base.profile.volatility,
    rejected_base.profile.oscillation,
    rejected_base.profile.gap_risk,
    rejected_base.profile.drawdown_risk,
    rejected_base.profile.trend,
    rejected_base.profile.suggested_step_pct,
    rejected_base.profile.estimated_moves_per_year,
    [Jedi::Tools::ProfileIssue::LowLiquidity],
    [] of Jedi::Tools::ProfileIssue,
  )
  rejected = Jedi::Tools::ProfileCollectionItem.new(
    rejected_base.security,
    rejected_profile,
  )
  result = Jedi::Tools::ProfileCollectionResult.new(
    selection,
    3,
    [aaa, bbb, rejected],
    [] of Jedi::Tools::ProfileCollectionFailure,
  )

  default_report = Jedi::Tools::ProfileCollectionReporter.new(result).render
  complete_report = Jedi::Tools::ProfileCollectionReporter.new(
    result,
    Jedi::Tools::ProfileCollectionSort::Global,
    nil,
    true,
  ).render

  aaa_default = default_report.lines.find { |line| line.includes?("AAA") }.not_nil!
  aaa_complete = complete_report.lines.find { |line| line.includes?("AAA") }.not_nil!
  bbb_default = default_report.lines.find { |line| line.includes?("BBB") }.not_nil!
  bbb_complete = complete_report.lines.find { |line| line.includes?("BBB") }.not_nil!
  rejected_line = complete_report.lines.find { |line| line.includes?("REJ") }.not_nil!

  aaa_complete.should eq(aaa_default)
  bbb_complete.should eq(bbb_default)
  rejected_line.lstrip.should start_with("-")
end

describe Jedi::Tools::ProfileCollectionSort do
  it "uses the transparent global rank as the default ordering" do
    Jedi::Tools::ProfileCollectionSort.parse(nil).should eq(
      Jedi::Tools::ProfileCollectionSort::Global
    )
    Jedi::Tools::ProfileCollectionSort.parse("").should eq(
      Jedi::Tools::ProfileCollectionSort::Global
    )
    Jedi::Tools::ProfileCollectionSort.parse("global").should eq(
      Jedi::Tools::ProfileCollectionSort::Global
    )
  end

  it "rejects removed composite rankings" do
    %w(current recent verdict jedi).each do |value|
      expect_raises(Jedi::LowLevelError) do
        Jedi::Tools::ProfileCollectionSort.parse(value)
      end
    end
  end
end
