require "../support/jedi_spec_helper"

private def scoring_with(conn)
  Jedi::Tools::Scoring.new(conn, conn, "/tmp/jedi_scoring_spec.csv", "")
end

describe Jedi::Tools::Scoring do
  it "groups kc values by contiguous upward and downward windows" do
    JediSpec.with_db do |conn|
      scoring = scoring_with(conn)

      groups = scoring.groups([1.30, 1.20, 1.10, 0.90, 0.80], 2)

      groups.size.should eq(3)
      groups.should contain([1.30, 1.20, 0.90, 0.80])
      groups.should contain([1.20, 1.10, 0.90, 0.80])
      groups.should contain([1.30, 1.20, 1.10, 0.90, 0.80])
    end
  end

  it "builds contiguous windows with the requested minimum size" do
    JediSpec.with_db do |conn|
      scoring = scoring_with(conn)

      scoring.make_groups([1.30, 1.20, 1.10], 2).should eq([
        [1.30, 1.20],
        [1.20, 1.10],
        [1.30, 1.20, 1.10],
      ])
    end
  end

  it "decodes a score-one builder into type-one canonical scale definitions" do
    JediSpec.with_db do |conn|
      scoring = scoring_with(conn)

      scaledefs = scoring.decode(
        "kc:1.2,1.1,0.9,0.8, ki:0.0%, kb:0, kd:0.0, mg:2"
      )

      scaledefs.size.should eq(1)

      scaledef, scalebuild = scaledefs.first
      operational = Jedi::TradingRules::Scale::Type.new(scaledef).decode

      operational.type.should eq(Jedi::TradingRules::Scale::Operational::Type::One)
      operational.emax.should eq(2)
      operational.emin.should eq(-2)
      operational.kc(2).should be_close(1.20, JediSpec::EPSILON)
      operational.kc(-2).should be_close(0.80, JediSpec::EPSILON)
      operational.ks(1).should be < 1.0
      operational.ks(-1).should be > 1.0
      scalebuild.should contain("kc:1.2,1.1,0.9,0.8")
      scoring.scale_builder.should contain("kc:1.2,1.1,0.9,0.8")
    end
  end

  it "decodes a score-two builder into type-two canonical scale definitions" do
    JediSpec.with_db do |conn|
      scoring = scoring_with(conn)

      scaledefs = scoring.decode(
        "vr:10.0%, np:2, nn:2, ki:0.0%, kb:0, kd:0.0"
      )

      scaledefs.size.should eq(1)

      scaledef, scalebuild = scaledefs.first
      operational = Jedi::TradingRules::Scale::Type.new(scaledef).decode

      operational.type.should eq(Jedi::TradingRules::Scale::Operational::Type::Two)
      operational.vr.should be_close(0.10, JediSpec::EPSILON)
      operational.emax.should eq(2)
      operational.emin.should eq(-2)
      operational.ks(1).should be < 1.0
      operational.ks(-1).should be > 1.0
      scalebuild.should contain("np:2")
      scalebuild.should contain("nn:2")
    end
  end

  it "decodes a score-three builder into type-one scale definitions generated from vr" do
    JediSpec.with_db do |conn|
      scoring = scoring_with(conn)

      scaledefs = scoring.decode(
        "vr:10.0%, np:2, nn:2, ki:0.0%, kb:0, kd:0.0, mg:2"
      )

      scaledefs.size.should eq(1)

      scaledef, scalebuild = scaledefs.first
      operational = Jedi::TradingRules::Scale::Type.new(scaledef).decode

      operational.type.should eq(Jedi::TradingRules::Scale::Operational::Type::One)
      operational.emax.should eq(2)
      operational.emin.should eq(-2)
      operational.kc(2).should be_close(1.21, JediSpec::EPSILON)
      operational.kc(1).should be_close(1.10, JediSpec::EPSILON)
      operational.kc(-1).should be_close(0.90, JediSpec::EPSILON)
      operational.kc(-2).should be_close(0.81, JediSpec::EPSILON)

      # score-three uses vr/np/nn only to generate the kc list.
      # The persisted builder is the generated type-one builder, not the raw vr builder.
      scalebuild.should contain("kc:1.21,1.1,0.9,0.81")
      scalebuild.should contain("ki:0%")
      scalebuild.should contain("kd:0.0")
    end
  end

  it "rejects a score-three builder when np is not scalar" do
    JediSpec.with_db do |conn|
      scoring = scoring_with(conn)

      expect_raises(Jedi::LowLevelError) do
        scoring.decode(
          "vr:10.0%, np:2,3, nn:2, ki:0.0%, kb:0, kd:0.0, mg:2"
        )
      end
    end
  end

  it "rejects a score-three builder when nn is not scalar" do
    JediSpec.with_db do |conn|
      scoring = scoring_with(conn)

      expect_raises(Jedi::LowLevelError) do
        scoring.decode(
          "vr:10.0%, np:2, nn:2,3, ki:0.0%, kb:0, kd:0.0, mg:2"
        )
      end
    end
  end

  it "rejects unsupported scoring builder keyword combinations" do
    JediSpec.with_db do |conn|
      scoring = scoring_with(conn)

      expect_raises(Jedi::LowLevelError) do
        scoring.decode("vr:10.0%, np:2")
      end
    end
  end
end
