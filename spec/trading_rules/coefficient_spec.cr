require "../support/jedi_spec_helper"

describe Jedi::TradingRules::Coefficient do
  it "updates type-one coefficients when crossing an upward scale level" do
    coefficient = Jedi::TradingRules::Coefficient.new(
      opscale: JediSpec.type_one_scale,
      q0: 100.0,
      c0: 10.0,
      kcpc: 1.0,
      kspc: 1.0,
      start_position: Jedi::TradingRules::Position.new("0:0:+1"),
      next_position: Jedi::TradingRules::Position.new("1:0:0"),
      price: 10.0,
      kcp: 1.0,
      origin: Jedi::TradingRules::Origin::FromOrder,
      price_direction: Jedi::TradingRules::Direction::UpWard,
      settings_operations_count: 1
    )

    coefficient.kcp.should be_close(1.2, JediSpec::EPSILON)
    coefficient.ksp.should be_close(1.1 / 1.2, JediSpec::EPSILON)
    coefficient.cpe.should be_close(12.0, JediSpec::EPSILON)
    coefficient.spe.should be_close(100.0 * (1.1 / 1.2), JediSpec::EPSILON)
  end

  it "computes type-two coefficients for a standard downward step" do
    coefficient = Jedi::TradingRules::Coefficient.new(
      opscale: JediSpec.type_two_scale,
      q0: 100.0,
      c0: 10.0,
      kcpc: 1.0,
      kspc: 1.0,
      start_position: Jedi::TradingRules::Position.new("0:0:0"),
      next_position: Jedi::TradingRules::Position.new("0:0:-1"),
      price: 10.0,
      kcp: 1.0,
      origin: Jedi::TradingRules::Origin::FromOrder,
      price_direction: Jedi::TradingRules::Direction::DownWard,
      settings_operations_count: 1
    )

    coefficient.kcp.should be_close(1.0, JediSpec::EPSILON)
    coefficient.ksp.should be_close(1.0, JediSpec::EPSILON)
    coefficient.cpe.should be_close(9.0, JediSpec::EPSILON)
    coefficient.spe.should be_close(120.0, JediSpec::EPSILON)
  end

  it "recomputes kcp when a type-two scale jumps to a new level" do
    coefficient = Jedi::TradingRules::Coefficient.new(
      opscale: JediSpec.type_two_scale(ki: 0.10),
      q0: 100.0,
      c0: 10.0,
      kcpc: 1.0,
      kspc: 1.0,
      start_position: Jedi::TradingRules::Position.new("0:0:+1"),
      next_position: Jedi::TradingRules::Position.new("1:0:0"),
      price: 10.0,
      kcp: 1.0,
      origin: Jedi::TradingRules::Origin::FromOrder,
      price_direction: Jedi::TradingRules::Direction::UpWard,
      settings_operations_count: 1
    )

    coefficient.kcp.should be_close(1.10, JediSpec::EPSILON)
    coefficient.ksp.should be_close(1.0, JediSpec::EPSILON)
    coefficient.cpe.should be_close(11.0, JediSpec::EPSILON)
    coefficient.spe.should be_close(100.0, JediSpec::EPSILON)
  end
end
