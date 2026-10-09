require "../support/jedi_spec_helper"

module JediMoneyEdgeSpec
  extend self

  def seed_after_first_down(
    conn,
    *,
    money : String,
    stop : String? = nil,
    tick_buy : Float64 = 0.01,
    tick_sell : Float64 = 0.01,
  ) : Jedi::TradingSystem::Trade
    JediSpec.insert_security(conn, tick_buy: tick_buy, tick_sell: tick_sell)
    JediSpec.insert_scale(conn)
    JediSpec.insert_trade(conn, money: money, stop: stop)
    JediSpec.insert_settings(conn, q0: 100.0, c0: 10.0)
    JediSpec.insert_operation(conn, quantity: 100, price: 10.0, stock: 100)
    JediSpec.insert_operation(
      conn,
      id: 2_i64,
      quantity: 20,
      price: 9.0,
      stock: 120,
      position: "0:0:-1",
      buy: 18_000,
      trade_invest: 118_000,
      global_invest: 118_000
    )
    JediSpec.trade(conn)
  end
end

describe Jedi::TradingSystem::Money do
  it "accepts configured lower boundary values" do
    money = Jedi::TradingSystem::Money.parse("r:0.5%,o:0.5,n:1").not_nil!

    money.risk_rate.should be_close(0.005, JediSpec::EPSILON)
    money.target_coeff.should be_close(0.5, JediSpec::EPSILON)
    money.steps_down.should eq(1)
  end

  it "accepts configured upper boundary values" do
    money = Jedi::TradingSystem::Money.parse("r:5%,o:5,n:5").not_nil!

    money.risk_rate.should be_close(0.05, JediSpec::EPSILON)
    money.target_coeff.should be_close(5.0, JediSpec::EPSILON)
    money.steps_down.should eq(5)
  end

  it "rejects values below configured lower boundaries" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingSystem::Money.parse("r:0.49%,o:2,n:2")
    end

    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingSystem::Money.parse("r:1.5%,o:0.49,n:2")
    end

    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingSystem::Money.parse("r:1.5%,o:2,n:0")
    end
  end

  it "rejects values above configured upper boundaries" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingSystem::Money.parse("r:5.1%,o:2,n:2")
    end

    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingSystem::Money.parse("r:1.5%,o:5.1,n:2")
    end

    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingSystem::Money.parse("r:1.5%,o:2,n:6")
    end
  end
end

describe Jedi::TradingSystem::OrderEngine do
  it "does not create a loss-cut stoploss when a larger risk budget absorbs the projected loss" do
    JediSpec.with_db do |conn|
      trade = JediMoneyEdgeSpec.seed_after_first_down(
        conn,
        money: "r:5%,o:2,n:2"
      )

      orders = Jedi::TradingSystem::OrderEngine.new(trade).orders

      orders.has_key?(:down).should be_true
      orders.has_key?(:up).should be_true
      orders.has_key?(:loss).should be_false
      trade.stop.should be_nil
    end
  end

  it "creates a loss-cut stoploss for the same state when the risk budget is smaller" do
    JediSpec.with_db do |conn|
      trade = JediMoneyEdgeSpec.seed_after_first_down(
        conn,
        money: "r:1.5%,o:2,n:2"
      )

      orders = Jedi::TradingSystem::OrderEngine.new(trade).orders
      loss = orders[:loss].not_nil!

      loss.kind.should eq(Jedi::TradingSystem::TradeStop::Kind::CL)
      loss.quantity.should eq(120)
      loss.price.should be_close(7.33, JediSpec::EPSILON)

      persisted_stop = trade.stop.not_nil!
      persisted_stop.kind.should eq(Jedi::TradingSystem::TradeStop::Kind::CL)
      persisted_stop.guaranteed_gain.should be_close(-300.0, JediSpec::EPSILON)
    end
  end

  it "does not create a loss-cut stoploss when steps_down is not deep enough to exceed risk" do
    JediSpec.with_db do |conn|
      trade = JediMoneyEdgeSpec.seed_after_first_down(
        conn,
        money: "r:1.5%,o:2,n:1"
      )

      orders = Jedi::TradingSystem::OrderEngine.new(trade).orders

      orders.has_key?(:down).should be_true
      orders.has_key?(:up).should be_true
      orders.has_key?(:loss).should be_false
      trade.stop.should be_nil
    end
  end

  it "clears a persisted loss-cut stop when the current projection is no longer critical" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(
        conn,
        money: "r:1.5%,o:2,n:2",
        stop: "1:CL:100:8.0:-300.0"
      )

      trade = JediSpec.trade(conn)
      trade.stop.should_not be_nil

      orders = Jedi::TradingSystem::OrderEngine.new(trade).orders

      orders.has_key?(:loss).should be_false
      trade.stop.should be_nil
    end
  end
end
