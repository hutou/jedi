require "../support/jedi_spec_helper"

describe Jedi::TradingSystem::ReInitOption do
  it "parses reset reinitialization" do
    option = Jedi::TradingSystem::ReInitOption.parse("reset, 12.50")

    option.mode.should eq(Jedi::TradingSystem::ReInitMode::Reset)
    option.reset?.should be_true
    option.merge?.should be_false
    option.c0.should be_close(12.50, JediSpec::EPSILON)
  end

  it "parses merge reinitialization" do
    option = Jedi::TradingSystem::ReInitOption.parse("merge,8.75")

    option.mode.should eq(Jedi::TradingSystem::ReInitMode::Merge)
    option.merge?.should be_true
    option.reset?.should be_false
    option.c0.should be_close(8.75, JediSpec::EPSILON)
  end

  it "serializes to the persisted settings format" do
    Jedi::TradingSystem::ReInitOption
      .new(Jedi::TradingSystem::ReInitMode::Merge, 8.75)
      .to_s
      .should eq("merge,8.75")
  end

  it "rejects malformed reinitialization definitions" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingSystem::ReInitOption.parse("merge")
    end

    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingSystem::ReInitOption.parse("unknown,10.0")
    end

    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingSystem::ReInitOption.parse("reset,not-a-price")
    end
  end
end
