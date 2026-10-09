require "../support/play_spec_helper"

describe Jedi::Tools::Play do
  it "keeps using the down limit when the configured risk budget is large enough" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01,money=r:5%,o:2,n:2,loss=active",
      ["-1", "-1"]
    ) do |play|
      play.context.running_orders.size.should eq(2)

      play.context.running_orders[0].key.should eq(:down)
      play.context.running_orders[1].key.should eq(:down)
      play.context.running_orders[1].orders.has_key?(:loss).should be_false

      operation = play.context.current_operation
      operation.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      operation.stock.should be > 120
    end
  end

  it "does not let loss=active select a loss order when steps_down is too shallow" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01,money=r:1.5%,o:2,n:1,loss=active",
      ["-1", "-1"]
    ) do |play|
      play.context.running_orders.size.should eq(2)

      play.context.running_orders[0].key.should eq(:down)
      play.context.running_orders[1].key.should eq(:down)
      play.context.running_orders[1].orders.has_key?(:loss).should be_false

      operation = play.context.current_operation
      operation.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      operation.stock.should be > 120
    end
  end

  it "can activate loss protection after lowering the risk budget during play" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01,money=r:5%,o:2,n:2,loss=active",
      ["-1", "money=r:1.5%,o:2,n:2", "-1"]
    ) do |play|
      play.context.running_orders.size.should eq(2)

      play.context.running_orders[0].key.should eq(:down)
      play.context.running_orders[1].key.should eq(:loss)
      play.context.running_orders[1].orders[:loss].kind.should eq(Jedi::TradingSystem::TradeStop::Kind::CL)

      operation = play.context.current_operation
      operation.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      operation.mode.should eq(Jedi::TradingLife::Operation::Mode::StopLoss)
      operation.stock.should eq(0)
    end
  end

  it "can disable loss protection after raising the risk budget during play" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01,money=r:1.5%,o:2,n:2,loss=active",
      ["-1", "money=r:5%,o:2,n:2", "-1"]
    ) do |play|
      play.context.running_orders.size.should eq(2)

      play.context.running_orders[0].key.should eq(:down)
      play.context.running_orders[1].key.should eq(:down)
      play.context.running_orders[1].orders.has_key?(:loss).should be_false

      operation = play.context.current_operation
      operation.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      operation.stock.should be > 120
    end
  end
end
