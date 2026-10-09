require "../support/play_spec_helper"

describe Jedi::Tools::Play do
  it "does not execute an upward target price below the next up order" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["10.50"]
    ) do |play|
      play.new_operations_count.should eq(0)
      play.context.running_orders.empty?.should be_true
      play.context.current_operation.stock.should eq(100)
      play.context.current_operation.price.should be_close(10.0, JediSpec::EPSILON)
      play.context.current_operation.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
    end
  end

  it "executes exactly one upward limit order up to a partial target price" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["11.50"]
    ) do |play|
      play.new_operations_count.should eq(1)
      play.context.running_orders.size.should eq(1)

      selected = play.context.running_orders.last
      selected.key.should eq(:up)
      selected.orders[:up].price.should be_close(11.0, JediSpec::EPSILON)

      operation = play.context.current_operation
      operation.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      operation.quantity.should eq(20)
      operation.price.should be_close(11.0, JediSpec::EPSILON)
      operation.stock.should eq(80)
      operation.position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
    end
  end

  it "executes exactly one downward limit order down to a partial target price" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["8.50"]
    ) do |play|
      play.new_operations_count.should eq(1)
      play.context.running_orders.size.should eq(1)

      selected = play.context.running_orders.last
      selected.key.should eq(:down)
      selected.orders[:down].price.should be_close(9.0, JediSpec::EPSILON)

      operation = play.context.current_operation
      operation.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      operation.quantity.should eq(20)
      operation.price.should be_close(9.0, JediSpec::EPSILON)
      operation.stock.should eq(120)
      operation.position.should eq(Jedi::TradingRules::Position.new("0:0:-1"))
    end
  end

  it "stops adding operations after a stoploss has emptied the stock" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01,money=r:1.5%,o:2,n:2,loss=active",
      ["-1", "-1", "1", "-1"]
    ) do |play|
      play.new_operations_count.should eq(2)
      play.context.running_orders.size.should eq(2)
      play.simulation_stopped?.should be_true

      play.context.running_orders[0].key.should eq(:down)
      play.context.running_orders[1].key.should eq(:loss)

      operation = play.context.current_operation
      operation.mode.should eq(Jedi::TradingLife::Operation::Mode::StopLoss)
      operation.stock.should eq(0)
    end
  end

  it "executes a fixed operation and stops if no merge is pending" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["5@9.50", "1"]
    ) do |play|
      play.new_operations_count.should eq(1)
      play.context.running_orders.empty?.should be_true
      play.simulation_stopped?.should be_true

      operation = play.context.current_operation
      operation.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Market)
      operation.quantity.should eq(5)
      operation.price.should be_close(9.50, JediSpec::EPSILON)
      operation.stock.should eq(105)
    end
  end
end
