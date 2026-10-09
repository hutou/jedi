require "../support/play_spec_helper"

module JediPlayTickSpec
  extend self

  def price_on_tick?(price : Float64, tick : Float64) : Bool
    ratio = price / tick
    (ratio - ratio.round).abs <= JediSpec::EPSILON
  end
end

describe Jedi::Tools::Play do
  it "executes upward orders on a valid tick after split" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.05",
      ["split=3:2", "1"]
    ) do |play|
      operations = JediPlaySpec.operations(play)
      operations.size.should eq(2)

      final_operation = operations.last
      final_operation.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      final_operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      JediPlayTickSpec.price_on_tick?(final_operation.price, 0.05).should be_true
    end
  end

  it "executes downward orders on a valid tick after reinit reset" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.05",
      ["reinit=reset,8.37", "-1"]
    ) do |play|
      operations = JediPlaySpec.operations(play)
      operations.size.should eq(2)

      final_operation = operations.last
      final_operation.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      final_operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      JediPlayTickSpec.price_on_tick?(final_operation.price, 0.05).should be_true
    end
  end

  it "executes stoploss orders on a valid tick when loss trigger is active" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.05,money=r:1.5%,o:2,n:2,loss=active",
      ["-1", "-1"]
    ) do |play|
      final_operation = play.context.current_operation

      final_operation.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      final_operation.mode.should eq(Jedi::TradingLife::Operation::Mode::StopLoss)
      final_operation.stock.should eq(0)
      JediPlayTickSpec.price_on_tick?(final_operation.price, 0.05).should be_true
    end
  end
end
