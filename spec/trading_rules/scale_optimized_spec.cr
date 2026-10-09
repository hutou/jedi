require "../support/jedi_spec_helper"

describe Jedi::TradingRules::Scale do
  it "recognizes a generated optimized type-two scale" do
    JediSpec.with_db do |conn|
      operational = Jedi::TradingRules::Scale::Type
        .new("vr:10.0%, np:2, nn:2, ki:10.0%, kb:0, kd:0.0")
        .decode

      JediSpec.insert_scale(conn, scale: operational)

      scale = Jedi::TradingRules::Scale.new(conn, 1_i64)
      scale.operational.optimized?.should be_true
    end
  end

  it "recognizes a non-optimized canonical type-two scale" do
    JediSpec.with_db do |conn|
      operational = Jedi::TradingRules::Scale::Type
        .new("vr:10.0%, ks:0.8,1.2, ki:0.0%, kb:0")
        .decode

      JediSpec.insert_scale(conn, scale: operational)

      scale = Jedi::TradingRules::Scale.new(conn, 1_i64)
      scale.operational.optimized?.should be_false
    end
  end

  it "recognizes a generated optimized type-one scale" do
    JediSpec.with_db do |conn|
      operational = Jedi::TradingRules::Scale::Type
        .new("kc:1.2,1.1,0.9,0.8, ki:0.0%, kb:0, kd:0.0")
        .decode

      JediSpec.insert_scale(conn, scale: operational)

      scale = Jedi::TradingRules::Scale.new(conn, 1_i64)
      scale.operational.optimized?.should be_true
    end
  end

  it "recognizes a non-optimized canonical type-one scale" do
    JediSpec.with_db do |conn|
      operational = Jedi::TradingRules::Scale::Type
        .new("kc:1.2,1.1,0.9,0.8, ks:0.8,1.2, ki:10.0%, kb:0")
        .decode

      JediSpec.insert_scale(conn, scale: operational)

      scale = Jedi::TradingRules::Scale.new(conn, 1_i64)
      scale.operational.optimized?.should be_false
    end
  end
end
