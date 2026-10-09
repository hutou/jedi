require "../spec_helper"

private def backtest_execution_test_order(
  type : Jedi::TradingLife::Operation::Type,
  mode : Jedi::TradingLife::Operation::Mode,
  price : Float64,
  kind : Jedi::TradingSystem::TradeStop::Kind? = nil,
) : Jedi::TradingSystem::OrderEngine::Order
  Jedi::TradingSystem::OrderEngine::Order.new(
    type: type,
    mode: mode,
    position: Jedi::TradingRules::Position.new(0, 0, 0),
    quantity: 10,
    price: price,
    spe: 0.0,
    cpe: 0.0,
    last_stock: 10,
    operation_id: 1_i64,
    kind: kind,
  )
end

private def backtest_execution_test_quote(
  open : Float64,
  high : Float64,
  low : Float64,
  close : Float64? = nil,
) : Jedi::MarketData::Quote
  {
    date:   Time.utc(2026, 1, 5),
    open:   open,
    high:   high,
    low:    low,
    close:  close || open,
    volume: 1_000_i64,
  }
end

describe Jedi::Tools::BacktestExecutionPolicy do
  it "prioritizes the downside when both directional orders are touched" do
    orders = {
      :up => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Sell,
        Jedi::TradingLife::Operation::Mode::Limit,
        11.0,
      ),
      :down => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Buy,
        Jedi::TradingLife::Operation::Mode::Limit,
        9.0,
      ),
    }
    quote = backtest_execution_test_quote(10.0, 11.5, 8.5)

    decision = Jedi::Tools::BacktestExecutionPolicy.new.select(orders, quote)

    decision.should_not be_nil
    decision = decision.not_nil!
    decision.key.should eq(:down)
    decision.execution_price.should eq(9.0)
    decision.conflict.should be_true
  end

  it "prefers the down order to a loss-cut stop during an intraday fall" do
    orders = {
      :down => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Buy,
        Jedi::TradingLife::Operation::Mode::Limit,
        9.5,
      ),
      :loss => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Sell,
        Jedi::TradingLife::Operation::Mode::StopLoss,
        9.0,
        Jedi::TradingSystem::TradeStop::Kind::CL,
      ),
    }
    quote = backtest_execution_test_quote(10.0, 10.2, 8.8)

    decision = Jedi::Tools::BacktestExecutionPolicy.new.select(orders, quote)

    decision.should_not be_nil
    decision.not_nil!.key.should eq(:down)
  end

  it "keeps a gain-protection stoploss ahead of the down order" do
    orders = {
      :down => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Buy,
        Jedi::TradingLife::Operation::Mode::Limit,
        9.5,
      ),
      :loss => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Sell,
        Jedi::TradingLife::Operation::Mode::StopLoss,
        9.0,
        Jedi::TradingSystem::TradeStop::Kind::GP,
      ),
    }
    quote = backtest_execution_test_quote(10.0, 10.2, 8.8)

    decision = Jedi::Tools::BacktestExecutionPolicy.new.select(orders, quote)

    decision.should_not be_nil
    decision.not_nil!.key.should eq(:loss)
  end

  it "executes a loss-cut stop first when the opening gaps through it" do
    orders = {
      :down => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Buy,
        Jedi::TradingLife::Operation::Mode::Limit,
        9.5,
      ),
      :loss => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Sell,
        Jedi::TradingLife::Operation::Mode::StopLoss,
        9.0,
        Jedi::TradingSystem::TradeStop::Kind::CL,
      ),
    }
    quote = backtest_execution_test_quote(8.5, 8.8, 8.0)

    decision = Jedi::Tools::BacktestExecutionPolicy.new.select(orders, quote)

    decision.should_not be_nil
    decision = decision.not_nil!
    decision.key.should eq(:loss)
    decision.execution_price.should eq(8.5)
  end

  it "preserves upward priority in legacy mode" do
    orders = {
      :up => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Sell,
        Jedi::TradingLife::Operation::Mode::Limit,
        11.0,
      ),
      :down => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Buy,
        Jedi::TradingLife::Operation::Mode::Limit,
        9.0,
      ),
    }
    quote = backtest_execution_test_quote(10.0, 11.5, 8.5)
    policy = Jedi::Tools::BacktestExecutionPolicy.new(
      mode: Jedi::Tools::BacktestExecutionMode::Legacy,
    )

    decision = policy.select(orders, quote)

    decision.should_not be_nil
    decision.not_nil!.key.should eq(:up)
    decision.not_nil!.execution_price.should eq(11.0)
  end

  it "executes a sell stoploss at the opening price after a downward gap" do
    orders = {
      :loss => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Sell,
        Jedi::TradingLife::Operation::Mode::StopLoss,
        9.0,
      ),
    }
    quote = backtest_execution_test_quote(8.5, 8.8, 8.0)

    decision = Jedi::Tools::BacktestExecutionPolicy.new.select(orders, quote)

    decision.should_not be_nil
    decision = decision.not_nil!
    decision.execution_price.should eq(8.5)
    decision.gap.should be_true
  end

  it "gives a buy limit the better opening price after a downward gap" do
    orders = {
      :down => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Buy,
        Jedi::TradingLife::Operation::Mode::Limit,
        9.0,
      ),
    }
    quote = backtest_execution_test_quote(8.5, 9.2, 8.2)

    decision = Jedi::Tools::BacktestExecutionPolicy.new.select(orders, quote)

    decision.should_not be_nil
    decision = decision.not_nil!
    decision.execution_price.should eq(8.5)
    decision.gap.should be_true
  end

  it "uses the theoretical order price when there is no opening gap" do
    orders = {
      :down => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Buy,
        Jedi::TradingLife::Operation::Mode::Limit,
        9.0,
      ),
    }
    quote = backtest_execution_test_quote(10.0, 10.2, 8.8)

    decision = Jedi::Tools::BacktestExecutionPolicy.new.select(orders, quote)

    decision.should_not be_nil
    decision = decision.not_nil!
    decision.execution_price.should eq(9.0)
    decision.gap.should be_false
  end

  it "executes a sell limit at the opening before an intraday downward touch" do
    orders = {
      :up => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Sell,
        Jedi::TradingLife::Operation::Mode::Limit, 11.0,
      ),
      :down => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Buy,
        Jedi::TradingLife::Operation::Mode::Limit, 9.0,
      ),
    }

    [11.0, 12.0].each do |opening|
      quote = backtest_execution_test_quote(opening, 12.5, 8.5)
      decision = Jedi::Tools::BacktestExecutionPolicy.new.select(orders, quote).not_nil!

      decision.key.should eq(:up)
      decision.execution_price.should eq(opening)
      decision.gap.should eq(opening > 11.0)
      decision.conflict.should be_true
    end
  end

  it "executes an upward buy stop at the opening before an intraday sell stop" do
    orders = {
      :up => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Buy,
        Jedi::TradingLife::Operation::Mode::Stop, 11.0,
      ),
      :down => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Sell,
        Jedi::TradingLife::Operation::Mode::Stop, 9.0,
      ),
    }
    quote = backtest_execution_test_quote(12.0, 12.5, 8.5)
    decision = Jedi::Tools::BacktestExecutionPolicy.new.select(orders, quote).not_nil!

    decision.key.should eq(:up)
    decision.execution_price.should eq(12.0)
    decision.gap.should be_true
  end

  it "executes an opening buy limit before a later gain-protection stop" do
    orders = {
      :down => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Buy,
        Jedi::TradingLife::Operation::Mode::Limit, 9.5,
      ),
      :loss => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Sell,
        Jedi::TradingLife::Operation::Mode::StopLoss, 9.0,
        Jedi::TradingSystem::TradeStop::Kind::GP,
      ),
    }
    quote = backtest_execution_test_quote(9.2, 10.2, 8.8)
    decision = Jedi::Tools::BacktestExecutionPolicy.new.select(orders, quote).not_nil!

    decision.key.should eq(:down)
    decision.execution_price.should eq(9.2)
    decision.conflict.should be_true
  end

  it "keeps legacy theoretical-price execution even after a gap" do
    orders = {
      :loss => backtest_execution_test_order(
        Jedi::TradingLife::Operation::Type::Sell,
        Jedi::TradingLife::Operation::Mode::StopLoss,
        9.0,
      ),
    }
    quote = backtest_execution_test_quote(8.5, 8.8, 8.0)
    policy = Jedi::Tools::BacktestExecutionPolicy.new(
      mode: Jedi::Tools::BacktestExecutionMode::Legacy,
    )

    decision = policy.select(orders, quote)

    decision.should_not be_nil
    decision = decision.not_nil!
    decision.execution_price.should eq(9.0)
    decision.gap.should be_false
  end

  it "makes opening-day activation explicit" do
    default_policy = Jedi::Tools::BacktestExecutionPolicy.new
    same_session_policy = Jedi::Tools::BacktestExecutionPolicy.new(
      opening_day: Jedi::Tools::BacktestOpeningDayPolicy::SameSession,
    )

    default_policy.orders_active_on_opening_day?.should be_false
    same_session_policy.orders_active_on_opening_day?.should be_true
  end
end
