require "../spec_helper"

private def with_scoring_environment(&)
  JediSpec.with_db do |conn_main|
    conn_memory = DB.connect "sqlite3://%3Amemory%3A"

    previous_simulation = Jedi::App.simulation
    previous_initial_investment = Jedi::App.initial_investment

    begin
      Jedi::App.simulation = Jedi::SimulationMode::FromSeed
      Jedi::App.initial_investment = 1_000
      yield conn_main, conn_memory
    ensure
      Jedi::App.simulation = previous_simulation
      Jedi::App.initial_investment = previous_initial_investment
      conn_memory.close
    end
  end
end

describe Jedi::Tools::Scoring do
  it "evaluates each scale with the unified backtest engine" do
    with_scoring_environment do |conn_main, conn_memory|
      filename = File.expand_path(
        "../fixtures/tools/backtest_quotes.csv",
        __DIR__,
      )
      builder = "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0"

      scoring = Jedi::Tools::Scoring.new(
        conn_main,
        conn_memory,
        filename,
        builder,
      )
      output = scoring.run

      output.should contain(I18n.t("tools.score.compact.raw_title"))
      output.should contain(I18n.t("tools.score.context.security", {
        :name => "Test security", :ticker => "TEST", :isin => "FR4487601001",
      }))
      output.should contain(I18n.t("tools.score.context.opening_amount", {:amount => "1000.00"}))
      output.should contain(I18n.t("tools.score.context.raw_order", {
        :order => I18n.t("tools.score.context.orders.fitness"),
      }))
      output.should contain(I18n.t("tools.score.compact.ratios_note"))
      output.should contain(I18n.t("tools.score.compact.activity_note"))
      scoring.evaluated_results.size.should eq(1)

      score = scoring.evaluated_results.first
      quote_history = Jedi::Tools::QuoteHistory.new(filename, nil, nil)
      simulation = Jedi::Tools::BacktestEngine.new(
        conn_main: conn_main,
        conn_memory: conn_memory,
        quote_history: quote_history,
        scaledef: score.scaledef,
        money: nil,
        sizing_policy: Jedi::Tools::FixedAmountSizingPolicy.new(1_000.0),
        execution_policy: Jedi::Tools::BacktestExecutionPolicy.new,
      ).run

      score.fitness.should be_close(simulation.gross_fitness, 1e-9)
      score.num_avg_oper_month.should be_close(
        simulation.average_operations_per_month,
        1e-9,
      )
      score.maximum_investment_ratio.should be_close(
        simulation.maximum_investment_ratio,
        1e-9,
      )

      performance = score.performance
      performance.known.should be_true
      performance.net_fitness.should be_close(simulation.net_fitness, 1e-9)
      performance.net_return_on_maximum_investment.should be_close(
        simulation.net_return_on_maximum_investment,
        1e-9,
      )
      performance.net_annualized_return.should be_close(
        simulation.net_annualized_return,
        1e-9,
      )
      performance.maximum_investment_cents.should eq(
        simulation.maximum_investment_cents
      )
      performance.total_fees_cents.should eq(simulation.total_fees_cents)
      performance.operation_count.should eq(simulation.operation_count)
      performance.scale_operation_count.should eq(
        simulation.operation_count - simulation.trade_count
      )
    end
  end

  it "reports the actual period after date and record selection" do
    with_scoring_environment do |conn_main, conn_memory|
      filename = File.expand_path("../fixtures/tools/backtest_quotes.csv", __DIR__)
      scoring = Jedi::Tools::Scoring.new(
        conn_main,
        conn_memory,
        filename,
        "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0",
      )

      output = scoring.run(option_records: "l2", option_date: "le:2026-01-06")

      output.should contain(I18n.t("tools.score.context.period", {
        :first => "2026-01-05", :last => "2026-01-06", :days => "2",
      }))
      output.should_not contain("2026-01-02")
      output.should_not contain("2026-01-07")
    end
  end

  it "reports adaptive coverage and the requested budget separately from a complete grid" do
    with_scoring_environment do |conn_main, conn_memory|
      filename = File.expand_path("../fixtures/tools/backtest_quotes.csv", __DIR__)
      scoring = Jedi::Tools::Scoring.new(
        conn_main,
        conn_memory,
        filename,
        "vr:10%,15%,np:3,4,nn:3,ki:15%,kb:1,kd:0.0",
      )

      partial = scoring.run(option_budget: 2)
      partial.should contain(I18n.t("tools.score.context.search", {
        :strategy => "adaptive", :evaluated => "2", :available => "4",
      }))
      partial.should contain(I18n.t("tools.score.context.budget", {:budget => "2"}))
      partial.should contain(I18n.t("tools.score.context.partial_search"))

      complete = scoring.run(option_search: "grid")
      complete.should contain(I18n.t("tools.score.context.search", {
        :strategy => "grid", :evaluated => "4", :available => "4",
      }))
      complete.should_not contain(I18n.t("tools.score.context.budget", {:budget => "2"}))
      complete.should_not contain(I18n.t("tools.score.context.partial_search"))
      scoring.evaluated_results.size.should eq(4)
    end
  end

  it "describes each raw ordering without changing the ordered results" do
    with_scoring_environment do |conn_main, conn_memory|
      filename = File.expand_path("../fixtures/tools/backtest_quotes.csv", __DIR__)
      scoring = Jedi::Tools::Scoring.new(
        conn_main,
        conn_memory,
        filename,
        "vr:10%,15%,np:3,4,nn:3,ki:15%,kb:1,kd:0.0",
      )

      {1 => "fitness", 2 => "activity", 3 => "investment"}.each do |sort, name|
        output = scoring.run(option_sort: sort, option_search: "grid")
        output.should contain(I18n.t("tools.score.context.raw_order", {
          :order => I18n.t("tools.score.context.orders.#{name}"),
        }))
        scoring.evaluated_results.each_cons(2) do |pair|
          comparison = Jedi::Tools::ScoringObjective.new(sort).compare(pair[0], pair[1])
          (comparison <= 0).should be_true
        end
        rows = output.lines.select(&.starts_with?(" ")).select(&.includes?("II:"))
        rows.size.should eq(scoring.evaluated_results.size)
        rows.each_with_index do |row, index|
          row.should contain(scoring.evaluated_results[index].candidate.typed_builder)
        end
      end
    end
  end

  it "prints shared context and metric notes once when both compact rankings are requested" do
    with_scoring_environment do |conn_main, conn_memory|
      filename = File.expand_path("../fixtures/tools/backtest_quotes.csv", __DIR__)
      scoring = Jedi::Tools::Scoring.new(
        conn_main,
        conn_memory,
        filename,
        "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0",
      )

      output = scoring.run(option_ranking: "both")

      output.should contain(I18n.t("tools.score.compact.raw_title"))
      output.should contain(I18n.t("tools.score.compact.title"))
      output.scan("FR4487601001").size.should eq(1)
      output.scan(I18n.t("tools.score.compact.ratios_note")).size.should eq(1)
      output.scan(I18n.t("tools.score.compact.activity_note")).size.should eq(1)
    end
  end

  it "renders an economic study from the same scoring simulations" do
    with_scoring_environment do |conn_main, conn_memory|
      filename = File.expand_path(
        "../fixtures/tools/backtest_quotes.csv",
        __DIR__,
      )
      builder = "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0"

      scoring = Jedi::Tools::Scoring.new(
        conn_main,
        conn_memory,
        filename,
        builder,
      )
      output = scoring.run(
        option_ranking: "raw",
        option_display: "study",
      )

      output.should contain(I18n.t("tools.score.study.raw_title"))
      output.should contain("Test security")
      output.should contain(I18n.t("tools.score.context.period", {
        :first => "2026-01-02", :last => "2026-01-07", :days => "4",
      }))
      output.should contain(I18n.t("tools.score.study.note"))
      output.should contain("15.0")
      scoring.evaluated_results.first.performance.known.should be_true
    end
  end

  it "shows evaluated candidates before Jedi filtering in study mode" do
    with_scoring_environment do |conn_main, conn_memory|
      filename = File.expand_path(
        "../fixtures/tools/backtest_quotes.csv",
        __DIR__,
      )
      builder = "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0"

      scoring = Jedi::Tools::Scoring.new(
        conn_main,
        conn_memory,
        filename,
        builder,
      )
      output = scoring.run(
        option_ranking: "jedi",
        option_display: "study",
      )

      output.should contain(I18n.t("tools.score.study.title"))
      output.should contain(I18n.t("tools.score.context.rankings.jedi"))
      output.should contain(I18n.t("tools.score.context.search_order", {
        :order => I18n.t("tools.score.context.orders.fitness"),
      }))
      output.should_not contain(I18n.t("tools.score.context.raw_order", {
        :order => I18n.t("tools.score.context.orders.fitness"),
      }))
      output.should contain(I18n.t("tools.score.study.evaluated_title"))
      output.should contain("15.0")
    end
  end
end
