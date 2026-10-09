require "../spec_helper"

private def type_two_scale : Jedi::TradingRules::Scale::Operational
  Jedi::TradingRules::Scale::Operational.new(
    type: Jedi::TradingRules::Scale::Operational::Type::Two,
    definition: "test type II",
    builder: "vr:10%,np:2,nn:2,ki:0%,kb:1",
    ks_values: {
      -2 => 1.50,
      -1 => 1.20,
       0 => 1.00,
       1 => 0.80,
       2 => 0.60,
    },
    emax: 3,
    emin: -3,
    ki: 0.0,
    kb: Jedi::TradingRules::Kb::Pwr,
    vr_value: 0.10,
  )
end

private def type_one_scale : Jedi::TradingRules::Scale::Operational
  Jedi::TradingRules::Scale::Operational.new(
    type: Jedi::TradingRules::Scale::Operational::Type::One,
    definition: "test type I",
    builder: "kc:1.30,1.10,0.90,0.80,ki:0%,kb:1",
    ks_values: {
      -2 => 1.50,
      -1 => 1.20,
       0 => 1.00,
       1 => 0.80,
       2 => 0.60,
    },
    emax: 3,
    emin: -3,
    ki: 0.0,
    kb: Jedi::TradingRules::Kb::Pwr,
    kc_values: {
      -3 => 0.70,
      -2 => 0.80,
      -1 => 0.90,
       0 => 1.00,
       1 => 1.10,
       2 => 1.20,
       3 => 1.30,
    },
  )
end

describe Jedi::Tools::PositionSizer do
  it "derives a type-II stop distance from two downward scale steps" do
    sizing = Jedi::Tools::PositionSizer.new(type_two_scale).calculate(
      capital: 10_000.0,
      risk_rate: 0.01,
      entry_price: 100.0,
      stop_steps: 2,
    )

    sizing.stop_price.should be_close(81.0, 0.000_001)
    sizing.risk_distance.should be_close(0.19, 0.000_001)
    sizing.risk_amount.should eq(100.0)
    sizing.maximum_quantity_by_risk.should eq(5)
  end

  it "derives a type-I stop distance from the scale coefficients" do
    sizing = Jedi::Tools::PositionSizer.new(type_one_scale).calculate(
      capital: 10_000.0,
      risk_rate: 0.01,
      entry_price: 100.0,
      stop_steps: 2,
    )

    sizing.stop_price.should be_close(80.0, 0.000_001)
    sizing.risk_distance.should be_close(0.20, 0.000_001)
    sizing.maximum_quantity_by_risk.should eq(5)
  end

  it "uses the lower of risk and capital upper bounds" do
    sizing = Jedi::Tools::PositionSizer.new(type_two_scale).calculate(
      capital: 500.0,
      risk_rate: 0.50,
      entry_price: 100.0,
      stop_steps: 2,
    )

    # For q0 = 1, projected investment is:
    # 100 + 0.20*90 + 0.30*81 = 142.30.
    sizing.maximum_quantity_by_risk.should eq(13)
    sizing.maximum_quantity_by_capital.should eq(3)
    sizing.maximum_quantity.should eq(3)
    sizing.limiting_constraint.capital?.should be_true
    sizing.quantity.should eq(3)
    sizing.maximum_projected_investment.should be_close(426.90, 0.000_001)
  end

  it "accepts a trade when every useful position remains operable" do
    useful = [
      Jedi::TradingRules::Direction::UpWard,
      Jedi::TradingRules::Direction::UpWard,
    ]

    sizing = Jedi::Tools::PositionSizer.new(type_two_scale).calculate(
      capital: 10_000.0,
      risk_rate: 0.02,
      entry_price: 100.0,
      stop_steps: 2,
      minimum_quantity: 2,
      useful_directions: useful,
    )

    # With the real rounding rule, q0 = 9 gives successive stocks 7 and 5,
    # hence two shares on each sell order. Risk allows 10.
    sizing.minimum_operable_quantity.should eq(9)
    sizing.maximum_quantity.should eq(10)
    sizing.operable?.should be_true
    sizing.quantity.should eq(10)
  end

  it "rejects a trade when operability requires more than risk allows" do
    useful = [
      Jedi::TradingRules::Direction::UpWard,
      Jedi::TradingRules::Direction::UpWard,
    ]

    sizing = Jedi::Tools::PositionSizer.new(type_two_scale).calculate(
      capital: 10_000.0,
      risk_rate: 0.01,
      entry_price: 100.0,
      stop_steps: 2,
      minimum_quantity: 4,
      useful_directions: useful,
    )

    # q0 = 19 is the first quantity producing two successive sell orders
    # of at least four shares, while risk permits only 5.
    sizing.minimum_operable_quantity.should eq(19)
    sizing.maximum_quantity.should eq(5)
    sizing.operable?.should be_false
    sizing.failure.should eq(
      Jedi::Tools::PositionSizingFailure::InsufficientOperability,
    )
    sizing.quantity.should eq(0)
  end

  it "projects a type-II level jump with the real coefficient engine" do
    directions = Array.new(
      3,
      Jedi::TradingRules::Direction::UpWard,
    )
    path = Jedi::Tools::PositionSizer.new(type_two_scale).project(
      100.0,
      directions,
    )

    path.map(&.position.to_s).should eq(["0:0:+1", "0:0:+2", "1:0: 0"])
    path[0].price.should be_close(110.0, 0.000_001)
    path[1].price.should be_close(121.0, 0.000_001)
    path[2].price.should be_close(133.1, 0.000_001)
    path.last.price_coefficient.should be_close(1.331, 0.000_001)
  end
end

it "exposes the minimum operable opening quantity for fixed-amount evaluation" do
  useful = [
    Jedi::TradingRules::Direction::UpWard,
    Jedi::TradingRules::Direction::UpWard,
  ]

  minimum = Jedi::Tools::PositionSizer.new(type_two_scale).minimum_operable_quantity(
    entry_price: 100.0,
    minimum_quantity: 2,
    useful_directions: useful,
  )

  minimum.should eq(9)
end
