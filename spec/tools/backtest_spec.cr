require "../spec_helper"

private def with_backtest_environment(&)
  Jedi.init_i18n("en")
  JediSpec.with_db do |conn_main|
    conn_memory = DB.connect "sqlite3://%3Amemory%3A"

    previous_simulation = Jedi::App.simulation
    previous_capital = Jedi::App.capital
    previous_distance = Jedi::App.distance
    previous_risk_rate = Jedi::App.risk_rate
    previous_initial_investment = Jedi::App.initial_investment

    begin
      Jedi::App.simulation = Jedi::SimulationMode::FromSeed
      Jedi::App.capital = 20_000
      Jedi::App.distance = 0.20
      Jedi::App.risk_rate = 0.015
      yield conn_main, conn_memory
    ensure
      Jedi::App.simulation = previous_simulation
      Jedi::App.capital = previous_capital
      Jedi::App.distance = previous_distance
      Jedi::App.risk_rate = previous_risk_rate
      Jedi::App.initial_investment = previous_initial_investment
      conn_memory.close
    end
  end
end

describe Jedi::Tools::BackTest do
  it "preserves the unified fixed-amount reports in technical mode" do
    with_backtest_environment do |conn_main, conn_memory|
      filename = File.expand_path(
        "../fixtures/tools/backtest_quotes.csv",
        __DIR__,
      )

      backtest = Jedi::Tools::BackTest.new(
        conn_main,
        conn_memory,
        filename,
        "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0",
        nil,
      )
      output = backtest.run(
        option_command: {'r' => "", 'f' => ""},
        option_display: "technical",
      )

      output.should contain(I18n.t("tools.backtest.table.title"))
      output.should contain(I18n.t("trade.results.list.table.title.one"))
      output.should_not contain("missing translation")
      backtest.simulation_result.sizing_mode.fixed_amount?.should be_true
      backtest.simulation_result.opening_rejection_count.should eq(0)
      backtest.simulation_result.execution_mode.conservative?.should be_true
      backtest.simulation_result.opening_day_policy.next_session?.should be_true
      backtest.simulation_result.opening_day_execution_count.should eq(0)

      Jedi::TradingSystem::Trades.new(conn_memory).fetch.size.should eq(1)
      Jedi::TradingLife::Operations.new(conn_memory).fetch.size.should be >= 1
    end
  end

  it "reports the actual gross gain fees and net gain in compact mode" do
    with_backtest_environment do |conn_main, conn_memory|
      filename = File.expand_path("../fixtures/tools/backtest_quotes.csv", __DIR__)
      backtest = Jedi::Tools::BackTest.new(
        conn_main, conn_memory, filename,
        "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0", nil,
      )

      output = backtest.run(option_command: {'r' => ""})

      output.should contain("Test security")
      output.should contain(I18n.t("tools.backtest.compact.period", {
        :first => "2026-01-02", :last => "2026-01-07", :days => "4",
      }))
      output.should contain(I18n.t("tools.backtest.compact.first_purchase", {
        :date => "2026-01-02", :quantity => "150", :amount => "1500.00",
      }))
      {
        "gross_gain"         => "60.00",
        "fees"               => "5.25",
        "net_gain"           => "54.75",
        "maximum_investment" => "1500.00",
        "net_return"         => "3.65",
      }.each do |key, value|
        output.should contain(I18n.t("tools.backtest.compact.#{key}", {:value => value}))
      end
      output.should contain(I18n.t("tools.backtest.compact.holdings", {
        :quantity => "150", :value => "1560.00",
      }))
      output.should contain(I18n.t("tools.backtest.compact.note"))
      output.should_not contain("Correlation coefficient")
      output.should_not contain("Annualized return")
      output.should_not contain("missing translation")
    end
  end

  it "uses the selected period and separates the requested amount from the actual purchase" do
    with_backtest_environment do |conn_main, conn_memory|
      filename = File.expand_path("../fixtures/tools/backtest_quotes.csv", __DIR__)
      backtest = Jedi::Tools::BackTest.new(
        conn_main, conn_memory, filename,
        "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0", nil,
      )

      output = backtest.run(
        option_command: {'r' => ""},
        option_records: "l2",
        option_date: "le:2026-01-06",
        option_distance: 0.21,
      )

      output.should contain(I18n.t("tools.backtest.compact.period", {
        :first => "2026-01-05", :last => "2026-01-06", :days => "2",
      }))
      output.should contain(I18n.t("tools.backtest.compact.fixed_amount", {:amount => "1428.00"}))
      output.should contain(I18n.t("tools.backtest.compact.first_purchase", {
        :date => "2026-01-05", :quantity => "142", :amount => "1420.00",
      }))
    end
  end

  it "reports inoperable openings without presenting a fictitious return" do
    with_backtest_environment do |conn_main, conn_memory|
      filename = File.expand_path("../fixtures/tools/backtest_capital_quotes.csv", __DIR__)
      backtest = Jedi::Tools::BackTest.new(
        conn_main, conn_memory, filename,
        "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0",
        Jedi::TradingSystem::Money.new(0.05, 1.0, 2),
      )

      output = backtest.run(
        option_command: {'r' => ""},
        option_capital: 1_000.0,
        option_minimum_quantity: 100_000,
        option_operability_steps: 1,
      )

      output.should contain(I18n.t("tools.backtest.no_trade_opened"))
      output.should contain(I18n.t("tools.backtest.compact.openings", {
        :accepted => "0", :rejected => "3",
      }))
      output.should_not contain(I18n.t("tools.backtest.compact.net_return", {:value => "0.00"}))
      backtest.simulation_result.trade_count.should eq(0)
      backtest.simulation_result.operation_count.should eq(0)
    end
  end

  it "rejects an invalid display before loading quotations or running a simulation" do
    with_backtest_environment do |conn_main, conn_memory|
      backtest = Jedi::Tools::BackTest.new(
        conn_main, conn_memory, "missing-backtest-file.csv",
        "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0", nil,
      )

      error = expect_raises(Jedi::LowLevelError) do
        backtest.run(option_command: {'r' => ""}, option_display: "invalid")
      end

      error.key.should eq("tools.backtest.display.invalid_mode")
      error.kind.should eq(Jedi::LowLevelError::Kind::UserInput)
    end
  end

  it "rejects non-finite simulation capital without changing the configured capital" do
    with_backtest_environment do |main, memory|
      filename = File.expand_path("../fixtures/tools/backtest_quotes.csv", __DIR__)
      backtest = Jedi::Tools::BackTest.new(
        main, memory, filename, "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0",
        Jedi::TradingSystem::Money.new(0.015, 1.0, 2),
      )
      previous_capital = Jedi::App.capital
      [Float64::NAN, Float64::INFINITY].each do |capital|
        error = expect_raises(Jedi::LowLevelError) do
          backtest.run(option_command: {} of Char => String, option_capital: capital)
        end
        error.key.should eq("tools.backtest.invalid_capital")
        error.kind.user_input?.should be_true
        Jedi::App.capital.should eq(previous_capital)
      end
    end
  end

  it "postpones a capital-sized opening until it becomes operable" do
    with_backtest_environment do |conn_main, conn_memory|
      filename = File.expand_path(
        "../fixtures/tools/backtest_capital_quotes.csv",
        __DIR__,
      )
      money = Jedi::TradingSystem::Money.new(0.05, 1.0, 2)

      backtest = Jedi::Tools::BackTest.new(
        conn_main,
        conn_memory,
        filename,
        "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0",
        money,
      )
      output = backtest.run(
        option_command: {'r' => ""},
        option_capital: 1_000.0,
        option_minimum_quantity: 1,
        option_operability_steps: 1,
      )

      result = backtest.simulation_result
      result.sizing_mode.capital?.should be_true
      result.opening_rejection_count.should eq(1)
      result.accepted_sizing_events.size.should eq(1)
      result.first_operation_date.not_nil!.to_s("%Y-%m-%d")
        .should eq("2026-01-05")
      result.first_accepted_sizing.not_nil!.quantity.should be > 0
      output.should contain(I18n.t("tools.backtest.compact.capital", {
        :amount => "1000.00", :risk => "5.00", :steps => "2",
      }))
      output.should contain(I18n.t("tools.backtest.compact.openings", {
        :accepted => "1", :rejected => "1",
      }))
    end
  end

  it "accepts explicit legacy and same-session execution policies" do
    with_backtest_environment do |conn_main, conn_memory|
      filename = File.expand_path(
        "../fixtures/tools/backtest_quotes.csv",
        __DIR__,
      )

      backtest = Jedi::Tools::BackTest.new(
        conn_main,
        conn_memory,
        filename,
        "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0",
        nil,
      )
      backtest.run(
        option_command: {'r' => ""},
        option_execution: "legacy",
        option_opening_day_orders: "same",
      )

      result = backtest.simulation_result
      result.execution_mode.legacy?.should be_true
      result.opening_day_policy.same_session?.should be_true
    end
  end
end
