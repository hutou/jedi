require "../support/jedi_spec_helper"

describe "Persistence round trips" do
  it "round-trips a security row through typed accessors" do
    JediSpec.with_db do |conn|
      JediSpec.insert_security(
        conn,
        tick_buy: 0.001,
        tick_sell: 0.005
      )

      security = Jedi::Exchange::Security.new(conn, 1_i64)

      security.isin.should eq("FR4487601001")
      security.name.should eq("SPEC SECURITY")
      security.ticker.should eq("SPEC")
      security.tick_buy.value.should be_close(0.001, JediSpec::EPSILON)
      security.tick_sell.value.should be_close(0.005, JediSpec::EPSILON)
      security.tax.should be_close(0.0, JediSpec::EPSILON)
      security.quotation_price.should be_nil

      # security.set_quote(12.34)
      Jedi::Exchange::QuoteSetter.new(security).set(12.34)

      reloaded = Jedi::Exchange::Security.new(conn, 1_i64)
      reloaded.quotation_price.not_nil!.should be_close(12.34, JediSpec::EPSILON)
      reloaded.quotation_mode.should eq("live")
      reloaded.quotation_website.should eq("manual")
      reloaded.quotation_date.should_not be_nil
    end
  end

  it "round-trips a scale operational JSON row" do
    JediSpec.with_db do |conn|
      JediSpec.insert_scale(conn, scale: JediSpec.type_one_scale)

      scale = Jedi::TradingRules::Scale.new(conn, "S_TEST")
      operational = scale.operational

      scale.name.should eq("S_TEST")
      scale.comment.should eq("Spec scale")
      operational.type.should eq(Jedi::TradingRules::Scale::Operational::Type::One)
      operational.definition.should eq("kc:1.2,1.1,0.9,0.8, ks:0.8,1.2, ki:10.0%, kb:0")
      operational.emax.should eq(2)
      operational.emin.should eq(-2)
      operational.ki.should be_close(0.10, JediSpec::EPSILON)
      operational.ks(1).should be_close(0.80, JediSpec::EPSILON)
      operational.ks(-1).should be_close(1.20, JediSpec::EPSILON)
      operational.kc(2).should be_close(1.20, JediSpec::EPSILON)
      operational.kc(-2).should be_close(0.80, JediSpec::EPSILON)
    end
  end

  it "round-trips trade money and stop through typed accessors and updates" do
    JediSpec.with_db do |conn|
      stop = Jedi::TradingSystem::TradeStop.new(
        1_i64,
        Jedi::TradingSystem::TradeStop::Kind::CL,
        100,
        7.5,
        -300.0
      )

      JediSpec.insert_security(conn)
      JediSpec.insert_trade(
        conn,
        money: "r:1.5%,o:2,n:2",
        stop: stop.to_s
      )

      trade = Jedi::TradingSystem::Trade.new(conn, "T_TEST")
      money = trade.money.not_nil!
      persisted_stop = trade.stop.not_nil!

      money.risk_rate.should be_close(0.015, JediSpec::EPSILON)
      money.target_coeff.should be_close(2.0, JediSpec::EPSILON)
      money.steps_down.should eq(2)

      persisted_stop.operation_id.should eq(1_i64)
      persisted_stop.kind.should eq(Jedi::TradingSystem::TradeStop::Kind::CL)
      persisted_stop.quantity.should eq(100)
      persisted_stop.price.should be_close(7.5, JediSpec::EPSILON)
      persisted_stop.guaranteed_gain.should be_close(-300.0, JediSpec::EPSILON)

      replacement = Jedi::TradingSystem::TradeStop.new(
        2_i64,
        Jedi::TradingSystem::TradeStop::Kind::GP,
        80,
        11.25,
        125.0
      )

      trade.stop_update(replacement).should eq(1)
      trade.stop.not_nil!.kind.should eq(Jedi::TradingSystem::TradeStop::Kind::GP)
      trade.stop.not_nil!.price.should be_close(11.25, JediSpec::EPSILON)

      trade.stop_clear.should eq(1)
      trade.stop.should be_nil
    end
  end

  it "round-trips a split settings row through typed accessors" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      conn.exec(
        "UPDATE settings SET split = ?, q0 = ?, c0 = ?, position = ? WHERE id = ?",
        "3:2",
        150.0,
        6.6667,
        "0:0:0",
        1_i64
      )

      settings = Jedi::TradingSystem::Settings.new(conn, 1_i64)

      settings.split.not_nil!.to_s.should eq("3:2")
      settings.sync.should be_nil
      settings.reinit.should be_nil
      settings.q0.should be_close(150.0, JediSpec::EPSILON)
      settings.c0.should be_close(6.6667, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      settings.trade.id.should eq(1_i64)
      settings.scale.name.should eq("S_TEST")
    end
  end

  it "round-trips a synchronized settings row through typed accessors" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      conn.exec(
        "UPDATE settings SET sync = ?, position = ? WHERE id = ?",
        "1:0:+1",
        "0:0:+1",
        1_i64
      )

      settings = Jedi::TradingSystem::Settings.new(conn, 1_i64)

      settings.split.should be_nil
      settings.sync.not_nil!.should eq(Jedi::TradingRules::Position.new("1:0:+1"))
      settings.reinit.should be_nil
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
    end
  end

  it "round-trips a reinit settings row through typed accessors" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      conn.exec(
        "UPDATE settings SET reinit = ?, q0 = ?, c0 = ?, position = ? WHERE id = ?",
        "reset,8.5",
        100.0,
        8.5,
        "0:0:0",
        1_i64
      )

      settings = Jedi::TradingSystem::Settings.new(conn, 1_i64)
      reinit = settings.reinit.not_nil!

      settings.split.should be_nil
      settings.sync.should be_nil
      reinit.reset?.should be_true
      reinit.c0.should be_close(8.5, JediSpec::EPSILON)
      settings.q0.should be_close(100.0, JediSpec::EPSILON)
      settings.c0.should be_close(8.5, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
    end
  end

  it "round-trips operation enums, position and associations" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      JediSpec.insert_operation(
        conn,
        id: 2_i64,
        type: Jedi::TradingLife::Operation::Type::Sell,
        mode: Jedi::TradingLife::Operation::Mode::Limit,
        quantity: 20,
        price: 11.0,
        stock: 80,
        position: "0:0:+1",
        ksp: 0.8,
        kcp: 1.0,
        sell: 22_000,
        trade_invest: 78_000,
        global_invest: 78_000,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0)
      )

      operation = Jedi::TradingLife::Operation.new(conn, 2_i64)

      operation.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      operation.quantity.should eq(20)
      operation.price.should be_close(11.0, JediSpec::EPSILON)
      operation.sell.should eq(22_000)
      operation.stock.should eq(80)
      operation.position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
      operation.ksp.should be_close(0.8, JediSpec::EPSILON)
      operation.kcp.should be_close(1.0, JediSpec::EPSILON)

      operation.settings.id.should eq(1_i64)
      operation.trade.id.should eq(1_i64)
      operation.scale.name.should eq("S_TEST")
    end
  end
end
