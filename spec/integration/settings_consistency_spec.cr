require "../support/play_spec_helper"

describe "Settings consistency between SettingsCreator and Play" do
  it "creates equivalent settings after split" do
    creator_values = nil

    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      settings_id = Jedi::TradingSystem::SettingsCreator.new(conn).call(
        trade_ident: 1_i64,
        scale_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0),
        option_split: Jedi::Exchange::Security::Split.new("2:1")
      )

      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)
      creator_values = {
        settings.split.not_nil!.to_s,
        settings.q0,
        settings.c0,
        settings.position,
        settings.kspc,
        settings.kcpc,
      }
    end

    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["split=2:1"]
    ) do |play|
      settings = JediPlaySpec.settings_rows(play).last
      values = {
        settings.split.not_nil!.to_s,
        settings.q0,
        settings.c0,
        settings.position,
        settings.kspc,
        settings.kcpc,
      }

      values.should eq(creator_values.not_nil!)
    end
  end

  it "creates equivalent settings after reinit reset" do
    creator_values = nil

    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      settings_id = Jedi::TradingSystem::SettingsCreator.new(conn).call(
        trade_ident: 1_i64,
        scale_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0),
        option_reinit: Jedi::TradingSystem::ReInitOption.parse("reset,8.5")
      )

      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)
      creator_values = {
        settings.reinit.not_nil!.to_s,
        settings.q0,
        settings.c0,
        settings.position,
        settings.kspc,
        settings.kcpc,
      }
    end

    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["reinit=reset,8.5"]
    ) do |play|
      settings = JediPlaySpec.settings_rows(play).last
      values = {
        settings.reinit.not_nil!.to_s,
        settings.q0,
        settings.c0,
        settings.position,
        settings.kspc,
        settings.kcpc,
      }

      values.should eq(creator_values.not_nil!)
    end
  end

  it "creates equivalent pending settings after reinit merge" do
    creator_values = nil

    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      settings_id = Jedi::TradingSystem::SettingsCreator.new(conn).call(
        trade_ident: 1_i64,
        scale_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0),
        option_reinit: Jedi::TradingSystem::ReInitOption.parse("merge,9.0")
      )

      settings = Jedi::TradingSystem::Settings.new(conn, settings_id)
      creator_values = {
        settings.reinit.not_nil!.to_s,
        settings.q0,
        settings.c0,
        settings.position,
        settings.kspc,
        settings.kcpc,
      }
    end

    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["reinit=merge,9.0"]
    ) do |play|
      settings = JediPlaySpec.settings_rows(play).last
      values = {
        settings.reinit.not_nil!.to_s,
        settings.q0,
        settings.c0,
        settings.position,
        settings.kspc,
        settings.kcpc,
      }

      values.should eq(creator_values.not_nil!)
    end
  end
end
