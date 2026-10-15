require "../support/cli_spec_helper"
require "../support/play_spec_helper"

module JediMoneyStatusSpec
  extend self

  MONEY  = "r:1.5%,o:2,n:2"
  STOP   = "1:cl:100:9.5:-50"
  STAGES = {"created", "configured", "opened", "running", "closed"}

  def seed_stage(conn, stage : String, *, id : Int64 = 1_i64,
                 money : String? = nil, stop : String? = nil) : Nil
    if id == 1_i64
      JediSpec.insert_security(conn)
      JediSpec.insert_scale(conn)
    end
    JediSpec.insert_trade(conn, id: id, name: "T_#{stage.upcase}", money: money, stop: stop)
    return if stage == "created"
    day = id.to_i
    JediSpec.insert_settings(conn, id: id, trade_id: id,
      q0: stage == "configured" ? 0.0 : 100.0,
      c0: stage == "configured" ? 0.0 : 10.0,
      timestamp: Time.local(2026, 1, day, 9, 0, 0))
    return if stage == "configured"
    JediSpec.insert_operation(conn, id: id * 10, settings_id: id,
      timestamp: Time.local(2026, 1, day, 10, 0, 0))
    if stage == "running"
      JediSpec.insert_operation(conn, id: id * 10 + 1, settings_id: id,
        quantity: 20, price: 9.0, stock: 120, trade_invest: 118_000,
        timestamp: Time.local(2026, 1, day, 11, 0, 0))
    elsif stage == "closed"
      JediSpec.insert_operation(conn, id: id * 10 + 1, settings_id: id,
        type: Jedi::TradingLife::Operation::Type::Sell,
        quantity: 100, price: 11.0, stock: 0, sell: 110_000,
        trade_invest: -10_000, global_invest: -10_000,
        timestamp: Time.local(2026, 1, day, 11, 0, 0))
    end
  end

  def seed_all(conn) : Nil
    STAGES.each_with_index { |stage, i| seed_stage(conn, stage, id: (i + 1).to_i64) }
  end

  def ids(conn, filter : String, *, running : Bool = false,
          extended : Bool = false, records : String? = nil) : Array(String)
    output = Jedi::TradingSystem::TradeLister.new(conn).call(filter,
      option_csv: true, option_running: running,
      option_extended: extended, option_records: records)
    output.empty? ? [] of String : CSV.parse(output).map(&.[0])
  end

  def with_dump(text : String, &)
    file = File.tempfile("jedi-money-status-", ".dump")
    begin
      file.print(text)
      file.flush
      yield file.path
    ensure
      file.close
      File.delete(file.path) if File.exists?(file.path)
    end
  end
end

