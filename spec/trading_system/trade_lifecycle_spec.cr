require "../support/cli_spec_helper"

module JediTradeLifecycleSpec
  extend self

  def seed_states(conn) : Nil
    JediSpec.insert_security(conn)
    JediSpec.insert_scale(conn)
    {"T_CREATED", "T_CONFIGURED", "T_OPENED", "T_RUNNING", "T_CLOSED"}.each_with_index do |name, index|
      id = (index + 1).to_i64
      JediSpec.insert_trade(conn, id: id, name: name)
      next if index.zero?
      JediSpec.insert_settings(conn, id: id, trade_id: id,
        q0: index == 1 ? 0.0 : 100.0, c0: index == 1 ? 0.0 : 10.0,
        timestamp: Time.local(2026, 1, 1, 9, index, 0))
    end
    JediSpec.insert_operation(conn, id: 1_i64, settings_id: 3_i64,
      timestamp: Time.local(2026, 1, 1, 10, 0, 0))
    JediSpec.insert_operation(conn, id: 2_i64, settings_id: 4_i64,
      timestamp: Time.local(2026, 1, 1, 10, 10, 0))
    JediSpec.insert_operation(conn, id: 3_i64, settings_id: 4_i64,
      quantity: 20, stock: 120,
      timestamp: Time.local(2026, 1, 1, 10, 20, 0))
    JediSpec.insert_operation(conn, id: 4_i64, settings_id: 5_i64,
      timestamp: Time.local(2026, 1, 1, 10, 30, 0))
    JediSpec.insert_operation(conn, id: 5_i64, settings_id: 5_i64,
      type: Jedi::TradingLife::Operation::Type::Sell,
      quantity: 100, price: 11.0, stock: 0, sell: 110_000,
      trade_invest: -10_000, global_invest: -10_000,
      timestamp: Time.local(2026, 1, 1, 10, 40, 0))
  end

  def record(conn, type, quantity, price, hour)
    Jedi::TradingLife::OperationCreator.new(conn).call(
      trade_ident: 1_i64,
      timestamp: Time.local(2026, 1, 1, hour, 0, 0),
      type: type,
      mode: Jedi::TradingLife::Operation::Mode::Market,
      quantity: quantity,
      price: price,
      cfees: 0.0,
      tickcheck: false)
  end
end

describe Jedi::TradingSystem::Trade, "lifecycle status" do
  it "classifies a trade without settings as created" do
    JediSpec.with_db do |conn|
      JediTradeLifecycleSpec.seed_states(conn)
      JediSpec.trade(conn, 1_i64).lifecycle_status.should eq(
        Jedi::TradingSystem::Trade::LifecycleStatus::Created)
    end
  end

  it "classifies a trade with settings but no operation as configured" do
    JediSpec.with_db do |conn|
      JediTradeLifecycleSpec.seed_states(conn)
      JediSpec.trade(conn, 2_i64).lifecycle_status.should eq(
        Jedi::TradingSystem::Trade::LifecycleStatus::Configured)
    end
  end

  it "classifies a trade with just its initial purchase as opened" do
    JediSpec.with_db do |conn|
      JediTradeLifecycleSpec.seed_states(conn)
      JediSpec.trade(conn, 3_i64).lifecycle_status.should eq(
        Jedi::TradingSystem::Trade::LifecycleStatus::Opened)
    end
  end

  it "classifies a trade with a subsequent operation and shares as running" do
    JediSpec.with_db do |conn|
      JediTradeLifecycleSpec.seed_states(conn)
      JediSpec.trade(conn, 4_i64).lifecycle_status.should eq(
        Jedi::TradingSystem::Trade::LifecycleStatus::Running)
    end
  end

  it "gives closure priority when the last recorded holding is zero" do
    JediSpec.with_db do |conn|
      JediTradeLifecycleSpec.seed_states(conn)
      JediSpec.trade(conn, 5_i64).lifecycle_status.should eq(
        Jedi::TradingSystem::Trade::LifecycleStatus::Closed)
    end
  end

  it "counts operations across the complete settings chain" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      Jedi::TradingSystem::SettingsCreator.new(conn).call(
        trade_ident: 1_i64, scale_ident: 1_i64,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0))
      JediTradeLifecycleSpec.record(conn, Jedi::TradingLife::Operation::Type::Buy, 20, 9.0, 12)

      JediSpec.trade(conn).last_settings.not_nil!.operations.size.should eq(1)
      JediSpec.trade(conn).lifecycle_status.should eq(
        Jedi::TradingSystem::Trade::LifecycleStatus::Running)
    end
  end

  it "keeps opened and running states when new settings have no operation yet" do
    JediSpec.with_db do |conn|
      JediTradeLifecycleSpec.seed_states(conn)
      {3_i64, 4_i64}.each_with_index do |trade_id, index|
        Jedi::TradingSystem::SettingsCreator.new(conn).call(
          trade_ident: trade_id, scale_ident: 1_i64,
          timestamp: Time.local(2026, 1, 1, 11, index, 0))
      end

      JediSpec.trade(conn, 3_i64).lifecycle_status.should eq(
        Jedi::TradingSystem::Trade::LifecycleStatus::Opened)
      JediSpec.trade(conn, 4_i64).lifecycle_status.should eq(
        Jedi::TradingSystem::Trade::LifecycleStatus::Running)
    end
  end

  it "recalculates on the same object after recording and deleting operations" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      trade = JediSpec.trade(conn)
      trade.lifecycle_status.should eq(Jedi::TradingSystem::Trade::LifecycleStatus::Opened)

      JediTradeLifecycleSpec.record(conn, Jedi::TradingLife::Operation::Type::Buy, 20, 9.0, 11)
      trade.lifecycle_status.should eq(Jedi::TradingSystem::Trade::LifecycleStatus::Running)
      JediTradeLifecycleSpec.record(conn, Jedi::TradingLife::Operation::Type::Sell, 120, 11.0, 12)
      trade.lifecycle_status.should eq(Jedi::TradingSystem::Trade::LifecycleStatus::Closed)

      deleter = Jedi::TradingLife::OperationDeleter.new(conn)
      deleter.delete
      trade.lifecycle_status.should eq(Jedi::TradingSystem::Trade::LifecycleStatus::Running)
      deleter.delete
      trade.lifecycle_status.should eq(Jedi::TradingSystem::Trade::LifecycleStatus::Opened)
      deleter.delete
      trade.lifecycle_status.should eq(Jedi::TradingSystem::Trade::LifecycleStatus::Configured)
    end
  end
