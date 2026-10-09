require "../support/play_spec_helper"

describe Jedi::Tools::Play do
  it "feeds settings correctly after split" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["split=2:1"]
    ) do |play|
      JediPlaySpec.operations(play).size.should eq(1)

      settings = JediPlaySpec.settings_rows(play).last
      settings.split.not_nil!.to_s.should eq("2:1")
      settings.sync.should be_nil
      settings.reinit.should be_nil
      settings.q0.should be_close(200.0, JediSpec::EPSILON)
      settings.c0.should be_close(5.0, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
    end
  end

  it "feeds settings correctly after sync" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["sync=1:0:+1"],
      scale: JediSpec.type_one_scale
    ) do |play|
      JediPlaySpec.operations(play).size.should eq(1)

      settings = JediPlaySpec.settings_rows(play).last
      settings.split.should be_nil
      settings.sync.not_nil!.should eq(Jedi::TradingRules::Position.new("1:0:+1"))
      settings.reinit.should be_nil
      settings.q0.should be_close(100.0, JediSpec::EPSILON)
      settings.c0.should be_close(10.0, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
    end
  end

  it "feeds settings correctly after reinit reset" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["reinit=reset,8.5"]
    ) do |play|
      JediPlaySpec.operations(play).size.should eq(1)

      settings = JediPlaySpec.settings_rows(play).last
      reinit = settings.reinit.not_nil!

      reinit.reset?.should be_true
      settings.q0.should be_close(100.0, JediSpec::EPSILON)
      settings.c0.should be_close(8.5, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      settings.kspc.should be_close(1.0, JediSpec::EPSILON)
      settings.kcpc.should be_close(1.0, JediSpec::EPSILON)
    end
  end

  it "feeds pending settings correctly after reinit merge" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["reinit=merge,9.0"]
    ) do |play|
      JediPlaySpec.operations(play).size.should eq(1)

      settings = JediPlaySpec.settings_rows(play).last
      reinit = settings.reinit.not_nil!

      reinit.merge?.should be_true
      reinit.c0.should be_close(9.0, JediSpec::EPSILON)
      settings.q0.should be_close(0.0, JediSpec::EPSILON)
      settings.c0.should be_close(0.0, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      settings.kspc.should be_close(1.0, JediSpec::EPSILON)
      settings.kcpc.should be_close(1.0, JediSpec::EPSILON)
    end
  end

  it "regression: uses maybe_splitted_price when computing the next order after a split" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["split=2:1", "1"]
    ) do |play|
      operations = JediPlaySpec.operations(play)
      operations.size.should eq(2)

      final_operation = operations.last

      # Regression: after split=2:1, the next upward order must be computed
      # from the adjusted price 5.0, not from the raw previous operation price 10.0.
      final_operation.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      final_operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      final_operation.quantity.should eq(40)
      final_operation.price.should be_close(5.5, JediSpec::EPSILON)
      final_operation.stock.should eq(160)
      final_operation.position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
    end
  end
end