describe "Trade money lifecycle rules" do
  it "refuses money in ordinary creation before writing a trade" do
    JediSpec.with_db do |conn|
      JediSpec.insert_security(conn)
      ex = expect_raises(Jedi::LowLevelError) do
        Jedi::TradingSystem::TradeCreator.new(conn).call(
          name: "T_NEW", security_ident: 1_i64,
          money: Jedi::TradingSystem::Money.parse(JediMoneyStatusSpec::MONEY))
      end
      ex.key.should eq("trade.money_requires_settings")
      ex.kind.should eq(Jedi::LowLevelError::Kind::UserInput)
      conn.scalar("SELECT COUNT(*) FROM trade").should eq(0_i64)
    end
  end

  it "refuses a nonempty value on created and closed trades without changing any field" do
    {"created" => "trade.money_requires_settings", "closed" => "trade.money_on_closed_trade"}.each do |stage, key|
      JediSpec.with_db do |conn|
        JediMoneyStatusSpec.seed_stage(conn, stage,
          money: JediMoneyStatusSpec::MONEY, stop: JediMoneyStatusSpec::STOP)
        before = JediSpec.trade(conn).record
        ex = expect_raises(Jedi::LowLevelError) do
          Jedi::TradingSystem::TradeUpdater.new(JediSpec.trade(conn)).call(
            name: "T_RENAMED", money: JediMoneyStatusSpec::MONEY, reset_stop: true)
        end
        ex.key.should eq(key)
        JediSpec.trade(conn).record.should eq(before)
      end
    end
  end

  it "accepts money once configured and keeps accepting it while holding shares" do
    %w(configured opened running).each do |stage|
      JediSpec.with_db do |conn|
        JediMoneyStatusSpec.seed_stage(conn, stage)
        before = JediSpec.trade(conn).lifecycle_status
        Jedi::TradingSystem::TradeUpdater.new(JediSpec.trade(conn)).call(
          money: JediMoneyStatusSpec::MONEY).should eq(1)
        JediSpec.trade(conn).money.not_nil!.risk_rate.should eq(0.015)
        JediSpec.trade(conn).lifecycle_status.should eq(before)
      end
    end
  end

  it "allows clearing historical money and stop in every lifecycle state" do
    JediMoneyStatusSpec::STAGES.each do |stage|
      JediSpec.with_db do |conn|
        JediMoneyStatusSpec.seed_stage(conn, stage,
          money: JediMoneyStatusSpec::MONEY, stop: JediMoneyStatusSpec::STOP)
        before = JediSpec.trade(conn).operations.to_a.map(&.record)
        Jedi::TradingSystem::TradeUpdater.new(JediSpec.trade(conn)).call(
          money: "  ", reset_stop: true).should eq(1)
        trade = JediSpec.trade(conn)
        trade.money.should be_nil
        trade.stop.should be_nil
        trade.operations.to_a.map(&.record).should eq(before)
      end
    end
  end

  it "allows a rename without re-entering money on a historical created or closed trade" do
    %w(created closed).each do |stage|
      JediSpec.with_db do |conn|
        JediMoneyStatusSpec.seed_stage(conn, stage,
          money: JediMoneyStatusSpec::MONEY, stop: JediMoneyStatusSpec::STOP)
        before = JediSpec.trade(conn)
        money, stop = before.money, before.stop
        Jedi::TradingSystem::TradeUpdater.new(before).call(name: "T_RENAMED")
        JediSpec.trade(conn).money.should eq(money)
        JediSpec.trade(conn).stop.should eq(stop)
      end
    end
  end

  it "keeps the existing explicit stop-reset requirement for active trades" do
    JediSpec.with_db do |conn|
      JediMoneyStatusSpec.seed_stage(conn, "opened",
        money: JediMoneyStatusSpec::MONEY, stop: JediMoneyStatusSpec::STOP)
      Jedi::App.simulation = Jedi::SimulationMode::None
      before = JediSpec.trade(conn).record
      ex = expect_raises(Jedi::LowLevelError) do
        Jedi::TradingSystem::TradeUpdater.new(JediSpec.trade(conn)).call(money: "r:2%,o:2,n:2")
      end
      ex.key.should eq("trade.update.reset_stop_required")
      JediSpec.trade(conn).record.should eq(before)
      Jedi::TradingSystem::TradeUpdater.new(JediSpec.trade(conn)).call(
        money: "r:2%,o:2,n:2", reset_stop: true)
      JediSpec.trade(conn).money.not_nil!.risk_rate.should eq(0.02)
      JediSpec.trade(conn).stop.should be_nil
    end
  end

  it "rejects the removed creation option in both CLI syntaxes" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.insert_security(conn)
      [["--name=T_NEW", "--security=1"], ["T_NEW", "1"]].each do |args|
        JediCliSpec.expect_failure(conn,
          ["trade", "create"] + args + ["--money=#{JediMoneyStatusSpec::MONEY}"],
          "infra.invalid_option")
      end
      conn.scalar("SELECT COUNT(*) FROM trade").should eq(0_i64)
    end
  end

  it "routes the configured-stage restriction through trade update" do
    JediCliSpec.with_cli_db do |conn|
      JediMoneyStatusSpec.seed_stage(conn, "created")
      JediCliSpec.expect_failure(conn,
        ["trade", "update", "1", "--money=#{JediMoneyStatusSpec::MONEY}"],
        "trade.money_requires_settings")
      JediCliSpec.run(conn, "settings", "create", "1", "--scale=1",
        "--date=2026-01-01", "--time=09:00:00")
      JediCliSpec.run(conn, "trade", "update", "1", "--money=#{JediMoneyStatusSpec::MONEY}")
      JediSpec.trade(conn).money.should_not be_nil
    end
  end

  it "applies seed money after the simulated settings have been created" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01,money=#{JediMoneyStatusSpec::MONEY}",
      [] of String
    ) do |play|
      play.mem_trade.lifecycle_status.should eq(Jedi::TradingSystem::Trade::LifecycleStatus::Opened)
      play.mem_trade.money.not_nil!.risk_rate.should eq(0.015)
    end
  end

  it "restores historical money on created and closed trades through backup replay" do
    dump = IO::Memory.new
    JediSpec.with_db do |source|
      JediMoneyStatusSpec.seed_stage(source, "created", id: 1_i64,
        money: JediMoneyStatusSpec::MONEY, stop: JediMoneyStatusSpec::STOP)
      JediMoneyStatusSpec.seed_stage(source, "closed", id: 2_i64,
        money: JediMoneyStatusSpec::MONEY, stop: JediMoneyStatusSpec::STOP)
      Jedi::Database::Main.new(source).dump(dump)
    end
    JediSpec.with_db do |target|
      JediMoneyStatusSpec.with_dump(dump.to_s) { |path| Jedi::Database::Main.new(target).load(path) }
      %w(created closed).each do |stage|
        trade = Jedi::TradingSystem::Trade.new(target, "T_#{stage.upcase}")
        trade.lifecycle_status.to_s.underscore.should eq(stage)
        trade.money.not_nil!.risk_rate.should eq(0.015)
        trade.stop.not_nil!.guaranteed_gain.should eq(-50.0)
        expect_raises(Jedi::LowLevelError) do
          Jedi::TradingSystem::TradeUpdater.new(trade).call(money: JediMoneyStatusSpec::MONEY)
        end
      end
    end
  end

  it "still rejects invalid historical money and rolls the whole import back" do
    dump = IO::Memory.new
    JediSpec.with_db do |source|
      JediMoneyStatusSpec.seed_stage(source, "created", money: JediMoneyStatusSpec::MONEY)
      Jedi::Database::Main.new(source).dump(dump)
    end
    invalid = dump.to_s.gsub("r:1.5%, o:2.0, n:2", "r:invalid,o:2,n:2")
    invalid.should_not eq(dump.to_s)
    JediSpec.with_db do |target|
      JediMoneyStatusSpec.with_dump(invalid) do |path|
        ex = expect_raises(Jedi::LowLevelError) { Jedi::Database::Main.new(target).load(path) }
        ex.key.should eq("trade.update.invalid_money")
      end
      target.scalar("SELECT COUNT(*) FROM trade").should eq(0_i64)
      target.scalar("SELECT COUNT(*) FROM security").should eq(0_i64)
    end
  end
