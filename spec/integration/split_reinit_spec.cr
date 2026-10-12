require "../support/jedi_spec_helper"

module JediSplitReinitSpec
  extend self

  def seed_retained_trade(conn, *, scale = JediSpec.type_two_scale) : Nil
    JediSpec.seed_basic_trade(conn, stock: 1500, price: 1.0, scale: scale)
    JediSpec.insert_operation(conn,
      id: 2_i64,
      quantity: 290,
      price: 0.8,
      stock: 1790,
      position: "1:2:-1",
      ksp: 0.7,
      kcp: 0.8,
      timestamp: Time.local(2026, 1, 1, 10, 30, 0),
      buy: 23_200,
      trade_invest: 173_200,
      global_invest: 173_200)
  end

  def create_settings(conn, mode : String, *, split : String = "1:10") : Int64
    Jedi::TradingSystem::SettingsCreator.new(conn).call(
      trade_ident: 1_i64,
      scale_ident: 1_i64,
      timestamp: Time.local(2026, 1, 1, 11, 0, 0),
      option_split: Jedi::Exchange::Security::Split.new(split),
      option_reinit: Jedi::TradingSystem::ReInitOption.parse("#{mode},12.0"))
  end

  def record_operation(conn, type, quantity, price, *, hour : Int32 = 12) : Int64
    Jedi::TradingLife::OperationCreator.new(conn).call(
      trade_ident: 1_i64,
      timestamp: Time.local(2026, 1, 1, hour, 0, 0),
      type: type,
      mode: Jedi::TradingLife::Operation::Mode::Market,
      quantity: quantity,
      price: price,
      cfees: 0.0,
      tickcheck: true)
  end
end

