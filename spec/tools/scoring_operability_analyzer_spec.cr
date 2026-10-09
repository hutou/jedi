require "../spec_helper"

describe Jedi::Tools::ScoringOperabilityAnalyzer do
  it "keeps a degraded current state operable when it meets the requested quantity" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, stock: 5, price: 10.0)
      filename = File.expand_path(
        "../fixtures/tools/backtest_quotes.csv",
        __DIR__,
      )
      result = Jedi::Tools::BacktestResult.new(
        quote_history: Jedi::Tools::QuoteHistory.new(filename),
        scale: Jedi::TradingRules::Scale.new(conn, 1_i64),
        security: Jedi::Exchange::Security.new(conn, 1_i64),
        trades: Jedi::TradingSystem::Trades.new(conn).fetch,
        operations: Jedi::TradingLife::Operations.new(conn).fetch,
        sizing_policy: Jedi::Tools::FixedAmountSizingPolicy.new(50.0),
        sizing_events: [] of Jedi::Tools::BacktestSizingEvent,
        execution_policy: Jedi::Tools::BacktestExecutionPolicy.new,
        execution_events: [] of Jedi::Tools::BacktestExecutionEvent,
      )

      operability = Jedi::Tools::ScoringOperabilityAnalyzer.analyze(
        result,
        minimum_quantity: 1,
      )

      operability.status.should eq("Degraded")
      operability.minimum_directional_quantity.should eq(1)
      operability.operable.should be_true
      operability.warnings.empty?.should be_false
    end
  end
end
