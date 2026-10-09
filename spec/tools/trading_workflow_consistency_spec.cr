require "../spec_helper"

private def with_trading_workflow(&)
  JediSpec.with_db do |main|
    memory = DB.connect("sqlite3://%3Amemory%3A")
    previous_simulation = Jedi::App.simulation
    previous_capital = Jedi::App.capital
    previous_distance = Jedi::App.distance
    previous_risk_rate = Jedi::App.risk_rate
    previous_initial_investment = Jedi::App.initial_investment
    begin
      Jedi.init_i18n("en")
      Jedi::App.simulation = Jedi::SimulationMode::FromSeed
      Jedi::App.capital = 20_000
      Jedi::App.risk_rate = 0.015
      Jedi::App.distance = 0.30
      Jedi::App.initial_investment = 1_000
      yield main, memory
    ensure
      Jedi::App.simulation = previous_simulation
      Jedi::App.capital = previous_capital
      Jedi::App.distance = previous_distance
      Jedi::App.risk_rate = previous_risk_rate
      Jedi::App.initial_investment = previous_initial_investment
      memory.close
    end
  end
end

private def trading_workflow_fixture(name : String) : String
  File.expand_path("../fixtures/tools/#{name}", __DIR__)
end

describe "KISS trading workflow consistency" do
  it "executes the opening sell before the intraday buy and accounts for fees and remaining shares" do
    with_trading_workflow do |main, memory|
      backtest = Jedi::Tools::BackTest.new(
        main, memory, trading_workflow_fixture("backtest_opening_gaps.csv"),
        "vr:10%,ks:0.8,1.2,ki:0%,kb:0", nil,
      )
      backtest.run(option_command: {} of Char => String, option_records: "f2")
      result = backtest.simulation_result

      result.trade_count.should eq(1)
      result.operation_count.should eq(2)
      result.final_stock.should eq(80)
      result.total_buys_cents.should eq(100_000)
      result.total_sells_cents.should eq(24_000)
      result.portfolio_cents.should eq(80_000)
      result.total_fees_cents.should eq(434)
      result.gross_gain_cents.should eq(4_000)
      result.net_gain_cents.should eq(3_566)
      result.maximum_investment_cents.should eq(100_000)
      event = result.execution_events.first
      event.key.should eq(:up)
      event.execution_price.should eq(12.0)
      event.conflict.should be_true
      event.gap.should be_true
      result.daily_valuations.last.net_gain_cents.should eq(3_566)
    end
  end

  it "reopens only on the next session after liquidation and preserves cumulative accounting" do
    with_trading_workflow do |main, memory|
      Jedi::App.capital = 1_000
      history = Jedi::Tools::QuoteHistory.new(trading_workflow_fixture("backtest_liquidation_gap.csv"))
      result = Jedi::Tools::BacktestEngine.new(
        conn_main: main, conn_memory: memory, quote_history: history,
        scaledef: "vr:10%,ks:0.8,1.2,ki:0%,kb:0",
        money: Jedi::TradingSystem::Money.new(0.015, 1.0, 2),
        sizing_policy: Jedi::Tools::FixedAmountSizingPolicy.new(1_000.0),
        execution_policy: Jedi::Tools::BacktestExecutionPolicy.new,
      ).run

      result.trade_count.should eq(2)
      result.operation_count.should eq(3)
      result.operations.map(&.stock).should eq([100, 0, 100])
      result.sizing_events.map(&.timestamp).should eq([Time.utc(2026, 1, 2), Time.utc(2026, 1, 6)])
      result.opening_day_execution_count.should eq(0)
      result.total_buys_cents.should eq(200_000)
      result.total_sells_cents.should eq(85_000)
      result.total_fees_cents.should eq(998)
      result.portfolio_cents.should eq(100_000)
      result.current_investment_cents.should eq(115_000)
      result.maximum_investment_cents.should eq(115_000)
      result.gross_gain_cents.should eq(-15_000)
      result.net_gain_cents.should eq(-15_998)
      result.daily_valuations.last.net_gain_cents.should eq(-15_998)
      event = result.execution_events.first
      event.key.should eq(:loss)
      event.execution_price.should eq(8.5)
      event.gap.should be_true
    end
  end

  it "uses identical capital including cents for candidate and simulated openings" do
    with_trading_workflow do |main, memory|
      definition = "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0"
      money = Jedi::TradingSystem::Money.new(0.05, 1.0, 2)
      candidate = Jedi::Tools::CandidateEvaluator.new(main, memory).call(
        isin: "FR4487601001", price: 10.0, scaledef: definition,
        amount: nil, money: money, capital: 1_831.75,
        minimum_quantity: 1, operability_steps: 1,
      )
      previous_capital = Jedi::App.capital
      backtest = Jedi::Tools::BackTest.new(
        main, memory, trading_workflow_fixture("backtest_quotes.csv"), definition, money,
      )
      output = backtest.run(
        option_command: {'r' => ""}, option_capital: 1_831.75,
        option_minimum_quantity: 1, option_operability_steps: 1,
      )
      result = backtest.simulation_result
      decision = result.first_accepted_sizing.not_nil!

      candidate.quantity.should eq(33)
      decision.quantity.should eq(33)
      decision.amount.should eq(candidate.opening_amount)
      decision.position_sizing.not_nil!.risk_amount.should eq(candidate.position_sizing.not_nil!.risk_amount)
      result.capital_sizing_policy.not_nil!.capital.should eq(1_831.75)
      output.should contain("1831.75")
      Jedi::App.capital.should eq(previous_capital)
    end
  end

  it "reuses a score scale in backtest and candidate with the same fixed opening quantity" do
    with_trading_workflow do |main, memory|
      filename = trading_workflow_fixture("backtest_opening_gaps.csv")
      scoring = Jedi::Tools::Scoring.new(
        main, memory, filename, "vr:10%,np:2,nn:2,ki:0%,kb:1,kd:0.0",
        progress_io: IO::Memory.new,
      )
      scoring.run
      score = scoring.evaluated_results.first
      selected = score.candidate
      backtest = Jedi::Tools::BackTest.new(main, memory, filename, selected.scalebuild, nil)
      backtest.run(option_command: {} of Char => String)
      simulation = backtest.simulation_result
      scale_definition = simulation.scale.operational.definition
      initial_quantity = simulation.first_accepted_sizing.not_nil!.quantity

      score.fitness.should be_close(simulation.gross_fitness, JediSpec::EPSILON)
      score.performance.net_fitness.should be_close(simulation.net_fitness, JediSpec::EPSILON)
      score.performance.total_fees_cents.should eq(simulation.total_fees_cents)
      score.performance.maximum_investment_cents.should eq(simulation.maximum_investment_cents)
      score.performance.operation_count.should eq(simulation.operation_count)

      candidate = Jedi::Tools::CandidateEvaluator.new(main, memory).call(
        isin: "FR4487601001", price: 10.0, scaledef: selected.scalebuild,
        amount: 1_000.0, money: nil, capital: 20_000.0,
      )
      candidate.quantity.should eq(initial_quantity)
      candidate.opening_amount.should eq(1_000.0)
      candidate.scale.operational.definition.should eq(scale_definition)
      main.scalar("SELECT COUNT(*) FROM operation").as(Int64).should eq(0)
    end
  end
end
