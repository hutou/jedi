require "../support/jedi_spec_helper"

module DatabaseDumpLoadSpec
  extend self

  US = "\x1f"

  def with_dump_file(contents : String, &)
    file = File.tempfile("jedi-database-", ".dump")
    path = file.path
    begin
      file.print(contents)
      file.flush
      yield path
    ensure
      file.close
      File.delete(path) if File.exists?(path)
    end
  end

  def line(*fields) : String
    fields.join(US)
  end
end

describe Jedi::Database::Main do
  it "dumps and restores all entities, unused dependencies, and quotations" do
    quote_time = Time.utc(2026, 9, 27, 14, 30, 45)
    source_dump = IO::Memory.new

    JediSpec.with_db do |source|
      JediSpec.insert_security(
        source,
        id: 1_i64,
        isin: "FR0000120271",
        name: "TOTALENERGIES",
        ticker: "TTE",
        tick_buy: 0.005,
        tick_sell: 0.01,
        tax: 0.003,
        quotation_date: quote_time,
        quotation_website: "alphavantage",
        quotation_mode: "eod",
        quotation_price: 57.3456,
        quotation_variation: -1.25
      )
      Jedi::TradingRules::ScaleCreator.new(source).restore(
        name: "ACTIVE_SCALE",
        comment: "Active scale",
        builder: JediSpec.type_two_scale.builder,
        announce: false
      )
      JediSpec.insert_trade(
        source,
        id: 1_i64,
        name: "Active",
        money: "r:1.5%,o:2,n:2",
        security_id: 1_i64
      )
      JediSpec.insert_settings(
        source,
        id: 1_i64,
        trade_id: 1_i64,
        scale_id: 1_i64,
        timestamp: Time.local(2026, 9, 26, 9, 0, 0)
      )
      JediSpec.insert_operation(
        source,
        id: 1_i64,
        settings_id: 1_i64,
        quantity: 100,
        price: 10.0,
        stock: 100,
        # Same timestamp and id as the settings row: both records must remain
        # present in the dump, with settings emitted first.
        timestamp: Time.local(2026, 9, 26, 9, 0, 0)
      )
      JediSpec.insert_operation(
        source,
        id: 2_i64,
        settings_id: 1_i64,
        type: Jedi::TradingLife::Operation::Type::Sell,
        mode: Jedi::TradingLife::Operation::Mode::Market,
        quantity: 100,
        price: 0.0,
        stock: 0,
        timestamp: Time.local(2026, 9, 26, 10, 0, 0),
        trade_invest: 100_000,
        global_invest: 100_000
      )

      stop = Jedi::TradingSystem::TradeStop.new(
        1_i64,
        Jedi::TradingSystem::TradeStop::Kind::CL,
        100,
        7.5,
        -250.0
      )
      source.exec("UPDATE trade SET stop = ? WHERE id = ?", stop.to_s, 1_i64)

      # This security and its trade have no settings. Their relative order in
      # the dump proves that an unused trade never precedes its dependency.
      JediSpec.insert_security(
        source,
        id: 2_i64,
        isin: "FR0000131104",
        name: "BNP PARIBAS",
        ticker: "BNP",
        quotation_date: Time.utc(2026, 9, 27, 15, 0, 0),
        quotation_website: "manual",
        quotation_mode: "live",
        quotation_price: 81.2,
        quotation_variation: nil
      )
      JediSpec.insert_trade(
        source,
        id: 2_i64,
        name: "Dormant",
        security_id: 2_i64
      )

      # A completely unused and unquoted security must also survive.
      JediSpec.insert_security(
        source,
        id: 3_i64,
        isin: "FRJEDI000000",
        name: "JEDI UNTICKERED SECURITY",
        ticker: ""
      )
      # Historical backups can contain distinct names for equivalent scales.
      Jedi::TradingRules::ScaleCreator.new(source).restore(
        name: "UNUSED_SCALE",
        comment: "Unused scale",
        builder: JediSpec.type_two_scale.builder,
        announce: false
      )
      source.exec(
        "INSERT INTO note (id, date, summary, contents) VALUES (?, ?, ?, ?)",
        1_i64,
        Time.utc(2026, 9, 27, 12, 0, 0),
        "First line\nSecond line",
        "Detailed contents\nwith another line"
      )

      Jedi::Database::Main.new(source).dump(source_dump)
    end

    dump_text = source_dump.to_s
    lines = dump_text.lines
    unused_security_index = lines.index(&.includes?("FR0000131104")).not_nil!
    unused_trade_index = lines.index(&.includes?("\x1ftrade\x1fcreate\x1fDormant\x1f")).not_nil!
    unused_security_index.should be < unused_trade_index

    DatabaseDumpLoadSpec.with_dump_file(dump_text) do |filename|
      JediSpec.with_db do |target|
        Jedi::App.simulation = Jedi::SimulationMode::None
        load_output = IO::Memory.new

        Jedi::Database::Main.new(target).load(filename, load_output)

        Jedi::App.simulation.should eq(Jedi::SimulationMode::None)
        target.scalar("SELECT COUNT(*) FROM security").as(Int64).should eq(3_i64)
        target.scalar("SELECT COUNT(*) FROM trade").as(Int64).should eq(2_i64)
        target.scalar("SELECT COUNT(*) FROM scale").as(Int64).should eq(2_i64)
        target.scalar("SELECT COUNT(*) FROM settings").as(Int64).should eq(1_i64)
        target.scalar("SELECT COUNT(*) FROM operation").as(Int64).should eq(2_i64)
        target.scalar("SELECT COUNT(*) FROM note").as(Int64).should eq(1_i64)

        active_security = Jedi::Exchange::Security.new(target, "FR0000120271")
        active_security.quotation_date.not_nil!.to_utc.should eq(quote_time)
        active_security.quotation_website.should eq("alphavantage")
        active_security.quotation_mode.should eq("eod")
        active_security.quotation_price.not_nil!.should be_close(57.3456, JediSpec::EPSILON)
        active_security.quotation_variation.not_nil!.should be_close(-1.25, JediSpec::EPSILON)

        manual_security = Jedi::Exchange::Security.new(target, "FR0000131104")
        manual_security.quotation_website.should eq("manual")
        manual_security.quotation_mode.should eq("live")
        manual_security.quotation_price.not_nil!.should be_close(81.2, JediSpec::EPSILON)
        manual_security.quotation_variation.should be_nil

        unquoted_security = Jedi::Exchange::Security.new(target, "FRJEDI000000")
        unquoted_security.ticker.should be_empty
        unquoted_security.quotation_date.should be_nil
        unquoted_security.quotation_price.should be_nil

        active_trade = Jedi::TradingSystem::Trade.new(target, "Active")
        active_trade.money.not_nil!.risk_rate.should be_close(0.015, JediSpec::EPSILON)
        active_trade.stop.not_nil!.to_s.should eq("1:CL:100:7.5:-250.0")
        liquidation = active_trade.last_operation.not_nil!
        liquidation.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
        liquidation.price.should eq(0.0)
        liquidation.stock.should eq(0)

        dormant_trade = Jedi::TradingSystem::Trade.new(target, "Dormant")
        dormant_trade.security.isin.should eq("FR0000131104")

        note = Jedi::Journal::Note.new(target, 1_i64)
        note.summary.should eq("First line\nSecond line")
        note.contents.should eq("Detailed contents\nwith another line")

        restored_dump = IO::Memory.new
        Jedi::Database::Main.new(target).dump(restored_dump)
        restored_dump.to_s.should eq(dump_text)
      end
    end
  end

  it "loads legacy security rows and numeric security references" do
    dump_text = [
      DatabaseDumpLoadSpec.line(
        "jedi", "security", "create", "FR4487601001", "LEGACY", "LEG",
        "0.01", "0.01", "0.0"),
      DatabaseDumpLoadSpec.line(
        "jedi", "trade", "create", "Legacy", "1", "", ""),
    ].join("\n") + "\n"

    DatabaseDumpLoadSpec.with_dump_file(dump_text) do |filename|
      JediSpec.with_db do |target|
        Jedi::Database::Main.new(target).load(filename, IO::Memory.new)

        trade = Jedi::TradingSystem::Trade.new(target, "Legacy")
        trade.security_id.should eq(1_i64)
        trade.security.isin.should eq("FR4487601001")
        trade.security.quotation_price.should be_nil
      end
    end
  end

  it "rolls the complete load back and restores the simulation mode on a deferred error" do
    dump_text = [
      DatabaseDumpLoadSpec.line(
        "jedi", "security", "create", "FR4487601001", "ROLLBACK", "RBK",
        "0.01", "0.01", "0.0"),
      DatabaseDumpLoadSpec.line(
        "jedi", "trade", "create", "Rollback", "FR4487601001",
        "invalid-money", ""),
    ].join("\n") + "\n"

    DatabaseDumpLoadSpec.with_dump_file(dump_text) do |filename|
      JediSpec.with_db do |target|
        Jedi::App.simulation = Jedi::SimulationMode::None

        expect_raises(Jedi::LowLevelError) do
          Jedi::Database::Main.new(target).load(filename, IO::Memory.new)
        end

        Jedi::App.simulation.should eq(Jedi::SimulationMode::None)
        %w(security scale trade settings operation note).each do |table|
          target.scalar("SELECT COUNT(*) FROM #{table}").as(Int64).should eq(0_i64)
        end
      end
    end
  end
end