end

describe Jedi::TradingSystem::TradeLister, "status filter expression" do
  it "filters each of the five canonical status codes" do
    JediSpec.with_db do |conn|
      JediMoneyStatusSpec.seed_all(conn)
      JediMoneyStatusSpec::STAGES.each_with_index do |stage, i|
        JediMoneyStatusSpec.ids(conn, "status=^#{stage}$").should eq([(i + 1).to_s])
      end
    end
  end

  it "recognises both localized labels and stable codes" do
    {"fr" => {"créé", "paramétré", "ouvert", "en cours", "clôturé"},
     "en" => {"created", "configured", "opened", "in progress", "closed"}}.each do |lang, labels|
      JediSpec.with_db do |conn|
        JediMoneyStatusSpec.seed_all(conn)
        Jedi.init_i18n(lang)
        labels.each_with_index do |label, i|
          JediMoneyStatusSpec.ids(conn, "status=^#{label}$").should eq([(i + 1).to_s])
        end
        JediMoneyStatusSpec.ids(conn, "STATUS=^CLOSED$").should eq(["5"])
      end
    end
  end

  it "supports several statuses through the existing regex alternation" do
    JediSpec.with_db do |conn|
      JediMoneyStatusSpec.seed_all(conn)
      JediMoneyStatusSpec.ids(conn, "status=^(configured|opened)$").should eq(%w(2 3))
    end
  end

  it "combines status with the existing AND and OR expressions" do
    JediSpec.with_db do |conn|
      JediMoneyStatusSpec.seed_all(conn)
      JediMoneyStatusSpec.ids(conn, "status=^closed$ || status=^created$").should eq(%w(1 5))
      JediMoneyStatusSpec.ids(conn, "status=^(opened|running)$ && name=^T_RUNNING$").should eq(["4"])
    end
  end

  it "intersects the status expression with the holding-only running filter" do
    JediSpec.with_db do |conn|
      JediMoneyStatusSpec.seed_all(conn)
      JediMoneyStatusSpec.ids(conn, "status=^(opened|running)$", running: true).should eq(%w(3 4))
      JediMoneyStatusSpec.ids(conn, "status=^closed$", running: true).should be_empty
    end
  end

  it "selects record positions after filtering by status" do
    JediSpec.with_db do |conn|
      JediMoneyStatusSpec.seed_all(conn)
      JediMoneyStatusSpec.ids(conn, "status=^(opened|running)$", records: "f1").should eq(["3"])
      JediMoneyStatusSpec.ids(conn, "status=^(opened|running)$", records: "l1").should eq(["4"])
    end
  end

  it "combines status and security fields in extended output" do
    JediSpec.with_db do |conn|
      JediMoneyStatusSpec.seed_all(conn)
      JediMoneyStatusSpec.ids(conn, "status=^closed$ && security=SPEC", extended: true).should eq(["5"])
    end
  end

  it "includes the localized status in an unqualified expression" do
    JediSpec.with_db do |conn|
      JediMoneyStatusSpec.seed_all(conn)
      Jedi.init_i18n("fr")
      JediMoneyStatusSpec.ids(conn, "clôturé").should eq(["5"])
      Jedi.init_i18n("en")
    end
  end

  it "reports malformed status regexes even on an empty database" do
    JediSpec.with_db do |conn|
      ["status=[", "status="].each do |filter|
        ex = expect_raises(Jedi::LowLevelError) { JediMoneyStatusSpec.ids(conn, filter) }
        ex.key.should eq("infra.invalid_regex")
      end
    end
  end

  it "routes status expressions through the CLI and preserves regex validation" do
    JediCliSpec.with_cli_db do |conn|
      JediMoneyStatusSpec.seed_all(conn)
      JediCliSpec.run(conn, "trade", "list", "status=^(opened|running)$", "--csv")
      JediCliSpec.expect_failure(conn,
        ["trade", "list", "status=["], "infra.invalid_regex")
    end
  end
end
