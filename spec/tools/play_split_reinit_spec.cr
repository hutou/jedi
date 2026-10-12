require "../support/play_spec_helper"

describe Jedi::Tools::Play, "combined split and reinit" do
  it "resets a reverse split and continues without applying the split twice" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=1790,c0=0.8,tick=0.01",
      ["split=1:10,reinit=reset,12.0", "1", "-1"]
    ) do |play|
      settings = JediPlaySpec.settings_rows(play).last
      operations = JediPlaySpec.operations(play)
      settings.q0.should eq(179.0)
      settings.c0.should eq(12.0)
      operations.size.should eq(3)
      operations[1].stock.should eq(143)
      operations[1].quantity.should eq(36)
      operations[1].price.should be_close(13.2, JediSpec::EPSILON)
      operations[2].stock.should eq(179)
      operations[2].quantity.should eq(36)
      operations[2].price.should be_close(11.87, JediSpec::EPSILON)
    end
  end

  it "uses the reset price immediately for a type-II scale even without a split" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["reinit=reset,12.0", "1"]
    ) do |play|
      operation = play.context.current_operation
      operation.quantity.should eq(20)
      operation.price.should be_close(13.2, JediSpec::EPSILON)
      operation.stock.should eq(80)
    end
  end

  it "handles a target price after resetting the split reference" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=1790,c0=0.8,tick=0.01",
      ["split=1:10,reinit=reset,12.0", "10.8"]
    ) do |play|
      operations = JediPlaySpec.operations(play)
      operations.size.should eq(2)
      operations.last.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      operations.last.stock.should eq(215)
      operations.last.price.should be_close(10.8, JediSpec::EPSILON)
    end
  end

  it "merges a manual buy in new units and resumes automatic orders" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=1790,c0=0.8,tick=0.01",
      ["split=1:10", "reinit=merge,12.0", "21@10.0", "1"]
    ) do |play|
      settings = JediPlaySpec.settings_rows(play).last
      operations = JediPlaySpec.operations(play)
      settings.split.to_s.should eq("1:10")
      settings.q0.should eq(200.0)
      settings.c0.should be_close(11.79, JediSpec::EPSILON)
      operations.size.should eq(3)
      operations[1].stock.should eq(200)
      operations[1].quantity.should eq(21)
      operations[1].position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      operations[2].stock.should eq(160)
      operations[2].quantity.should eq(40)
      operations[2].price.should be_close(11.0, JediSpec::EPSILON)
    end
  end

  it "merges a manual sale in new units and resumes automatic orders" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=1790,c0=0.8,tick=0.01",
      ["reinit=merge,12.0,split=1:10", "-20@14.0", "1"]
    ) do |play|
      settings = JediPlaySpec.settings_rows(play).last
      operations = JediPlaySpec.operations(play)
      settings.q0.should eq(159.0)
      settings.c0.should be_close(11.7484, JediSpec::EPSILON)
      operations[1].stock.should eq(159)
      operations[2].stock.should eq(127)
      operations[2].quantity.should eq(32)
      operations[2].price.should be_close(15.41, JediSpec::EPSILON)
    end
  end

  it "allows selling more than the old stock after a division for reset and merge" do
    ["reset", "merge"].each do |mode|
      JediPlaySpec.with_seeded_play(
        "scale=S_TEST,q0=100,c0=24,tick=0.01",
        ["split=2:1,reinit=#{mode},12.0", "-150@12.0"]
      ) do |play|
        play.context.current_operation.stock.should eq(50)
        play.context.current_operation.sell.should eq(180_000)
      end
    end
  end

  it "rejects a manual sale exceeding the new stock after a reverse split" do
    ["reset", "merge"].each do |mode|
      ex = expect_raises(Jedi::LowLevelError) do
        JediPlaySpec.with_seeded_play(
          "scale=S_TEST,q0=1790,c0=0.8,tick=0.01",
          ["split=1:10,reinit=#{mode},12.0", "-180@12.0"]
        ) do |_play|
        end
      end
      ex.key.should eq("tools.play.short_selling_prohibited")
    end
  end

  it "still requires a manual operation before automatic steps after a combined merge" do
    ex = expect_raises(Jedi::LowLevelError) do
      JediPlaySpec.with_seeded_play(
        "scale=S_TEST,q0=1790,c0=0.8,tick=0.01",
        ["split=1:10,reinit=merge,12.0", "1"]
      ) do |_play|
      end
    end
    ex.key.should eq("tools.play.reinit_merge_manual_operation")
  end

  it "allows loss-trigger changes while a combined merge is pending" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=1790,c0=0.8,tick=0.01",
      ["split=1:10,reinit=merge,12.0", "loss=active", "21@10.0"]
    ) do |play|
      play.loss_trigger.should eq(Jedi::Tools::Play::LossTrigger::Active)
      play.context.current_operation.stock.should eq(200)
    end
  end

  it "keeps sync incompatible with the combined settings change" do
    ex = expect_raises(Jedi::LowLevelError) do
      JediPlaySpec.with_seeded_play(
        "scale=S_TEST,q0=100,c0=10,tick=0.01",
        ["split=2:1,reinit=reset,8.5,sync=0:0:0"]
      ) do |_play|
      end
    end
    ex.key.should eq("tools.play.reinit_split_sync_exclusive")
  end

  it "liquidates only the new stock when the simulated loss stop is active" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=1790,c0=1,tick=0.01,money=r:1.5%,o:2,n:2,loss=active",
      ["split=1:10,reinit=reset,10.0", "-1"]
    ) do |play|
      operation = play.context.current_operation
      operation.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      operation.mode.should eq(Jedi::TradingLife::Operation::Mode::StopLoss)
      operation.quantity.should eq(179)
      operation.price.should be_close(8.32, JediSpec::EPSILON)
      operation.stock.should eq(0)
    end
  end
end
