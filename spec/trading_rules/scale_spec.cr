require "../support/jedi_spec_helper"

describe Jedi::TradingRules::Scale do
  it "decodes a canonical type-two scale definition" do
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

  it "decodes an optimized type-two scale and materializes intermediate steps" do
    operational = Jedi::TradingRules::Scale::Type
      .new("vr:10.0%, np:2, nn:2, ki:10.0%, kb:0, kd:0.0")
      .decode

    operational.type.should eq(Jedi::TradingRules::Scale::Operational::Type::Two)
    operational.vr.should be_close(0.10, JediSpec::EPSILON)
    operational.emax.should eq(2)
    operational.emin.should eq(-2)
    operational.ks(1).should be_close(0.95, JediSpec::EPSILON)
    operational.ks(-1).should be_close(1.06, JediSpec::EPSILON)
  end

  it "round-trips an operational scale through JSON" do
    operational = JediSpec.type_two_scale
    decoded = Jedi::TradingRules::Scale::Operational.from_json(operational.to_json)

    decoded.type.should eq(operational.type)
    decoded.emax.should eq(operational.emax)
    decoded.emin.should eq(operational.emin)
    decoded.vr.should be_close(operational.vr, JediSpec::EPSILON)
    decoded.ks(1).should be_close(operational.ks(1), JediSpec::EPSILON)
    decoded.ks(-1).should be_close(operational.ks(-1), JediSpec::EPSILON)
  end

  it "loads its operational definition from the database" do
    JediSpec.with_db do |conn|
      JediSpec.insert_scale(conn, name: "S_DB", scale: JediSpec.type_two_scale)

      scale = Jedi::TradingRules::Scale.new(conn, "S_DB")

      scale.name.should eq("S_DB")
      scale.operational.type.should eq(Jedi::TradingRules::Scale::Operational::Type::Two)
      scale.operational.vr.should be_close(0.10, JediSpec::EPSILON)
    end
  end
end
