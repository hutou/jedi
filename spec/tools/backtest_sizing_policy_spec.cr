require "../spec_helper"

private def sizing_scale : Jedi::TradingRules::Scale::Operational
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

describe Jedi::Tools::BacktestSizingPolicy do
  it "keeps the historical fixed-amount behavior" do
    decision = Jedi::Tools::FixedAmountSizingPolicy.new(1_000.0)
      .calculate(33.0, sizing_scale)

    decision.mode.fixed_amount?.should be_true
    decision.quantity.should eq(30)
    decision.amount.should eq(990.0)
    decision.operable?.should be_true
    decision.position_sizing.should be_nil
  end

  it "returns a non-operable capital decision instead of raising" do
    decision = Jedi::Tools::CapitalSizingPolicy.new(
      capital: 10_000.0,
      risk_rate: 0.01,
      stop_steps: 2,
      minimum_quantity: 2,
      operability_steps: 2,
    ).calculate(100.0, sizing_scale)

    decision.mode.capital?.should be_true
    decision.operable?.should be_false
    decision.quantity.should eq(0)
    decision.position_sizing.not_nil!.failure.should eq(
      Jedi::Tools::PositionSizingFailure::InsufficientOperability,
    )
  end

  it "accepts a capital decision when both bounds remain compatible" do
    decision = Jedi::Tools::CapitalSizingPolicy.new(
      capital: 10_000.0,
      risk_rate: 0.02,
      stop_steps: 2,
      minimum_quantity: 2,
      operability_steps: 2,
    ).calculate(100.0, sizing_scale)

    decision.operable?.should be_true
    decision.quantity.should eq(10)
    decision.position_sizing.not_nil!.minimum_operable_quantity.should eq(9)
  end
end
