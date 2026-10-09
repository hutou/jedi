require "../support/jedi_spec_helper"

describe Jedi::TradingRules::Scale::Operational do
  it "derives type-two boundaries from the number of ks values" do
    operational = Jedi::TradingRules::Scale::Type
      .new("vr:10.0%, ks:0.7,0.8,1.2,1.3, ki:0.0%, kb:0")
      .decode

    operational.type.should eq(Jedi::TradingRules::Scale::Operational::Type::Two)
    operational.emax.should eq(3)
    operational.emin.should eq(-3)
    operational.ks(2).should be_close(0.70, JediSpec::EPSILON)
    operational.ks(1).should be_close(0.80, JediSpec::EPSILON)
    operational.ks(0).should be_close(1.00, JediSpec::EPSILON)
    operational.ks(-1).should be_close(1.20, JediSpec::EPSILON)
    operational.ks(-2).should be_close(1.30, JediSpec::EPSILON)
  end

  it "derives type-one boundaries from the number of kc values" do
    operational = Jedi::TradingRules::Scale::Type
      .new("kc:1.3,1.2,1.1,0.9,0.8,0.7, ks:0.7,0.8,1.2,1.3, ki:10.0%, kb:0")
      .decode

    operational.type.should eq(Jedi::TradingRules::Scale::Operational::Type::One)
    operational.emax.should eq(3)
    operational.emin.should eq(-3)
    operational.kc(3).should be_close(1.30, JediSpec::EPSILON)
    operational.kc(2).should be_close(1.20, JediSpec::EPSILON)
    operational.kc(1).should be_close(1.10, JediSpec::EPSILON)
    operational.kc(0).should be_close(1.00, JediSpec::EPSILON)
    operational.kc(-1).should be_close(0.90, JediSpec::EPSILON)
    operational.kc(-2).should be_close(0.80, JediSpec::EPSILON)
    operational.kc(-3).should be_close(0.70, JediSpec::EPSILON)
  end

  it "round-trips extended type-two boundaries through JSON" do
    operational = Jedi::TradingRules::Scale::Type
      .new("vr:10.0%, ks:0.7,0.8,1.2,1.3, ki:0.0%, kb:0")
      .decode

    decoded = Jedi::TradingRules::Scale::Operational.from_json(operational.to_json)

    decoded.type.should eq(operational.type)
    decoded.emax.should eq(3)
    decoded.emin.should eq(-3)
    decoded.ks(2).should be_close(0.70, JediSpec::EPSILON)
    decoded.ks(-2).should be_close(1.30, JediSpec::EPSILON)
  end

  it "raises when vr is requested from a type-one scale" do
    expect_raises(Jedi::LowLevelError) do
      JediSpec.type_one_scale.vr
    end
  end

  it "raises when kc is requested from a type-two scale" do
    expect_raises(Jedi::LowLevelError) do
      JediSpec.type_two_scale.kc(1)
    end
  end

  it "raises when ks is requested outside the materialized steps" do
    expect_raises(KeyError) do
      JediSpec.type_two_scale.ks(2)
    end
  end
end
