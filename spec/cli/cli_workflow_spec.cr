require "../spec_helper"
require "../support/cli_spec_helper"

describe Jedi::Command, "CLI smoke workflow" do
  it "creates the critical security, scale, trade, settings and operation records" do
    JediCliSpec.with_cli_db do |conn|
      JediCliSpec.run(conn,
        "security", "create",
        "--isin=FR4487601001",
        "--name=CLI SECURITY",
        "--ticker=CLIS",
        "--tick-buy=0.01",
        "--tick-sell=0.01",
        "--tax-rate=0.003")

      security = Jedi::Exchange::Security.new(conn, 1_i64)
      security.isin.should eq("FR4487601001")
      security.name.should eq("CLI SECURITY")
      security.ticker.should eq("CLIS")
      security.tick_buy.value.should be_close(0.01, JediSpec::EPSILON)
      security.tick_sell.value.should be_close(0.01, JediSpec::EPSILON)

      JediCliSpec.run(conn,
        "scale", "create",
        "--name=B_vr_01",
        "--comment=CLI scale",
        "--builder=vr:10.0%, ks:0.8,1.2, ki:0.0%, kb:0")

      scale = Jedi::TradingRules::Scale.new(conn, "B_vr_01")
      scale.name.should eq("B_vr_01")
      scale.operational.type.should eq(Jedi::TradingRules::Scale::Operational::Type::Two)

      JediCliSpec.run(conn,
        "trade", "create",
        "--name=T_CLI",
        "--security=1")

      trade = Jedi::TradingSystem::Trade.new(conn, "T_CLI")
      trade.security.id.should eq(security.id)
      trade.money.should be_nil

      JediCliSpec.run(conn,
        "settings", "create",
        "--scale=B_vr_01",
        "--date=2026-01-01",
        "--time=09:00:00",
        "T_CLI")

      JediCliSpec.run(conn, "trade", "update", "T_CLI", "--money=r:1.5%,o:2,n:2")
      trade.reload!(trade.id)
      trade.money.to_s.should eq("r:1.5%, o:2.0, n:2")

      settings = trade.last_settings.not_nil!
      settings.scale.name.should eq("B_vr_01")
      settings.q0.should be_close(0.0, JediSpec::EPSILON)
      settings.c0.should be_close(0.0, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))

      JediCliSpec.run(conn,
        "operation", "create",
        "T_CLI",
        "--date=2026-01-01",
        "--time=10:00:00",
        "--type=Buy",
        "--mode=Market",
        "--quantity=100",
        "--price=10.0")

      operation = trade.last_operation.not_nil!
      operation.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Market)
      operation.quantity.should eq(100)
      operation.price.should be_close(10.0, JediSpec::EPSILON)
      operation.stock.should eq(100)

      refreshed_settings = trade.last_settings.not_nil!
      refreshed_settings.q0.should be_close(100.0, JediSpec::EPSILON)
      refreshed_settings.c0.should be_close(10.0, JediSpec::EPSILON)

      JediCliSpec.run(conn,
        "operation", "create",
        "T_CLI",
        "--date=2026-01-01",
        "--time=11:00:00",
        "--type=Sell",
        "--mode=Market",
        "--quantity=100",
        "--price=0.0")

      liquidation = trade.last_operation.not_nil!
      liquidation.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      liquidation.price.should eq(0.0)
      liquidation.stock.should eq(0)
    end
  end

  it "routes trade update options and resets an existing stop when explicitly requested" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.seed_basic_trade(conn,
        money: "r:1.5%,o:2,n:2",
        stop: "0:cl:0:0:8.0")

      JediCliSpec.run(conn,
        "trade", "update",
        "T_TEST",
        "--name=T_UPDATED",
        "--money=r:2.0%,o:3,n:2",
        "--reset-stop")

      trade = Jedi::TradingSystem::Trade.new(conn, "T_UPDATED")
      trade.money.to_s.should eq("r:2%, o:3.0, n:2")
      trade.stop.should be_nil
    end
  end
end
