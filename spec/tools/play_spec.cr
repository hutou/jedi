require "../support/jedi_spec_helper"

describe Jedi::Tools::Play do
  it "parses loss trigger mode with fallback as default" do
    Jedi::Tools::Play.parse_loss_trigger(nil).should eq(Jedi::Tools::Play::LossTrigger::Fallback)
    Jedi::Tools::Play.parse_loss_trigger("").should eq(Jedi::Tools::Play::LossTrigger::Fallback)
    Jedi::Tools::Play.parse_loss_trigger("active").should eq(Jedi::Tools::Play::LossTrigger::Active)
    Jedi::Tools::Play.parse_loss_trigger("fallback").should eq(Jedi::Tools::Play::LossTrigger::Fallback)
  end

  it "parses play command tokens into typed actions" do
    actions = Jedi::Tools::Play::CommandParser.new.parse([
      "2x1,-1",
      "12.50",
      "-3@9.75",
      "scale=S2,loss=active",
      "money=r:1.5%,o:2,n:2",
    ])

    actions[0].as(Jedi::Tools::Play::StepAction).steps.should eq([1, -1, 1, -1])
    actions[1].as(Jedi::Tools::Play::TargetPriceAction).price.should be_close(12.50, JediSpec::EPSILON)

    manual = actions[2].as(Jedi::Tools::Play::ManualOperationAction)
    manual.quantity.should eq(-3)
    manual.price.should be_close(9.75, JediSpec::EPSILON)

    settings = actions[3].as(Jedi::Tools::Play::SettingsChangeAction)
    settings.scale_name.should eq("S2")
    settings.loss_trigger.should eq(Jedi::Tools::Play::LossTrigger::Active)

    money = actions[4].as(Jedi::Tools::Play::TradeMoneyChangeAction)
    money.money_raw.should eq("r:1.5%,o:2,n:2")
  end

  it "simulates a simple up/down sequence from a seeded trade" do
    JediSpec.with_db do |main_conn|
      JediSpec.insert_scale(main_conn, name: "S_TEST", scale: JediSpec.type_two_scale)

      JediSpec.with_db do |memory_conn|
        play = Jedi::Tools::Play.new(
          main_conn,
          memory_conn,
          "scale=S_TEST,q0=100,c0=10,tick=0.01",
          ["1", "-1"]
        )

        play.new_operations_count.should eq(2)
        play.context.running_orders.size.should eq(2)
        play.context.current_operation.stock.should eq(100)
        play.context.current_operation.price.should be_close(9.9, JediSpec::EPSILON)
        play.context.current_operation.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      end
    end
  end

  it "selects the active stoploss before the down limit only after risk is exceeded" do
    JediSpec.with_db do |main_conn|
      JediSpec.insert_scale(main_conn, name: "S_TEST", scale: JediSpec.type_two_scale)

      JediSpec.with_db do |memory_conn|
        play = Jedi::Tools::Play.new(
          main_conn,
          memory_conn,
          "scale=S_TEST,q0=100,c0=10,tick=0.01,money=r:1.5%,o:2,n:2,loss=active",
          ["-1", "-1"]
        )

        play.context.running_orders.size.should eq(2)

        first = play.context.running_orders[0]
        first.key.should eq(:down)
        first.orders.has_key?(:down).should be_true
        first.orders.has_key?(:loss).should be_false

        second = play.context.running_orders[1]
        second.key.should eq(:loss)
        second.orders.has_key?(:down).should be_true
        second.orders.has_key?(:loss).should be_true
        second.orders[:loss].kind.should eq(Jedi::TradingSystem::TradeStop::Kind::CL)

        play.context.current_operation.mode.should eq(Jedi::TradingLife::Operation::Mode::StopLoss)
        play.context.current_operation.stock.should eq(0)
      end
    end
  end

  it "keeps the down limit before the stoploss when loss trigger is fallback" do
    JediSpec.with_db do |main_conn|
      JediSpec.insert_scale(main_conn, name: "S_TEST", scale: JediSpec.type_two_scale)

      JediSpec.with_db do |memory_conn|
        play = Jedi::Tools::Play.new(
          main_conn,
          memory_conn,
          "scale=S_TEST,q0=100,c0=10,tick=0.01,money=r:1.5%,o:2,n:2,loss=fallback",
          ["-1", "-1"]
        )

        play.context.running_orders.size.should eq(2)
        play.context.running_orders[0].key.should eq(:down)

        second = play.context.running_orders[1]
        second.key.should eq(:down)
        second.orders.has_key?(:down).should be_true
        second.orders.has_key?(:loss).should be_true

        play.context.current_operation.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
        play.context.current_operation.stock.should be > 0
      end
    end
  end

  it "identifies the operation that first triggers each upward operability warning" do
    JediSpec.with_db do |main_conn|
      JediSpec.with_db do |memory_conn|
        Jedi::Tools::Play.new(
          main_conn,
          memory_conn,
          "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,q0=100,c0=10,tick=0.01",
          ["6"]
        )

        warnings = Jedi::App.messages.select(&.key.==("tools.play.warning"))
        warnings.map { |warning| warning.params[:operation] }.should eq(["1", "2", "6"])
        warnings.map { |warning| warning.params[:warning] }.should eq([
          I18n.t("trade.orders.operating_mode_warning"),
          I18n.t("trade.orders.operating_mode_degraded", {key: :up, quantity: "1"}),
          I18n.t("trade.orders.operating_mode_blocked", {key: :up, quantity: "0"}),
        ])
      end
    end
  end

  it "does not report upward operability warnings during a downward simulation" do
    JediSpec.with_db do |main_conn|
      JediSpec.with_db do |memory_conn|
        Jedi::Tools::Play.new(
          main_conn,
          memory_conn,
          "scale=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1,q0=100,c0=10,tick=0.01",
          ["-6"]
        )

        Jedi::App.messages.none?(&.key.==("tools.play.warning")).should be_true
      end
    end
  end
end
