require "../support/play_spec_helper"

describe Jedi::Tools::Play do
  it "requires a manual operation immediately after reinit merge" do
    ex = expect_raises(Jedi::LowLevelError) do
      JediPlaySpec.with_seeded_play(
        "scale=S_TEST,q0=100,c0=10,tick=0.01",
        ["reinit=merge,9.0", "1"]
      ) do |_play|
      end
    end
    ex.key.should eq("tools.play.reinit_merge_manual_operation")
  end

  it "allows a loss-trigger-only change while reinit merge is pending" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["reinit=merge,9.0", "loss=active", "10@8.0"]
    ) do |play|
      play.loss_trigger.should eq(Jedi::Tools::Play::LossTrigger::Active)
      play.new_operations_count.should eq(1)
      play.context.current_operation.stock.should eq(110)
    end
  end

  it "resolves reinit merge with the following manual operation" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["reinit=merge,9.0", "10@8.0"]
    ) do |play|
      # After reinit=merge,9.0, the current settings row is intentionally pending.
      settings = play.context.current_settings
      settings.q0.should be_close(0.0, JediSpec::EPSILON)
      settings.c0.should be_close(0.0, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))

      # After operation 10@8.0.
      operation = play.context.current_operation
      operation.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Market)
      operation.quantity.should eq(10)
      operation.price.should be_close(8.0, JediSpec::EPSILON)
      operation.stock.should eq(110)
      operation.trade_invest.should eq(108_000)

      # Updated settings after operation.
      settings = JediPlaySpec.settings_rows(play).last
      reinit = settings.reinit.not_nil!
      reinit.merge?.should be_true
      settings.q0.should be_close(110.0, JediSpec::EPSILON)
      settings.c0.should be_close(8.9091, JediSpec::EPSILON)

      # Position unchanged after operation.
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
    end
  end

  it "continues correctly after resolving reinit merge with a manual operation" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["reinit=merge,9.0", "10@8.0", "1"]
    ) do |play|
      operations = JediPlaySpec.operations(play)

      # Initial operation + manual merge operation + automatic upward operation.
      operations.size.should eq(3)

      # Manual operation 10@8.0.
      manual_operation = operations[1]
      manual_operation.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      manual_operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Market)
      manual_operation.quantity.should eq(10)
      manual_operation.price.should be_close(8.0, JediSpec::EPSILON)
      manual_operation.stock.should eq(110)
      manual_operation.trade_invest.should eq(108_000)
      manual_operation.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))

      # Updated settings after manual operation.
      settings = JediPlaySpec.settings_rows(play).last
      settings.q0.should be_close(110.0, JediSpec::EPSILON)
      settings.c0.should be_close(8.9091, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))

      # Order selected for the following upward action.
      play.context.running_orders.size.should eq(1)
      running_order = play.context.running_orders.last
      running_order.key.should eq(:up)
      running_order.orders.has_key?(:up).should be_true

      up_order = running_order.orders[:up]
      up_order.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      up_order.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      up_order.quantity.should eq(22)
      up_order.price.should be_close(8.8, JediSpec::EPSILON)
      up_order.position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))

      # Final operation executed from action "1".
      final_operation = operations[2]
      final_operation.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      final_operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      final_operation.quantity.should eq(22)
      final_operation.price.should be_close(8.8, JediSpec::EPSILON)
      final_operation.stock.should eq(88)
      final_operation.trade_invest.should eq(88_640)
      final_operation.position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))

      play.context.current_operation.id.should eq(final_operation.id)
    end
  end

  it "reset reinitializes the reference from the current stock and requested c0" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["-1", "reinit=reset,8.5"]
    ) do |play|
      settings = play.context.current_settings
      reinit = settings.reinit.not_nil!

      reinit.reset?.should be_true
      settings.q0.should be_close(120.0, JediSpec::EPSILON)
      settings.c0.should be_close(8.5, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      settings.operations.size.should eq(0)

      play.context.current_operation.stock.should eq(120)
      play.context.current_operation.position.should eq(Jedi::TradingRules::Position.new("0:0:-1"))
    end
  end
end
