require "./spec_helper"

JediMarketSpec.initialize_i18n

private def b6_prepared_history_file(
  workspace : JediMarketSpec::Workspace,
) : String
  workspace.write(
    "quotes.csv",
    <<-CSV
      FR4487601001;TEST;Test security
      FR4487601001;20260102;10.00;10.20;9.80;10.00;1000
      FR4487601001;20260105;10.00;10.40;9.70;10.20;1100
      FR4487601001;20260106;10.20;10.50;9.90;10.30;1200
      FR4487601001;20260107;10.30;10.60;10.00;10.40;1300
      CSV
  )
end

private def b6_seed_history_database(
  database : Jedi::MarketData::Database,
  history : Jedi::MarketData::QuoteHistory,
) : Nil
  database.with_connection do |conn|
    Jedi::MarketData::SecurityRepository.new(conn).insert(history.security)
    repository = Jedi::MarketData::QuoteRepository.new(conn)
    history.quotes.each do |quote|
      repository.insert(history.isin, quote)
    end
  end
end

describe Jedi::MarketData::QuoteHistoryResolver do
  it "loads the same history from a file and from SQLite" do
    JediMarketSpec.with_workspace do |workspace|
      filename = b6_prepared_history_file(workspace)
      file_input = Jedi::MarketData::FileQuoteHistoryInput.new(filename)
      resolver = Jedi::MarketData::QuoteHistoryResolver.new
      file_history = resolver.load(file_input)

      database = JediMarketSpec.initialized_database("resolver")
      b6_seed_history_database(database, file_history)

      database_input = Jedi::MarketData::DatabaseQuoteHistoryInput.new(
        "resolver",
        "TEST",
        "france",
      )
      database_history = resolver.load(database_input)

      database_history.isin.should eq(file_history.isin)
      database_history.ticker.should eq(file_history.ticker)
      database_history.name.should eq(file_history.name)
      database_history.quotes.should eq(file_history.quotes)
      database_history.date_first.should eq(file_history.date_first)
      database_history.date_last.should eq(file_history.date_last)
    end
  end

  it "applies the same date and record selection to both sources" do
    JediMarketSpec.with_workspace do |workspace|
      filename = b6_prepared_history_file(workspace)
      resolver = Jedi::MarketData::QuoteHistoryResolver.new
      complete = resolver.load(
        Jedi::MarketData::FileQuoteHistoryInput.new(filename),
      )

      database = JediMarketSpec.initialized_database("selection")
      b6_seed_history_database(database, complete)

      selection = Jedi::MarketData::HistorySelection.from_options(
        "1:2",
        "ge:2026-01-05",
      )
      from_file = resolver.load(
        Jedi::MarketData::FileQuoteHistoryInput.new(filename),
        selection,
      )
      from_database = resolver.load(
        Jedi::MarketData::DatabaseQuoteHistoryInput.new(
          "selection",
          complete.isin,
          "france",
        ),
        selection,
      )

      from_database.quotes.should eq(from_file.quotes)
      from_database.quotes.size.should eq(2)
      from_database.date_first.to_s("%F").should eq("2026-01-05")
    end
  end

  it "preserves the security-not-found diagnostic" do
    JediMarketSpec.with_workspace do
      JediMarketSpec.initialized_database("missing_security")
      input = Jedi::MarketData::DatabaseQuoteHistoryInput.new(
        "missing_security",
        "UNKNOWN",
        "france",
      )

      error = expect_raises(Jedi::LowLevelError) do
        Jedi::MarketData::QuoteHistoryResolver.new.load(input)
      end

      error.log_context[:error_code]?.should eq("security_not_found")
      error.log_context[:market_source]?.should eq("missing_security")
      error.log_context[:security_ident]?.should eq("UNKNOWN")
    end
  end
end
