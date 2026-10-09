require "../support/jedi_spec_helper"

describe Jedi::TradingRules::Position do
  it "parses compact and labeled position definitions" do
    compact = Jedi::TradingRules::Position.new("1:2:-1")
    labeled = Jedi::TradingRules::Position.new("x:1,y:2,e:-1")

    compact.should eq(labeled)
    compact.coords.should eq({1, 2, -1})
  end

  it "accepts explicit plus signs in the scale step" do
    position = Jedi::TradingRules::Position.new("1:0:+1")

    position.coords.should eq({1, 0, 1})
  end

  it "rejects malformed position definitions" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingRules::Position.new("1:+0:0")
    end
  end

  it "rejects negative jump counters" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingRules::Position.new(-1, 0, 0)
    end
  end

  it "resets jumps but keeps the current scale step" do
    position = Jedi::TradingRules::Position.new("3:2:+1")

    position.reset_jumps.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
  end

  it "detects a level jump between two positions" do
    start_position = Jedi::TradingRules::Position.new("0:0:+1")
    next_position = Jedi::TradingRules::Position.new("1:0:0")

    start_position.jump?(next_position).should be_true
    start_position.jump?(Jedi::TradingRules::Position.new("0:0:0")).should be_false
  end

  it "moves upward inside the current level" do
    position = Jedi::TradingRules::Position.new("0:0:0")

    position.upmove(2).should eq(Jedi::TradingRules::Position.new("0:0:+1"))
  end

  it "jumps upward when reaching emax" do
    position = Jedi::TradingRules::Position.new("0:0:+1")

    position.upmove(2).should eq(Jedi::TradingRules::Position.new("1:0:0"))
  end

  it "moves downward inside the current level" do
    position = Jedi::TradingRules::Position.new("0:0:0")

    position.downmove(-2).should eq(Jedi::TradingRules::Position.new("0:0:-1"))
  end

  it "jumps downward when reaching emin" do
    position = Jedi::TradingRules::Position.new("0:0:-1")

    position.downmove(-2).should eq(Jedi::TradingRules::Position.new("0:1:0"))
  end
end
