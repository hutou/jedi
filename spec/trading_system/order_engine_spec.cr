require "../support/jedi_spec_helper"

describe Jedi::TradingSystem::OrderEngine do
  it "uses the exact supplied capital for simulated stops without changing the global or live capital" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, money: "r:1.5%,o:1,n:2")
      previous_simulation = Jedi::App.simulation
      previous_capital = Jedi::App.capital
      begin
        Jedi::App.simulation = Jedi::SimulationMode::FromSeed
        Jedi::App.capital = 20_000
        trade = JediSpec.trade(conn)
        Jedi::TradingSystem::OrderEngine.new(trade).orders.has_key?(:loss).should be_false

        orders = Jedi::TradingSystem::OrderEngine.new(trade, capital: 1_000.75).orders

        loss = orders[:loss]
        loss.price.should be_close(9.84, JediSpec::EPSILON)
        trade.stop.not_nil!.guaranteed_gain.should be_close(-15.01125, JediSpec::EPSILON)
        Jedi::App.capital.should eq(20_000)

        Jedi::App.simulation = Jedi::SimulationMode::None
        Jedi::TradingSystem::OrderEngine.new(trade).orders.has_key?(:loss).should be_false
      ensure
        Jedi::App.simulation = previous_simulation
        Jedi::App.capital = previous_capital
      end
    end
  end

  it "generates the two standard limit orders after the initial operation" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      orders = Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn)).orders
      down = orders[:down].not_nil!
      up = orders[:up].not_nil!

      down.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      down.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      down.quantity.should eq(20)
      down.price.should be_close(9.0, JediSpec::EPSILON)
      down.position.should eq(Jedi::TradingRules::Position.new("0:0:-1"))

      up.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      up.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      up.quantity.should eq(20)
      up.price.should be_close(11.0, JediSpec::EPSILON)
      up.position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
    end
  end

  it "computes the gain or loss at current price from all operations" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      trade = JediSpec.trade(conn)
      engine = Jedi::TradingSystem::OrderEngine.new(trade)
      lastdata = Jedi::TradingRules::LastData.new(
        trade.last_settings.not_nil!,
        trade.last_operation.not_nil!
      )

      engine.calculate_current_gain_loss(lastdata, 12.50).should be_close(250.0, JediSpec::EPSILON)
      engine.calculate_current_gain_loss(lastdata, 8.25).should be_close(-175.0, JediSpec::EPSILON)
    end
  end

  it "computes the equivalent stoploss price after virtual down steps" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      engine = Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn))

      moves = [
        Jedi::TradingSystem::OrderEngine::StepMove.new(20, 9.0, 18000, 0, 120),
        Jedi::TradingSystem::OrderEngine::StepMove.new(30, 8.0, 42000, 0, 150),
      ]

      engine.calculate_stoploss_price(100, moves).should be_close(7.8, JediSpec::EPSILON)
    end
  end

  it "rejects stoploss calculation without stock or without down steps" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      engine = Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn))

      expect_raises(Jedi::LowLevelError) do
        engine.calculate_stoploss_price(0, [] of Jedi::TradingSystem::OrderEngine::StepMove)
      end

      expect_raises(Jedi::LowLevelError) do
        engine.calculate_stoploss_price(100, [] of Jedi::TradingSystem::OrderEngine::StepMove)
      end
    end
  end

  it "does not add a loss-cut stoploss before the projected loss exceeds risk" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, money: "r:1.5%,o:2,n:2")

      orders = Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn)).orders

      orders.has_key?(:down).should be_true
      orders.has_key?(:up).should be_true
      orders.has_key?(:loss).should be_false
    end
  end

  it "adds a loss-cut stoploss once two further down steps would exceed risk" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, money: "r:1.5%,o:2,n:2")

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

      trade = JediSpec.trade(conn)
      orders = Jedi::TradingSystem::OrderEngine.new(trade).orders
      loss = orders[:loss].not_nil!

      orders.has_key?(:down).should be_true
      loss.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      loss.mode.should eq(Jedi::TradingLife::Operation::Mode::StopLoss)
      loss.quantity.should eq(120)
      loss.original_quantity.should eq(120)
      loss.price.should be_close(7.33, JediSpec::EPSILON)
      loss.kind.should eq(Jedi::TradingSystem::TradeStop::Kind::CL)

      persisted_stop = trade.stop.not_nil!
      persisted_stop.kind.should eq(Jedi::TradingSystem::TradeStop::Kind::CL)
      persisted_stop.price.should be_close(7.33, JediSpec::EPSILON)
      persisted_stop.guaranteed_gain.should be_close(-300.0, JediSpec::EPSILON)
    end
  end

  it "nets the stoploss quantity against the upward order when requested" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, money: "r:1.5%,o:2,n:2")

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

      orders = Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn))
        .orders(option_net_stop: true)
      loss = orders[:loss].not_nil!

      loss.quantity.should eq(100)
      loss.original_quantity.should eq(120)
    end
  end
end