describe "Split and reinit end-to-end" do
  it "resets 1790 old shares to 179 new shares and preserves financial history" do
    JediSpec.with_db do |conn|
      JediSplitReinitSpec.seed_retained_trade(conn)
      settings_id = JediSplitReinitSpec.create_settings(conn, "reset")
      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)
      trade = JediSpec.trade(conn)
      metrics = Jedi::TradingSystem::TradeMetrics.new(trade).calculate.not_nil!

      settings.split.to_s.should eq("1:10")
      settings.reinit.not_nil!.reset?.should be_true
      settings.rank.should eq(2)
      settings.q0.should be_close(179.0, JediSpec::EPSILON)
      settings.c0.should be_close(12.0, JediSpec::EPSILON)
      settings.kspc.should be_close(1.0, JediSpec::EPSILON)
      settings.kcpc.should be_close(1.0, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      settings.operations.empty?.should be_true
      metrics.stock.should eq(179)
      metrics.position.should eq(settings.position)
      metrics.buys.should eq(173_200)
      metrics.current_investment.should eq(173_200)
      metrics.operation_count.should eq(2)
      # Historical transactions keep their original units and position.
      trade.last_operation.not_nil!.stock.should eq(1790)
      trade.last_operation.not_nil!.price.should be_close(0.8, JediSpec::EPSILON)
      trade.last_operation.not_nil!.position.should eq(Jedi::TradingRules::Position.new("1:2:-1"))
    end
  end

  it "computes the first orders from 179 shares and the supplied post-split price for both scale types" do
    [JediSpec.type_one_scale, JediSpec.type_two_scale].each do |scale|
      JediSpec.with_db do |conn|
        JediSplitReinitSpec.seed_retained_trade(conn, scale: scale)
        JediSplitReinitSpec.create_settings(conn, "reset")
        orders = Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn)).orders

        orders[:up].type.should eq(Jedi::TradingLife::Operation::Type::Sell)
        orders[:up].quantity.should eq(36)
        orders[:up].last_stock.should eq(179)
        orders[:up].price.should be_close(13.2, JediSpec::EPSILON)
        orders[:up].position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
        orders[:down].type.should eq(Jedi::TradingLife::Operation::Type::Buy)
        orders[:down].quantity.should eq(36)
        orders[:down].last_stock.should eq(179)
        orders[:down].price.should be_close(10.8, JediSpec::EPSILON)
        orders[:down].position.should eq(Jedi::TradingRules::Position.new("0:0:-1"))
      end
    end
  end

  it "records the first buy against the converted stock" do
    JediSpec.with_db do |conn|
      JediSplitReinitSpec.seed_retained_trade(conn)
      JediSplitReinitSpec.create_settings(conn, "reset")
      id = JediSplitReinitSpec.record_operation(conn, Jedi::TradingLife::Operation::Type::Buy, 36, 10.8)
      operation = Jedi::TradingLife::Operation.new(conn, id)

      operation.stock.should eq(215)
      operation.buy.should eq(38_880)
      operation.trade_invest.should eq(212_080)
      operation.global_invest.should eq(212_080)
      operation.position.should eq(Jedi::TradingRules::Position.new("0:0:-1"))
    end
  end

  it "records a sale and does not apply the split again to the next operation" do
    JediSpec.with_db do |conn|
      JediSplitReinitSpec.seed_retained_trade(conn)
      settings_id = JediSplitReinitSpec.create_settings(conn, "reset")
      id = JediSplitReinitSpec.record_operation(conn, Jedi::TradingLife::Operation::Type::Sell, 36, 13.2)
      operation = Jedi::TradingLife::Operation.new(conn, id)
      operation.stock.should eq(143)
      operation.sell.should eq(47_520)
      operation.trade_invest.should eq(125_680)
      operation.position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))

      orders = Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn)).orders
      orders[:down].last_stock.should eq(143)
      orders[:down].quantity.should eq(36)
      orders[:down].price.should be_close(11.87, JediSpec::EPSILON)
      id = JediSplitReinitSpec.record_operation(conn, Jedi::TradingLife::Operation::Type::Buy, 36, 11.87, hour: 13)
      Jedi::TradingLife::Operation.new(conn, id).stock.should eq(179)
      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)
      settings.q0.should be_close(179.0, JediSpec::EPSILON)
      settings.c0.should be_close(12.0, JediSpec::EPSILON)
    end
  end

  it "merges a manual buy at post-split prices without converting either price again" do
    JediSpec.with_db do |conn|
      JediSplitReinitSpec.seed_retained_trade(conn)
      settings_id = JediSplitReinitSpec.create_settings(conn, "merge")
      pending = Jedi::TradingSystem::Settings.new(conn, settings_id)
      pending.q0.should eq(0.0)
      pending.c0.should eq(0.0)
      pending.split.to_s.should eq("1:10")
      pending.reinit.not_nil!.c0.should eq(12.0)

      id = JediSplitReinitSpec.record_operation(conn, Jedi::TradingLife::Operation::Type::Buy, 21, 10.0)
      operation = Jedi::TradingLife::Operation.new(conn, id)
      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)
      operation.stock.should eq(200)
      operation.buy.should eq(21_000)
      operation.trade_invest.should eq(194_200)
      operation.global_invest.should eq(194_200)
      operation.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      operation.ksp.should eq(1.0)
      operation.kcp.should eq(1.0)
      settings.q0.should eq(200.0)
      settings.c0.should be_close(11.79, JediSpec::EPSILON)

      id = JediSplitReinitSpec.record_operation(conn, Jedi::TradingLife::Operation::Type::Sell, 40, 11.0, hour: 13)
      Jedi::TradingLife::Operation.new(conn, id).stock.should eq(160)
      Jedi::TradingSystem::Settings.new(conn, settings_id).c0.should be_close(11.79, JediSpec::EPSILON)
    end
  end

  it "merges a manual sale using the converted stock and the requested reference" do
    JediSpec.with_db do |conn|
      JediSplitReinitSpec.seed_retained_trade(conn)
      settings_id = JediSplitReinitSpec.create_settings(conn, "merge")
      id = JediSplitReinitSpec.record_operation(conn, Jedi::TradingLife::Operation::Type::Sell, 20, 14.0)
      operation = Jedi::TradingLife::Operation.new(conn, id)
      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)

      operation.stock.should eq(159)
      operation.sell.should eq(28_000)
      operation.trade_invest.should eq(145_200)
      settings.q0.should eq(159.0)
      settings.c0.should be_close(11.7484, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
    end
  end

  it "allows a full sale during merge without dividing by zero" do
    JediSpec.with_db do |conn|
      JediSplitReinitSpec.seed_retained_trade(conn)
      settings_id = JediSplitReinitSpec.create_settings(conn, "merge")
      id = JediSplitReinitSpec.record_operation(conn, Jedi::TradingLife::Operation::Type::Sell, 179, 12.0)

      Jedi::TradingLife::Operation.new(conn, id).stock.should eq(0)
      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)
      settings.q0.should eq(0.0)
      settings.c0.should eq(0.0)
    end
  end

  it "rejects selling more than the converted stock for reset and merge without writing an operation" do
    ["reset", "merge"].each do |mode|
      JediSpec.with_db do |conn|
        JediSplitReinitSpec.seed_retained_trade(conn)
        settings_id = JediSplitReinitSpec.create_settings(conn, mode)
        ex = expect_raises(Jedi::LowLevelError) do
          JediSplitReinitSpec.record_operation(conn, Jedi::TradingLife::Operation::Type::Sell, 180, 12.0)
        end
        ex.key.should eq("operation.create.short_selling_forbidden")
        JediSpec.trade(conn).operations.size.should eq(2)
        Jedi::TradingSystem::Settings.new(conn, settings_id).operations.empty?.should be_true
      end
    end
  end

  it "supports a stock division as well as a reverse split for both reinit modes" do
    ["reset", "merge"].each do |mode|
      JediSpec.with_db do |conn|
        JediSpec.seed_basic_trade(conn, stock: 100, price: 24.0)
        settings_id = JediSplitReinitSpec.create_settings(conn, mode, split: "2:1")
        if mode == "reset"
          settings = Jedi::TradingSystem::Settings.new(conn, settings_id)
          settings.q0.should eq(200.0)
          settings.c0.should eq(12.0)
        end
        id = JediSplitReinitSpec.record_operation(conn, Jedi::TradingLife::Operation::Type::Buy, 20, 10.0)
        Jedi::TradingLife::Operation.new(conn, id).stock.should eq(220)
        if mode == "merge"
          settings = Jedi::TradingSystem::Settings.new(conn, settings_id)
          settings.q0.should eq(220.0)
          settings.c0.should be_close(11.8182, JediSpec::EPSILON)
        end
      end
    end
  end

  it "uses the same whole held stock for a fractional reverse split in reset and merge" do
    ["reset", "merge"].each do |mode|
      JediSpec.with_db do |conn|
        JediSpec.seed_basic_trade(conn, stock: 1793, price: 1.0)
        settings_id = JediSplitReinitSpec.create_settings(conn, mode)
        if mode == "reset"
          Jedi::TradingSystem::Settings.new(conn, settings_id).q0.should eq(179.0)
        end
        id = JediSplitReinitSpec.record_operation(conn, Jedi::TradingLife::Operation::Type::Buy, 21, 10.0)
        Jedi::TradingLife::Operation.new(conn, id).stock.should eq(200)
        if mode == "merge"
          settings = Jedi::TradingSystem::Settings.new(conn, settings_id)
          settings.q0.should eq(200.0)
          settings.c0.should be_close(11.79, JediSpec::EPSILON)
        end
        # No fictitious sale or payment is added for the fractional right.
        JediSpec.trade(conn).operations.size.should eq(2)
      end
    end
  end

  it "keeps the ban on consecutive unused settings for both combined modes" do
    ["reset", "merge"].each do |mode|
      JediSpec.with_db do |conn|
        JediSplitReinitSpec.seed_retained_trade(conn)
        JediSplitReinitSpec.create_settings(conn, mode)
        ex = expect_raises(Jedi::LowLevelError) do
          Jedi::TradingSystem::SettingsCreator.new(conn).call(
            trade_ident: 1_i64,
            scale_ident: 1_i64,
            timestamp: Time.local(2026, 1, 1, 12, 0, 0))
        end
        ex.key.should eq("settings.create.last_settings_not_used")
        JediSpec.trade(conn).settings_chain.size.should eq(2)
      end
    end
  end

  it "rejects split, sync and reinit together" do
    JediSpec.with_db do |conn|
      JediSplitReinitSpec.seed_retained_trade(conn)
      ex = expect_raises(Jedi::LowLevelError) do
        Jedi::TradingSystem::SettingsCreator.new(conn).call(
          trade_ident: 1_i64,
          scale_ident: 1_i64,
          timestamp: Time.local(2026, 1, 1, 11, 0, 0),
          option_split: Jedi::Exchange::Security::Split.new("1:10"),
          option_sync: Jedi::TradingRules::Position.new("0:0:0"),
          option_reinit: Jedi::TradingSystem::ReInitOption.parse("reset,12.0"))
      end
      ex.key.should eq("settings.create.zero_or_one_option_only")
      JediSpec.trade(conn).settings_chain.size.should eq(1)
    end
  end

  it "rejects the combined options before any initial settings exist" do
    ["reset", "merge"].each do |mode|
      JediSpec.with_db do |conn|
        JediSpec.insert_security(conn)
        JediSpec.insert_scale(conn)
        JediSpec.insert_trade(conn)
        ex = expect_raises(Jedi::LowLevelError) do
          JediSplitReinitSpec.create_settings(conn, mode)
        end
        ex.key.should eq("settings.create.option_not_allowed_in_empty_settings")
        JediSpec.trade(conn).settings_chain.empty?.should be_true
      end
    end
  end

  it "restores the original units when an unused combined settings row is deleted" do
    ["reset", "merge"].each do |mode|
      JediSpec.with_db do |conn|
        JediSplitReinitSpec.seed_retained_trade(conn)
        JediSplitReinitSpec.create_settings(conn, mode)
        Jedi::TradingSystem::SettingsDeleter.new(conn).call
        trade = JediSpec.trade(conn)
        metrics = Jedi::TradingSystem::TradeMetrics.new(trade).calculate.not_nil!

        trade.settings_chain.size.should eq(1)
        metrics.stock.should eq(1790)
        metrics.current_investment.should eq(173_200)
        trade.last_settings.not_nil!.split.should be_nil
      end
    end
  end

  it "can delete and replay the first merged operation without losing or repeating the split" do
    JediSpec.with_db do |conn|
      JediSplitReinitSpec.seed_retained_trade(conn)
      settings_id = JediSplitReinitSpec.create_settings(conn, "merge")
      JediSplitReinitSpec.record_operation(conn, Jedi::TradingLife::Operation::Type::Buy, 21, 10.0)
      Jedi::TradingLife::OperationDeleter.new(conn).delete

      pending = Jedi::TradingSystem::Settings.new(conn, settings_id)
      pending.q0.should eq(0.0)
      pending.c0.should eq(0.0)
      pending.split.to_s.should eq("1:10")
      pending.reinit.not_nil!.c0.should eq(12.0)
      pending.operations.empty?.should be_true
      id = JediSplitReinitSpec.record_operation(conn, Jedi::TradingLife::Operation::Type::Buy, 21, 10.0)
      Jedi::TradingLife::Operation.new(conn, id).stock.should eq(200)
      Jedi::TradingSystem::Settings.new(conn, settings_id).c0.should be_close(11.79, JediSpec::EPSILON)
      JediSpec.trade(conn).operations.size.should eq(3)
    end
  end
end
