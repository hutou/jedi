require "../support/jedi_spec_helper"

describe Jedi::TradingSystem::SettingsCreator do
  it "starts initial settings at the origin without a prior operation" do
    JediSpec.with_db do |conn|
      JediSpec.insert_security(conn)
      JediSpec.insert_scale(conn)
      JediSpec.insert_trade(conn)

      settings_id = Jedi::TradingSystem::SettingsCreator.new(conn).call(
        trade_ident: 1_i64,
        scale_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 9, 0, 0)
      )

      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)

      settings.rank.should eq(1)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      settings.operations.empty?.should be_true
    end
  end

  it "creates reset settings from the current stock and requested reference price" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      JediSpec.insert_operation(conn,
        id: 2_i64,
        type: Jedi::TradingLife::Operation::Type::Sell,
        mode: Jedi::TradingLife::Operation::Mode::Limit,
        quantity: 20,
        price: 12.0,
        stock: 80,
        position: "0:0:+1",
        timestamp: Time.local(2026, 1, 1, 10, 30, 0),
        sell: 24_000,
        trade_invest: 76_000,
        global_invest: 76_000)

      settings_id = Jedi::TradingSystem::SettingsCreator.new(conn).call(
        trade_ident: 1_i64,
        scale_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0),
        option_reinit: Jedi::TradingSystem::ReInitOption.parse("reset,8.5")
      )

      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)
      reinit = settings.reinit.not_nil!

      settings.rank.should eq(2)
      reinit.reset?.should be_true
      settings.q0.should be_close(80.0, JediSpec::EPSILON)
      settings.c0.should be_close(8.5, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      settings.kspc.should be_close(1.0, JediSpec::EPSILON)
      settings.kcpc.should be_close(1.0, JediSpec::EPSILON)
      settings.operations.empty?.should be_true
    end
  end

  it "creates merge settings as a pending empty reference row" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      JediSpec.insert_operation(conn,
        id: 2_i64,
        type: Jedi::TradingLife::Operation::Type::Sell,
        mode: Jedi::TradingLife::Operation::Mode::Limit,
        quantity: 20,
        price: 12.0,
        stock: 80,
        position: "0:0:+1",
        timestamp: Time.local(2026, 1, 1, 10, 30, 0),
        sell: 24_000,
        trade_invest: 76_000,
        global_invest: 76_000)

      settings_id = Jedi::TradingSystem::SettingsCreator.new(conn).call(
        trade_ident: 1_i64,
        scale_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0),
        option_reinit: Jedi::TradingSystem::ReInitOption.parse("merge,9.0")
      )

      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)
      reinit = settings.reinit.not_nil!

      settings.rank.should eq(2)
      reinit.merge?.should be_true
      reinit.c0.should be_close(9.0, JediSpec::EPSILON)
      settings.q0.should be_close(0.0, JediSpec::EPSILON)
      settings.c0.should be_close(0.0, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      settings.operations.empty?.should be_true
    end
  end

  it "rejects split and reinit reset in the same settings change" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      expect_raises(Jedi::LowLevelError) do
        Jedi::TradingSystem::SettingsCreator.new(conn).call(
          trade_ident: 1_i64,
          scale_ident: 1_i64,
          timestamp: Time.local(2026, 1, 1, 11, 0, 0),
          option_split: Jedi::Exchange::Security::Split.new("2:1"),
          option_reinit: Jedi::TradingSystem::ReInitOption.parse("reset,8.5")
        )
      end
    end
  end

  it "rejects split and reinit merge in the same settings change" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      expect_raises(Jedi::LowLevelError) do
        Jedi::TradingSystem::SettingsCreator.new(conn).call(
          trade_ident: 1_i64,
          scale_ident: 1_i64,
          timestamp: Time.local(2026, 1, 1, 11, 0, 0),
          option_split: Jedi::Exchange::Security::Split.new("2:1"),
          option_reinit: Jedi::TradingSystem::ReInitOption.parse("merge,9.0")
        )
      end
    end
  end

  it "applies a standard split to q0 and c0 without changing the logical position" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      settings_id = Jedi::TradingSystem::SettingsCreator.new(conn).call(
        trade_ident: 1_i64,
        scale_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0),
        option_split: Jedi::Exchange::Security::Split.new("2:1")
      )

      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)

      settings.reinit.should be_nil
      settings.split.not_nil!.to_s.should eq("2:1")
      settings.q0.should be_close(200.0, JediSpec::EPSILON)
      settings.c0.should be_close(5.0, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      settings.kspc.should be_close(1.0, JediSpec::EPSILON)
      settings.kcpc.should be_close(1.0, JediSpec::EPSILON)
    end
  end

  it "starts split settings at the last operation step, not the previous settings step" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      # The position is seeded directly: this spec checks the settings transition,
      # not the intervening sequence of operations.
      JediSpec.insert_operation(conn,
        id: 2_i64,
        type: Jedi::TradingLife::Operation::Type::Sell,
        mode: Jedi::TradingLife::Operation::Mode::Limit,
        quantity: 20,
        price: 12.0,
        stock: 80,
        position: "1:2:+1",
        timestamp: Time.local(2026, 1, 1, 10, 30, 0),
        sell: 24_000,
        trade_invest: 76_000,
        global_invest: 76_000)

      settings_id = Jedi::TradingSystem::SettingsCreator.new(conn).call(
        trade_ident: 1_i64,
        scale_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0),
        option_split: Jedi::Exchange::Security::Split.new("2:1")
      )

      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)

      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
      settings.q0.should be_close(200.0, JediSpec::EPSILON)
      settings.c0.should be_close(5.0, JediSpec::EPSILON)
    end
  end

  it "stores the raw sync option for a type-I scale but resets jumps in the active position" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, scale: JediSpec.type_one_scale)

      settings_id = Jedi::TradingSystem::SettingsCreator.new(conn).call(
        trade_ident: 1_i64,
        scale_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0),
        option_sync: Jedi::TradingRules::Position.new("2:1:-1")
      )

      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)

      settings.reinit.should be_nil
      settings.sync.not_nil!.should eq(Jedi::TradingRules::Position.new("2:1:-1"))
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:-1"))
      settings.q0.should be_close(100.0, JediSpec::EPSILON)
      settings.c0.should be_close(10.0, JediSpec::EPSILON)
    end
  end

  it "resets jumps when opening a standard settings row after an operation" do
    JediSpec.with_db do |conn|
      JediSpec.insert_security(conn)
      JediSpec.insert_scale(conn)
      JediSpec.insert_trade(conn)
      JediSpec.insert_settings(conn)
      JediSpec.insert_operation(conn, position: "1:2:-1", ksp: 0.8, kcp: 1.0)

      settings_id = Jedi::TradingSystem::SettingsCreator.new(conn).call(
        trade_ident: 1_i64,
        scale_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0)
      )

      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)

      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:-1"))
      settings.kspc.should be_close(0.8, JediSpec::EPSILON)
      settings.kcpc.should be_close(1.0, JediSpec::EPSILON)
    end
  end

  it "checks scale compatibility for synchronized settings after reset_jumps" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, scale: JediSpec.type_one_scale)

      expect_raises(Jedi::LowLevelError) do
        Jedi::TradingSystem::SettingsCreator.new(conn).call(
          trade_ident: 1_i64,
          scale_ident: 1_i64,
          timestamp: Time.local(2026, 1, 1, 11, 0, 0),
          option_sync: Jedi::TradingRules::Position.new("1:0:+2")
        )
      end
    end
  end

  it "rejects sync for a type-II scale" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      ex = expect_raises(Jedi::LowLevelError) do
        Jedi::TradingSystem::SettingsCreator.new(conn).call(
          trade_ident: 1_i64,
          scale_ident: 1_i64,
          timestamp: Time.local(2026, 1, 1, 11, 0, 0),
          option_sync: Jedi::TradingRules::Position.new("1:0:+1")
        )
      end

      ex.key.should eq("settings.create.sync_type_one_only")
    end
  end

  it "checks scale compatibility for split settings after reset_jumps" do
    JediSpec.with_db do |conn|
      JediSpec.insert_security(conn)
      JediSpec.insert_scale(conn)
      JediSpec.insert_trade(conn)
      JediSpec.insert_settings(conn)
      JediSpec.insert_operation(conn, position: "1:0:+2", ksp: 0.8, kcp: 1.0)

      expect_raises(Jedi::LowLevelError) do
        Jedi::TradingSystem::SettingsCreator.new(conn).call(
          trade_ident: 1_i64,
          scale_ident: 1_i64,
          timestamp: Time.local(2026, 1, 1, 11, 0, 0),
          option_split: Jedi::Exchange::Security::Split.new("2:1")
        )
      end
    end
  end

  it "rejects split and sync in the same settings change" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      expect_raises(Jedi::LowLevelError) do
        Jedi::TradingSystem::SettingsCreator.new(conn).call(
          trade_ident: 1_i64,
          scale_ident: 1_i64,
          timestamp: Time.local(2026, 1, 1, 11, 0, 0),
          option_split: Jedi::Exchange::Security::Split.new("2:1"),
          option_sync: Jedi::TradingRules::Position.new("1:0:0")
        )
      end
    end
  end

  it "rejects sync and reinit reset in the same settings change" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      expect_raises(Jedi::LowLevelError) do
        Jedi::TradingSystem::SettingsCreator.new(conn).call(
          trade_ident: 1_i64,
          scale_ident: 1_i64,
          timestamp: Time.local(2026, 1, 1, 11, 0, 0),
          option_sync: Jedi::TradingRules::Position.new("1:0:0"),
          option_reinit: Jedi::TradingSystem::ReInitOption.parse("reset,8.5")
        )
      end
    end
  end

  it "rejects sync and reinit merge in the same settings change" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      expect_raises(Jedi::LowLevelError) do
        Jedi::TradingSystem::SettingsCreator.new(conn).call(
          trade_ident: 1_i64,
          scale_ident: 1_i64,
          timestamp: Time.local(2026, 1, 1, 11, 0, 0),
          option_sync: Jedi::TradingRules::Position.new("1:0:0"),
          option_reinit: Jedi::TradingSystem::ReInitOption.parse("merge,9.0")
        )
      end
    end
  end

  it "rejects reinit before the initial settings row exists" do
    JediSpec.with_db do |conn|
      JediSpec.insert_security(conn)
      JediSpec.insert_scale(conn)
      JediSpec.insert_trade(conn)

      expect_raises(Jedi::LowLevelError) do
        Jedi::TradingSystem::SettingsCreator.new(conn).call(
          trade_ident: 1_i64,
          scale_ident: 1_i64,
          timestamp: Time.local(2026, 1, 1, 9, 0, 0),
          option_reinit: Jedi::TradingSystem::ReInitOption.parse("reset,8.5")
        )
      end
    end
  end
end
