require "../support/play_spec_helper"

describe Jedi::Tools::Play do
  it "can switch loss trigger to active before the critical down order" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01,money=r:1.5%,o:2,n:2,loss=fallback",
      ["-1", "loss=active", "-1"]
    ) do |play|
      play.loss_trigger.should eq(Jedi::Tools::Play::LossTrigger::Active)
      play.context.running_orders.size.should eq(2)

      play.context.running_orders[0].key.should eq(:down)
      play.context.running_orders[1].key.should eq(:loss)
      play.context.running_orders[1].orders[:loss].kind.should eq(Jedi::TradingSystem::TradeStop::Kind::CL)

      play.context.current_operation.mode.should eq(Jedi::TradingLife::Operation::Mode::StopLoss)
      play.context.current_operation.stock.should eq(0)
    end
  end

  it "can switch loss trigger back to fallback before the critical down order" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01,money=r:1.5%,o:2,n:2,loss=active",
      ["-1", "loss=fallback", "-1"]
    ) do |play|
      play.loss_trigger.should eq(Jedi::Tools::Play::LossTrigger::Fallback)
      play.context.running_orders.size.should eq(2)

      play.context.running_orders[0].key.should eq(:down)
      play.context.running_orders[1].key.should eq(:down)
      play.context.running_orders[1].orders.has_key?(:loss).should be_true

      play.context.current_operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      play.context.current_operation.stock.should be > 0
    end
  end

  it "does not let active loss trigger intercept an upward order" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01,money=r:1.5%,o:2,n:2,loss=active",
      ["-1", "1"]
    ) do |play|
      play.context.running_orders.size.should eq(2)

      first = play.context.running_orders[0]
      second = play.context.running_orders[1]

      first.key.should eq(:down)
      second.key.should eq(:up)
      second.orders.has_key?(:loss).should be_true

      play.context.current_operation.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      play.context.current_operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      play.context.current_operation.stock.should eq(100)
    end
  end
end
