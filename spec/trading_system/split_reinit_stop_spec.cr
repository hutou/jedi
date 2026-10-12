require "../support/jedi_spec_helper"

module JediSplitReinitStopSpec
  extend self

  def reset(conn, price : Float64 = 10.0) : Nil
    Jedi::TradingSystem::SettingsCreator.new(conn).call(
      trade_ident: 1_i64,
      scale_ident: 1_i64,
      timestamp: Time.local(2026, 1, 1, 11, 0, 0),
      option_split: Jedi::Exchange::Security::Split.new("1:10"),
      option_reinit: Jedi::TradingSystem::ReInitOption.parse("reset,#{price}"))
  end
end

describe Jedi::TradingSystem::OrderEngine, "stops after split and reset" do
  it "uses the new stock for current gains, stops and net stops" do
    [false, true].each do |net_stop|
      JediSpec.with_db do |conn|
        JediSpec.seed_basic_trade(conn, stock: 1790, price: 1.0, money: "r:1.5%,o:2,n:2")
        JediSplitReinitStopSpec.reset(conn)
        trade = JediSpec.trade(conn)
        engine = Jedi::TradingSystem::OrderEngine.new(trade, capital: 20_000.0)
        lastdata = Jedi::TradingRules::LastData.new(trade.last_settings.not_nil!, trade.last_operation.not_nil!)

        engine.calculate_current_gain_loss(lastdata, 10.0).should eq(0.0)
        engine.calculate_current_gain_loss(lastdata, 12.0).should eq(358.0)
        orders = engine.orders(option_net_stop: net_stop)
        loss = orders[:loss]
        loss.kind.should eq(Jedi::TradingSystem::TradeStop::Kind::CL)
        loss.last_stock.should eq(179)
        loss.original_quantity.should eq(179)
        loss.quantity.should eq(net_stop ? 143 : 179)
        loss.price.should be_close(8.32, JediSpec::EPSILON)
        trade.stop.not_nil!.quantity.should eq(179)
        trade.stop.not_nil!.guaranteed_gain.should eq(-300.0)
      end
    end
  end

  it "projects down steps from the reset position rather than the historical position" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, stock: 1790, price: 1.0)
      conn.exec("UPDATE operation SET position = '1:2:-1', ksp = 0.7, kcp = 0.8 WHERE id = 1")
      JediSplitReinitStopSpec.reset(conn)
      trade = JediSpec.trade(conn)
      engine = Jedi::TradingSystem::OrderEngine.new(trade)
      lastdata = Jedi::TradingRules::LastData.new(trade.last_settings.not_nil!, trade.last_operation.not_nil!)
      first = engine.step_moves(lastdata, 2).first

      first.stock.should eq(215)
      first.quantity.should eq(36)
      first.price.should be_close(9.0, JediSpec::EPSILON)
      first.buys.should eq(211_400)
    end
  end

  it "recomputes a pre-existing guaranteed-gain stop in the post-split unit" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn,
        stock: 1790, price: 1.0, money: "r:1.5%,o:2,n:2",
        stop: "1:GP:1790:1.055:100")
      JediSplitReinitStopSpec.reset(conn, 12.0)
      trade = JediSpec.trade(conn)
      orders = Jedi::TradingSystem::OrderEngine.new(trade, capital: 20_000.0).orders
      loss = orders[:loss]

      loss.kind.should eq(Jedi::TradingSystem::TradeStop::Kind::GP)
      loss.quantity.should eq(179)
      loss.price.should be_close(10.55, JediSpec::EPSILON)
      trade.stop.not_nil!.quantity.should eq(179)
      trade.stop.not_nil!.guaranteed_gain.should eq(100.0)
    end
  end

  it "recomputes a pre-existing loss-cut stop in the post-split unit" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn,
        stock: 1790, price: 1.0, money: "r:1.5%,o:2,n:2",
        stop: "1:CL:1790:0.832:-300")
      JediSplitReinitStopSpec.reset(conn)
      trade = JediSpec.trade(conn)
      orders = Jedi::TradingSystem::OrderEngine.new(trade, capital: 20_000.0).orders

      orders[:loss].quantity.should eq(179)
      orders[:loss].price.should be_close(8.32, JediSpec::EPSILON)
      trade.stop.not_nil!.guaranteed_gain.should eq(-300.0)
    end
  end

  it "waits for the manual merge transaction before calculating orders with money management" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, stock: 1790, price: 1.0, money: "r:1.5%,o:2,n:2")
      settings_id = Jedi::TradingSystem::SettingsCreator.new(conn).call(
        trade_ident: 1_i64,
        scale_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0),
        option_split: Jedi::Exchange::Security::Split.new("1:10"),
        option_reinit: Jedi::TradingSystem::ReInitOption.parse("merge,12.0"))
      Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn)).orders.empty?.should be_true

      id = Jedi::TradingLife::OperationCreator.new(conn).call(
        trade_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 12, 0, 0),
        type: Jedi::TradingLife::Operation::Type::Buy,
        mode: Jedi::TradingLife::Operation::Mode::Market,
        quantity: 21,
        price: 10.0,
        cfees: 0.0,
        tickcheck: true)
      Jedi::TradingLife::Operation.new(conn, id).stock.should eq(200)
      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)
      settings.q0.should eq(200.0)
      settings.c0.should be_close(11.79, JediSpec::EPSILON)
      Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn)).orders.empty?.should be_false
    end
  end

  it "returns no orders after a merge sale has liquidated the entire converted position" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, stock: 1790, price: 1.0)
      Jedi::TradingSystem::SettingsCreator.new(conn).call(
        trade_ident: 1_i64,
        scale_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0),
        option_split: Jedi::Exchange::Security::Split.new("1:10"),
        option_reinit: Jedi::TradingSystem::ReInitOption.parse("merge,12.0"))
      Jedi::TradingLife::OperationCreator.new(conn).call(
        trade_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 12, 0, 0),
        type: Jedi::TradingLife::Operation::Type::Sell,
        mode: Jedi::TradingLife::Operation::Mode::Market,
        quantity: 179,
        price: 12.0,
        cfees: 0.0,
        tickcheck: true)
      conn.exec("UPDATE trade SET money = 'r:1.5%,o:2,n:2' WHERE id = 1")
      Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn)).orders.empty?.should be_true
    end
  end
end
