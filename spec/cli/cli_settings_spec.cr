require "../spec_helper"
require "../support/cli_spec_helper"

describe Jedi::Command, "CLI settings commands" do
  it "routes split settings creation through the CLI" do
    JediCliSpec.with_cli_db do |conn|
      JediCliSpec.seed_cli_trade(conn)

      JediCliSpec.run(conn,
        "settings", "create",
        "--scale=S_TEST",
        "--date=2026-01-01",
        "--time=11:00:00",
        "--split=2:1",
        "T_TEST")

      settings = Jedi::TradingSystem::Trade.new(conn, "T_TEST").last_settings.not_nil!
      settings.split.to_s.should eq("2:1")
      settings.q0.should be_close(200.0, JediSpec::EPSILON)
      settings.c0.should be_close(5.0, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
    end
  end

  it "routes sync settings creation through the CLI" do
    JediCliSpec.with_cli_db do |conn|
      JediCliSpec.seed_cli_trade(conn, scale: JediSpec.type_one_scale)

      JediCliSpec.run(conn,
        "settings", "create",
        "--scale=S_TEST",
        "--date=2026-01-01",
        "--time=11:00:00",
        "--sync=1:0:+1",
        "T_TEST")

      settings = Jedi::TradingSystem::Trade.new(conn, "T_TEST").last_settings.not_nil!
      settings.sync.should eq(Jedi::TradingRules::Position.new("1:0:+1"))
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
    end
  end

  it "routes reinit reset settings creation through the CLI" do
    JediCliSpec.with_cli_db do |conn|
      JediCliSpec.seed_cli_trade(conn)

      JediCliSpec.run(conn,
        "settings", "create",
        "--scale=S_TEST",
        "--date=2026-01-01",
        "--time=11:00:00",
        "--reinit=reset,8.5",
        "T_TEST")

      settings = Jedi::TradingSystem::Trade.new(conn, "T_TEST").last_settings.not_nil!
      reinit = settings.reinit.not_nil!
      reinit.reset?.should be_true
      settings.q0.should be_close(100.0, JediSpec::EPSILON)
      settings.c0.should be_close(8.5, JediSpec::EPSILON)
      settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
    end
  end

  it "rejects mutually exclusive structural settings options from the CLI" do
    JediCliSpec.with_cli_db do |conn|
      JediCliSpec.seed_cli_trade(conn)

      JediCliSpec.expect_failure(conn,
        ["settings", "create",
         "--scale=S_TEST",
         "--date=2026-01-01",
         "--time=11:00:00",
         "--split=2:1",
         "--sync=1:0:0",
         "T_TEST"],
        "settings.create.zero_or_one_option_only")
    end
  end
end
