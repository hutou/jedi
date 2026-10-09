require "../support/jedi_spec_helper"

describe Jedi::TradingSystem::TradeStop do
  it "parses a persisted trade stop" do
    stop = Jedi::TradingSystem::TradeStop.parse("42:GP:120:9.87:350.25").not_nil!

    stop.operation_id.should eq(42_i64)
    stop.kind.should eq(Jedi::TradingSystem::TradeStop::Kind::GP)
    stop.quantity.should eq(120)
    stop.price.should be_close(9.87, JediSpec::EPSILON)
    stop.guaranteed_gain.should be_close(350.25, JediSpec::EPSILON)
  end

  it "returns nil for nil or blank persisted values" do
    Jedi::TradingSystem::TradeStop.parse(nil).should be_nil
    Jedi::TradingSystem::TradeStop.parse("").should be_nil
    Jedi::TradingSystem::TradeStop.parse("   ").should be_nil
  end

  it "round-trips through its persisted string format" do
    stop = Jedi::TradingSystem::TradeStop.new(
      7_i64,
      Jedi::TradingSystem::TradeStop::Kind::CL,
      50,
      12.34,
      -300.0
    )

    stop.to_s.should eq("7:CL:50:12.34:-300.0")
    Jedi::TradingSystem::TradeStop.parse(stop.to_s).should eq(stop)
  end

  it "compares stops by guaranteed gain" do
    old_stop = Jedi::TradingSystem::TradeStop.new(1_i64, Jedi::TradingSystem::TradeStop::Kind::GP, 100, 8.0, 100.0)
    new_stop = Jedi::TradingSystem::TradeStop.new(2_i64, Jedi::TradingSystem::TradeStop::Kind::GP, 100, 9.0, 250.0)

    new_stop.better_than?(old_stop).should be_true
    old_stop.better_than?(new_stop).should be_false
  end

  it "rejects malformed persisted values" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingSystem::TradeStop.parse("42:GP:120:9.87")
    end

    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingSystem::TradeStop.parse("42:BAD:120:9.87:350.25")
    end
  end
end