end

describe Jedi::TradingSystem::TradeLister, "lifecycle column" do
  it "shows all five localized statuses directly after the name" do
    {"fr" => {"créé", "paramétré", "ouvert", "en cours", "clôturé"},
     "en" => {"created", "configured", "opened", "in progress", "closed"}}.each do |lang, labels|
      JediSpec.with_db do |conn|
        JediTradeLifecycleSpec.seed_states(conn)
        Jedi.init_i18n(lang)
        output = Jedi::TradingSystem::TradeLister.new(conn).call
        names = {"T_CREATED", "T_CONFIGURED", "T_OPENED", "T_RUNNING", "T_CLOSED"}
        names.zip(labels).each do |name, label|
          output.lines.any? { |line| line.includes?(name) && line.includes?(label) }.should be_true
        end

        projection = Jedi::TradingSystem::TradeLister.new(conn).call(option_columns: "1,2")
        name_header = lang == "fr" ? "Nom" : "Name"
        status_header = lang == "fr" ? "Statut" : "Status"
        header = projection.lines.find { |line| line.includes?(name_header) && line.includes?(status_header) }.not_nil!
        header.index(name_header).not_nil!.should be < header.index(status_header).not_nil!
        projection.should_not contain(I18n.t("trade.list.table.money").split('\n').last)
      end
    end
  end

  it "exports stable status codes after name with matching CSV headers" do
    %w(fr en).each do |lang|
      JediSpec.with_db do |conn|
        JediTradeLifecycleSpec.seed_states(conn)
        Jedi.init_i18n(lang)
        {false, true}.each do |extended|
          rows = CSV.parse(Jedi::TradingSystem::TradeLister.new(conn).call(
            option_csv: true, option_headers: true, option_extended: extended))
          expected = %w(id name status money stop security_id)
          expected += %w(security_isin security_name) if extended
          rows.first.should eq(expected)
          rows[1..].map(&.[2]).should eq(%w(created configured opened running closed))
          rows.each { |row| row.size.should eq(extended ? 8 : 6) }
        end
      end
    end
  end

  it "keeps both opened and running trades with the running filter" do
    JediSpec.with_db do |conn|
      JediTradeLifecycleSpec.seed_states(conn)
      rows = CSV.parse(Jedi::TradingSystem::TradeLister.new(conn).call(
        option_csv: true, option_running: true))
      rows.map(&.[0]).should eq(%w(3 4))
      rows.map(&.[2]).should eq(%w(opened running))
    end
  end

  it "accepts the new last column and rejects indexes outside each table" do
    JediSpec.with_db do |conn|
      JediTradeLifecycleSpec.seed_states(conn)
      lister = Jedi::TradingSystem::TradeLister.new(conn)
      lister.call(option_columns: "4").should_not be_empty
      lister.call(option_columns: "7", option_extended: true).should contain("SPEC SECURITY")
      expect_raises(Jedi::LowLevelError) { lister.call(option_columns: "5") }
      expect_raises(Jedi::LowLevelError) { lister.call(option_columns: "8", option_extended: true) }
    end
  end

  it "supports explicitly reordered status and name columns" do
    JediSpec.with_db do |conn|
      JediTradeLifecycleSpec.seed_states(conn)
      Jedi.init_i18n("en")
      output = Jedi::TradingSystem::TradeLister.new(conn).call(option_columns: "2,1")
      header = output.lines.find { |line| line.includes?("Status") && line.includes?("Name") }.not_nil!
      header.index("Status").not_nil!.should be < header.index("Name").not_nil!
    end
  end

  it "derives status without changing stored trade fields or schema" do
    JediSpec.with_db do |conn|
      JediTradeLifecycleSpec.seed_states(conn)
      before = Jedi::TradingSystem::Trades.new(conn).fetch.to_a.map(&.record)

      Jedi::TradingSystem::TradeLister.new(conn).call

      Jedi::TradingSystem::Trades.new(conn).fetch.to_a.map(&.record).should eq(before)
      conn.query_all("SELECT name FROM pragma_table_info('trade')", as: String).should eq(
        %w(id name money stop security_id))
    end
  end

  it "routes the expanded column range and running filter through the CLI" do
    JediCliSpec.with_cli_db do |conn|
      JediTradeLifecycleSpec.seed_states(conn)
      Jedi.init_i18n("en")
      JediCliSpec.run(conn, "trade", "list", "-c", "1,2,4")
      JediCliSpec.expect_failure(conn, "trade", "list", "-c", "5")
      JediCliSpec.run(conn, "trade", "list", "-r", "--csv", "--headers")
    end
  end
end
