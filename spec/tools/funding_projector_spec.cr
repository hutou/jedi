require "../spec_helper"

describe Jedi::Tools::FundingProjector do
  it "projects the maximum additional net investment across both branches" do
    scale = JediSpec.type_two_scale

    projection = Jedi::Tools::FundingProjector.new(3).candidate(
      scale: scale,
      quantity: 100,
      price: 10.0,
    )

    projection.current_investment.should be_close(1_000.0, JediSpec::EPSILON)
    projection.maximum_investment.should be_close(1_386.55, JediSpec::EPSILON)
    projection.reserve.should be_close(386.55, JediSpec::EPSILON)
  end

  it "includes upward buy-stop trajectories of a non-optimized scale" do
    scale = JediSpec.type_two_scale(ki: 0.20)
    scale.optimized?.should be_false

    projection = Jedi::Tools::FundingProjector.new(3).candidate(
      scale: scale,
      quantity: 100,
      price: 10.0,
    )

    # The maximum is reached by an upward/upward/downward trajectory.
    # This regression protects non-optimized scales: funding must not be
    # reduced to down-limit buys only.
    projection.maximum_investment.should be_close(1_227.70, JediSpec::EPSILON)
    projection.reserve.should be_close(227.70, JediSpec::EPSILON)
  end

  it "starts an existing trade from its real current net investment" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      projection = Jedi::Tools::FundingProjector.new(1).trade(JediSpec.trade(conn))

      projection.current_investment.should be_close(1_000.0, JediSpec::EPSILON)
      projection.maximum_investment.should be_close(1_180.0, JediSpec::EPSILON)
      projection.reserve.should be_close(180.0, JediSpec::EPSILON)
    end
  end
end
