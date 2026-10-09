require "../spec_helper"
require "file_utils"

private def b7_fixture(name : String) : String
  File.expand_path(
    File.join("../fixtures/tools", name),
    __DIR__,
  )
end

private def b7_seed_database(
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

private def b7_cleanup_database(
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

describe "plot and statistics quotation sources" do
  it "prepares identical plot data from a file and from SQLite" do
    filename = b7_fixture("backtest_quotes.csv")
    source = "plot_source_#{Process.pid}_#{Random.rand(1_000_000)}"
    database = b7_seed_database(source, filename)

    begin
      from_file = Jedi::Tools::Plot.new(
        filename: filename,
        position: "",
      )
      from_file.run(
        option_date: "ge:2026-01-05",
        render: false,
      )

      from_database = Jedi::Tools::Plot.new(
        quote_input: Jedi::MarketData::DatabaseQuoteHistoryInput.new(
          source,
          "TEST",
          "france",
        ),
        position: "",
      )
      from_database.run(
        option_date: "ge:2026-01-05",
        render: false,
      )

      from_database.quote_history.quotes.should eq(
        from_file.quote_history.quotes,
      )
      from_database.quote_history.quotes.size.should eq(3)
      from_database.stats.volatility.should eq(
        from_file.stats.volatility,
      )
      from_database.stats.regression_slope.should eq(
        from_file.stats.regression_slope,
      )
    ensure
      b7_cleanup_database(database)
    end
  end

  it "produces identical statistics from a file and from SQLite" do
    filename = b7_fixture("backtest_quotes.csv")
    source = "stats_source_#{Process.pid}_#{Random.rand(1_000_000)}"
    database = b7_seed_database(source, filename)

    begin
      from_file = Jedi::Tools::Statistics.new(filename: filename).run(
        option_records: "1:2",
      )
      from_database = Jedi::Tools::Statistics.new(
        quote_input: Jedi::MarketData::DatabaseQuoteHistoryInput.new(
          source,
          "TEST",
          "france",
        ),
      ).run(option_records: "1:2")

      from_database.should eq(from_file)
    ensure
      b7_cleanup_database(database)
    end
  end
end
