require "../support/play_spec_helper"

describe Jedi::Tools::Play do
  it "continues from a synchronized settings position" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["sync=1:0:+1", "1"],
      scale: JediSpec.type_one_scale
    ) do |play|
      settings_rows = JediPlaySpec.settings_rows(play)
      settings_rows.size.should eq(2)

      synced_settings = settings_rows.last
      synced_settings.sync.not_nil!.should eq(Jedi::TradingRules::Position.new("1:0:+1"))
      synced_settings.position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
      synced_settings.q0.should be_close(100.0, JediSpec::EPSILON)
      synced_settings.c0.should be_close(10.0, JediSpec::EPSILON)

      operations = JediPlaySpec.operations(play)
      operations.size.should eq(2)

      final_operation = operations.last
      final_operation.settings_id.should eq(synced_settings.id)
      final_operation.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      final_operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      final_operation.position.should eq(Jedi::TradingRules::Position.new("1:0:0"))

      play.context.running_orders.size.should eq(1)
      play.context.running_orders.last.key.should eq(:up)
    end
  end

  it "applies a split settings row before the next automatic operation" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["split=2:1", "1"]
    ) do |play|
      settings_rows = JediPlaySpec.settings_rows(play)
      settings_rows.size.should eq(2)

      split_settings = settings_rows.last
      split_settings.split.not_nil!.to_s.should eq("2:1")
      split_settings.sync.should be_nil
      split_settings.reinit.should be_nil
      split_settings.q0.should be_close(200.0, JediSpec::EPSILON)
      split_settings.c0.should be_close(5.0, JediSpec::EPSILON)
      split_settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))

      operations = JediPlaySpec.operations(play)
      operations.size.should eq(2)

      final_operation = operations.last
      final_operation.settings_id.should eq(split_settings.id)
      final_operation.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      final_operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      final_operation.quantity.should eq(40)
      final_operation.price.should be_close(5.5, JediSpec::EPSILON)
      final_operation.stock.should eq(160)
      final_operation.position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
    end
  end

  it "rejects sync and split in the same play settings action" do
    expect_raises(Jedi::LowLevelError) do
      JediPlaySpec.with_seeded_play(
        "scale=S_TEST,q0=100,c0=10,tick=0.01",
        ["sync=1:0:0,split=2:1"]
      ) do |_play|
      end
    end
  end

  it "rejects sync and reinit in the same play settings action" do
    expect_raises(Jedi::LowLevelError) do
      JediPlaySpec.with_seeded_play(
        "scale=S_TEST,q0=100,c0=10,tick=0.01",
        ["sync=1:0:0,reinit=reset,8.5"]
      ) do |_play|
      end
    end
  end

  it "combines split and reinit in the same play settings action" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["split=2:1,reinit=reset,8.5"]
    ) do |play|
      settings = JediPlaySpec.settings_rows(play).last
      settings.split.to_s.should eq("2:1")
      settings.reinit.not_nil!.reset?.should be_true
      settings.q0.should be_close(200.0, JediSpec::EPSILON)
      settings.c0.should be_close(8.5, JediSpec::EPSILON)
      JediPlaySpec.operations(play).size.should eq(1)
    end
  end

  it "copies a changed scale into the memory database without creating an operation" do
    JediSpec.with_db do |main_conn|
      JediSpec.insert_scale(main_conn, name: "S_TEST", scale: JediSpec.type_two_scale)
      JediSpec.insert_scale(main_conn, id: 2_i64, name: "S_ALT", scale: JediSpec.type_one_scale)

      JediSpec.with_db do |memory_conn|
        play = Jedi::Tools::Play.new(
          main_conn,
          memory_conn,
          "scale=S_TEST,q0=100,c0=10,tick=0.01",
          ["scale=S_ALT"]
        )

        play.new_operations_count.should eq(0)
        JediPlaySpec.operations(play).size.should eq(1)

        settings_rows = JediPlaySpec.settings_rows(play)
        settings_rows.size.should eq(2)

        new_settings = settings_rows.last
        new_settings.scale.name.should eq("S_alt")
        new_settings.q0.should be_close(100.0, JediSpec::EPSILON)
        new_settings.c0.should be_close(10.0, JediSpec::EPSILON)
        new_settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      end
    end
  end

  it "changes money without creating a settings row" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["money=r:2%,o:2,n:2"]
    ) do |play|
      JediPlaySpec.settings_rows(play).size.should eq(1)
      JediPlaySpec.operations(play).size.should eq(1)

      money = play.mem_trade.money.not_nil!
      money.risk_rate.should be_close(0.02, JediSpec::EPSILON)
      money.target_coeff.should be_close(2.0, JediSpec::EPSILON)
      money.steps_down.should eq(2)
    end
  end
end
