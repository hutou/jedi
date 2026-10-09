require "../spec_helper"
require "file_utils"

private def b6_fixture(name : String) : String
  File.expand_path(
    File.join("../fixtures/tools", name),
    __DIR__,
  )
end

private def b6_seed_database(
  source : String,
  filename : String,
) : Jedi::MarketData::Database
  database = Jedi::MarketData::Database.new(source, "france")
  Jedi::MarketData::MarketInitializer.new(database).run
  history = Jedi::MarketData::PreparedQuotesFileLoader.new(filename).load

  database.with_connection do |conn|
    Jedi::MarketData::SecurityRepository.new(conn).insert(history.security)
    quotes = Jedi::MarketData::QuoteRepository.new(conn)
    history.quotes.each do |quote|
      quotes.insert(history.isin, quote)
    end
  end

  database
end

private def b6_cleanup_database(
  database : Jedi::MarketData::Database,
) : Nil
  {
    database.filename,
    "#{database.filename}-wal",
    "#{database.filename}-shm",
  }.each do |filename|
    File.delete(filename) if File.exists?(filename)
  end
end

private def b6_with_environment(& : DB::Connection ->) : Nil
  JediSpec.with_db do |conn_main|
    previous_simulation = Jedi::App.simulation
    previous_capital = Jedi::App.capital
    previous_distance = Jedi::App.distance
    previous_risk_rate = Jedi::App.risk_rate
    previous_initial_investment = Jedi::App.initial_investment

    begin
      Jedi::App.simulation = Jedi::SimulationMode::FromSeed
      Jedi::App.capital = 20_000
      Jedi::App.distance = 0.20
      Jedi::App.risk_rate = 0.015
      Jedi::App.initial_investment = 1_000
      yield conn_main
    ensure
      Jedi::App.simulation = previous_simulation
      Jedi::App.capital = previous_capital
      Jedi::App.distance = previous_distance
      Jedi::App.risk_rate = previous_risk_rate
      Jedi::App.initial_investment = previous_initial_investment
    end
  end
end

describe "quotation sources used by tools" do
  it "produces equivalent backtests from a file and from SQLite" do
    b6_with_environment do |conn_main|
      filename = b6_fixture("backtest_quotes.csv")
      source = "backtest_source_#{Process.pid}_#{Random.rand(1_000_000)}"
      database = b6_seed_database(source, filename)
      file_memory = DB.connect "sqlite3://%3Amemory%3A"
      database_memory = DB.connect "sqlite3://%3Amemory%3A"

      begin
        scaledef = "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0"

        file_backtest = Jedi::Tools::BackTest.new(
          conn_main,
          file_memory,
          filename,
          scaledef,
          nil,
        )
        file_report = file_backtest.run(option_command: {'r' => ""})

        database_backtest = Jedi::Tools::BackTest.new(
          conn_main,
          database_memory,
          Jedi::MarketData::DatabaseQuoteHistoryInput.new(
            source,
            "TEST",
            "france",
          ),
          scaledef,
          nil,
        )
        database_report = database_backtest.run(option_command: {'r' => ""})

        from_file = file_backtest.simulation_result
        from_database = database_backtest.simulation_result

        from_database.quote_history.quotes.should eq(
          from_file.quote_history.quotes,
        )
        from_database.trade_count.should eq(from_file.trade_count)
        from_database.operation_count.should eq(from_file.operation_count)
        from_database.gross_gain_cents.should eq(from_file.gross_gain_cents)
        from_database.net_gain_cents.should eq(from_file.net_gain_cents)
        from_database.maximum_investment_cents.should eq(
          from_file.maximum_investment_cents,
        )
        database_report.should eq(file_report)
      ensure
        file_memory.close
        database_memory.close
        b6_cleanup_database(database)
      end
    end
  end

  it "allows scoring to identify a database security by ticker" do
    b6_with_environment do |conn_main|
      filename = b6_fixture("backtest_quotes.csv")
      source = "scoring_source_#{Process.pid}_#{Random.rand(1_000_000)}"
      database = b6_seed_database(source, filename)
      conn_memory = DB.connect "sqlite3://%3Amemory%3A"

      begin
        scoring = Jedi::Tools::Scoring.new(
          conn_main,
          conn_memory,
          Jedi::MarketData::DatabaseQuoteHistoryInput.new(
            source,
            "TEST",
            "france",
          ),
          "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0",
        )

        output = scoring.run

        scoring.quote_history.isin.should eq("FR4487601001")
        scoring.evaluated_results.size.should eq(1)
        output.should contain(I18n.t("tools.score.context.security", {
          :name => "Test security", :ticker => "TEST", :isin => "FR4487601001",
        }))
      ensure
        conn_memory.close
        b6_cleanup_database(database)
      end
    end
  end
end
