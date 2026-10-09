require "../support/jedi_spec_helper"

describe Jedi::TradingSystem::Money do
  it "parses the risk, objective and number of down steps" do
    money = Jedi::TradingSystem::Money.parse(" r:1.5%, o:2, n:3 ").not_nil!

    money.risk_rate.should be_close(0.015, JediSpec::EPSILON)
    money.target_coeff.should be_close(2.0, JediSpec::EPSILON)
    money.steps_down.should eq(3)
  end

  it "returns nil for nil or blank definitions" do
    Jedi::TradingSystem::Money.parse(nil).should be_nil
    Jedi::TradingSystem::Money.parse("").should be_nil
    Jedi::TradingSystem::Money.parse("   ").should be_nil
  end

  it "computes the maximum risk and target amount from the dedicated capital" do
    money = Jedi::TradingSystem::Money.new(0.015, 2.0, 3)

    money.risk_amount(20_000.0).should be_close(300.0, JediSpec::EPSILON)
    money.target_amount(20_000.0).should be_close(600.0, JediSpec::EPSILON)
  end

  it "serializes to the canonical user-facing definition" do
    money = Jedi::TradingSystem::Money.new(0.015, 2.0, 3)

    money.to_s.should eq("r:1.5%, o:2.0, n:3")
  end

  it "rejects definitions with missing attributes" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingSystem::Money.parse("r:1.5%,o:2")
    end
  end

  it "rejects definitions outside configured limits" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingSystem::Money.parse("r:50%,o:2,n:3")
    end
  end
end
