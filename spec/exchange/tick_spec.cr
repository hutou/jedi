require "../support/jedi_spec_helper"

describe Jedi::Exchange::Security::Tick do
  it "rounds prices upward and downward to the declared tick" do
    tick = Jedi::Exchange::Security::Tick.new(0.05)

    tick.round_down(10.031).should be_close(10.00, JediSpec::EPSILON)
    tick.round_up(10.031).should be_close(10.05, JediSpec::EPSILON)

    tick.price_valid?(10.00).should be_true
    tick.price_valid?(10.05).should be_true
    tick.price_valid?(10.03).should be_false
  end

  it "rounds correctly with fine market ticks" do
    tick = Jedi::Exchange::Security::Tick.new(0.0001)

    tick.round_down(10.123456).should be_close(10.1234, JediSpec::EPSILON)
    tick.round_up(10.123456).should be_close(10.1235, JediSpec::EPSILON)
  end

  it "rejects unsupported tick values" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::Exchange::Security::Tick.new(0.03)
    end
  end
end
