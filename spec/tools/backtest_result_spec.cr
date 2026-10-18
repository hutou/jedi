require "../spec_helper"

# Observe optional computation without exposing diagnostic cache state in the CLI.
class Jedi::Tools::BacktestResult
  def indicators_initialized_for_spec? : Bool
    !@indicators.nil?
  end
end

private def with_backtest_result_environment(&)
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

describe Jedi::Tools::BacktestResult do
  it "computes and caches statistics only when a technical consumer requests them" do
    with_backtest_result_environment do |conn_main, conn_memory|
      Jedi.init_i18n("en")
      filename = File.expand_path("../fixtures/tools/backtest_quotes.csv", __DIR__)
      backtest = Jedi::Tools::BackTest.new(
        conn_main, conn_memory, filename,
        "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0", nil,
      )
      backtest.run(option_command: {'r' => ""})
      result = backtest.simulation_result
      result.indicators_initialized_for_spec?.should be_false
      original_gain = result.net_gain_cents
      original_operations = result.operation_count

      technical = Jedi::Tools::BacktestReporter.new(conn_memory, result)
        .render({'r' => ""}, technical: true)

      result.indicators_initialized_for_spec?.should be_true
      technical.should contain("Correlation coefficient")
      indicators = result.indicators
      result.indicators.should be(indicators)
      expected = Jedi::Tools::Indicators.new(result.quote_history)
      indicators.regression_slope.should be_close(expected.regression_slope, 1e-9)
      indicators.volatility.should be_close(expected.volatility, 1e-9)
      result.net_gain_cents.should eq(original_gain)
      result.operation_count.should eq(original_operations)
    end
  end

  it "uses maximum investment for multi-trade performance measures" do
    with_backtest_result_environment do |conn_main, conn_memory|
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
      backtest.run(option_command: {} of Char => String)
      result = backtest.simulation_result

      result.reference_capital_cents.should eq(150_000)
      result.maximum_investment_cents.should be > 0

      expected_gross = result.gross_gain_cents.to_f /
                       result.maximum_investment_cents.to_f * 100.0
      expected_net = result.net_gain_cents.to_f /
                     result.maximum_investment_cents.to_f * 100.0

      result.gross_return_on_maximum_investment.should be_close(
        expected_gross,
        0.000_000_1,
      )
      result.net_return_on_maximum_investment.should be_close(
        expected_net,
        0.000_000_1,
      )
      result.net_annualized_return.should be <= result.gross_annualized_return
      result.capital_utilization_percent.should be_nil
    end
  end

  it "reconstructs daily valuations including sessions before an opening" do
    with_backtest_result_environment do |conn_main, conn_memory|
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
      backtest.run(
        option_command: {} of Char => String,
        option_capital: 1_000.0,
        option_minimum_quantity: 1,
        option_operability_steps: 1,
      )
      result = backtest.simulation_result
      valuations = result.daily_valuations

      valuations.size.should eq(result.quote_history.quotes.size)
      result.simulation_trading_day_count.should eq(2)
      valuations.first.stock.should eq(0)
      valuations.first.investment_cents.should eq(0)
      valuations.first.gross_gain_cents.should eq(0)
      valuations.first.net_gain_cents.should eq(0)
      valuations[1].stock.should be > 0

      last = valuations.last
      last.investment_cents.should eq(result.current_investment_cents)
      last.gross_gain_cents.should eq(result.gross_gain_cents)
      last.net_gain_cents.should eq(result.net_gain_cents)

      result.reference_capital_cents.should eq(100_000)
      result.capital_utilization_percent.should_not be_nil
    end
  end

  it "stores daily monetary valuations beyond the Int32 range" do
    value = Jedi::Tools::BacktestValuation.new(
      timestamp: Time.utc(2026, 1, 1),
      day: 0.0,
      stock: 1,
      investment_cents: 2_147_483_648_i64,
      fees_cents: 0_i64,
      gross_gain_cents: 2_147_483_648_i64,
      net_gain_cents: 2_147_483_648_i64,
    )

    value.investment_cents.should eq(2_147_483_648_i64)
    value.gross_gain_cents.should eq(2_147_483_648_i64)
  end

  it "keeps the largest trade peak after an earlier realized gain" do
    with_backtest_result_environment do |main, memory|
      Jedi::App.capital = 1_000
      Jedi::App.distance = 0.015
      filename = File.expand_path("../fixtures/tools/backtest_sequential_gains.csv", __DIR__)
      backtest = Jedi::Tools::BackTest.new(
        main, memory, filename,
        "kc:1.4,1.2,0.8,0.6,ks:0,1.2,ki:0%,kb:0", nil,
      )
      backtest.run(option_command: {} of Char => String)
      result = backtest.simulation_result

      result.trade_count.should eq(2)
      result.operations.map(&.stock).should eq([100, 0, 100, 120])
      result.operations.map(&.global_invest).should eq([100_000, -20_000, 80_000, 96_000])
      result.trades.map do |trade|
        Jedi::TradingSystem::TradeMetrics.new(trade).calculate.not_nil!.maximum_investment
      end.should eq([100_000, 116_000])
      result.maximum_investment_cents.should eq(116_000)
      result.gross_gain_cents.should eq(6_000)
      result.net_gain_cents.should eq(4_824)
      result.net_return_on_maximum_investment.should be_close(4.158620689655172, JediSpec::EPSILON)

      result.daily_valuations.last.investment_cents.should eq(96_000)
      result.daily_valuations.last.gross_gain_cents.should eq(6_000)
      result.daily_valuations.last.net_gain_cents.should eq(4_824)
    end
  end

  it "shares the trade maximum across compact technical and detailed backtest reports" do
    with_backtest_result_environment do |main, memory|
      Jedi.init_i18n("en")
      Jedi::App.capital = 1_000
      Jedi::App.distance = 0.015
      filename = File.expand_path("../fixtures/tools/backtest_liquidation_gap.csv", __DIR__)
      backtest = Jedi::Tools::BackTest.new(
        main, memory, filename,
        "vr:10%,ks:0.8,1.2,ki:0%,kb:0",
        Jedi::TradingSystem::Money.new(0.015, 1.0, 2),
      )
      compact = backtest.run(option_command: {'r' => ""})
      result = backtest.simulation_result
      reporter = Jedi::Tools::BacktestReporter.new(memory, result)
      detailed = reporter.render({'f' => ""})
      technical = reporter.render({'r' => ""}, technical: true)

      compact.should contain(I18n.t("tools.backtest.compact.maximum_investment", {:value => "1000.00"}))
      technical.should contain("maximum 1000.00")
      total = detailed.lines.find do |line|
        cells = line.split('|')
        cells.size > 11 && cells[2].strip == I18n.t("trade.results.list.table.total")
      end.not_nil!
      total.split('|')[10].strip.should eq("1000.00")
      result.net_return_on_maximum_investment.should be_close(-15.998, JediSpec::EPSILON)
      result.current_investment_cents.should eq(115_000)
      result.daily_valuations.last.net_gain_cents.should eq(-15_998)
    end
  end

  it "lists backtest trade results in creation order while preserving the live return ordering" do
    with_backtest_result_environment do |main, memory|
      Jedi.init_i18n("en")
      Jedi::App.capital = 1_000
      Jedi::App.distance = 0.015
      filename = File.expand_path("../fixtures/tools/backtest_liquidation_gap.csv", __DIR__)
      backtest = Jedi::Tools::BackTest.new(
        main, memory, filename,
        "vr:10%,ks:0.8,1.2,ki:0%,kb:0",
        Jedi::TradingSystem::Money.new(0.015, 1.0, 2),
      )
      output = backtest.run(option_command: {'f' => ""})

      output.index("Trade_01").not_nil!.should be < output.index("Trade_02").not_nil!
      output.should_not contain("↓")

      live = Jedi::TradingSystem::TradeResults.new(memory).list(option_update_now: false)
      live.index("Trade_02").not_nil!.should be < live.index("Trade_01").not_nil!
      live.should contain("↓")
    end
  end
end
