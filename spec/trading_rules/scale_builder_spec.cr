require "../support/jedi_spec_helper"

describe Jedi::TradingRules::Scale::Builder do
  it "builds a canonical type-one scale" do
    operational = Jedi::TradingRules::Scale::Type
      .new("kc:1.2,1.1,0.9,0.8, ks:0.8,1.2, ki:10.0%, kb:0")
      .decode

    operational.type.should eq(Jedi::TradingRules::Scale::Operational::Type::One)
    operational.emax.should eq(2)
    operational.emin.should eq(-2)
    operational.ki.should be_close(0.10, JediSpec::EPSILON)
    operational.kb.should eq(Jedi::TradingRules::Kb::Pwr)

    operational.kc(2).should be_close(1.20, JediSpec::EPSILON)
    operational.kc(1).should be_close(1.10, JediSpec::EPSILON)
    operational.kc(0).should be_close(1.00, JediSpec::EPSILON)
    operational.kc(-1).should be_close(0.90, JediSpec::EPSILON)
    operational.kc(-2).should be_close(0.80, JediSpec::EPSILON)

    operational.ks(1).should be_close(0.80, JediSpec::EPSILON)
    operational.ks(0).should be_close(1.00, JediSpec::EPSILON)
    operational.ks(-1).should be_close(1.20, JediSpec::EPSILON)
  end

  it "builds a canonical type-two scale" do
    operational = Jedi::TradingRules::Scale::Type
      .new("vr:10.0%, ks:0.8,1.2, ki:0.0%, kb:0")
      .decode

    operational.type.should eq(Jedi::TradingRules::Scale::Operational::Type::Two)
    operational.vr.should be_close(0.10, JediSpec::EPSILON)
    operational.emax.should eq(2)
    operational.emin.should eq(-2)
    operational.ks(1).should be_close(0.80, JediSpec::EPSILON)
    operational.ks(0).should be_close(1.00, JediSpec::EPSILON)
    operational.ks(-1).should be_close(1.20, JediSpec::EPSILON)
  end

  it "builds an optimized type-two scale from np and nn" do
    operational = Jedi::TradingRules::Scale::Type
      .new("vr:10.0%, np:2, nn:2, ki:10.0%, kb:0, kd:0.0")
      .decode

    operational.type.should eq(Jedi::TradingRules::Scale::Operational::Type::Two)
    operational.emax.should eq(2)
    operational.emin.should eq(-2)
    operational.ks(1).should be_close(0.95, JediSpec::EPSILON)
    operational.ks(-1).should be_close(1.06, JediSpec::EPSILON)
  end

  it "keeps the original builder as metadata when the canonical definition is optimized" do
    operational = Jedi::TradingRules::Scale::Type
      .new("vr:10.0%, np:2, nn:2, ki:10.0%, kb:0, kd:0.0")
      .decode

    operational.builder.should contain("np:2")
    operational.builder.should contain("nn:2")
    operational.definition.should contain("vr:10%")
    operational.definition.should contain("ks:")
  end

  it "regression: rejects type-two ks values that are not sorted in the expected order" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingRules::Scale::Type
        .new("vr:10.0%, ks:1.2,0.8, ki:0.0%, kb:0")
        .decode
    end
  end

  it "rejects duplicated ks values" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingRules::Scale::Type
        .new("vr:10.0%, ks:0.8,0.8,1.2, ki:0.0%, kb:0")
        .decode
    end
  end

  it "rejects type-one kc values that are not strictly descending" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingRules::Scale::Type
        .new("kc:1.1,1.2,0.9,0.8, ks:0.8,1.2, ki:10.0%, kb:0")
        .decode
    end
  end

  it "rejects type-one kc and ks lists with incompatible sizes" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingRules::Scale::Type
        .new("kc:1.2,1.1,0.9,0.8, ks:0.7,0.8,1.2, ki:10.0%, kb:0")
        .decode
    end
  end

  it "rejects vr values outside the configured bounds" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingRules::Scale::Type
        .new("vr:1.0%, ks:0.8,1.2, ki:0.0%, kb:0")
        .decode
    end
  end

  it "rejects incomplete builder definitions" do
    # expect_raises(Jedi::LowLevelError) do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingRules::Scale::Type
        .new("vr:10.0%, ks:0.8,1.2")
        .decode
    end
  end

  it "rejects malformed numeric values" do
    expect_raises(Jedi::LowLevelError) do
      Jedi::TradingRules::Scale::Type
        .new("vr:abc, ks:0.8,1.2, ki:0.0%, kb:0")
        .decode
    end
  end
end
