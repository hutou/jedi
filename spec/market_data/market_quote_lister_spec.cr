require "./spec_helper"

describe Jedi::MarketData::MarketQuoteLister do
  it "displays a complete OHLCV quotation history" do
    JediMarketSpec.with_workspace do |_workspace|
      JediMarketSpec.initialize_i18n
      database = JediMarketSpec.initialized_database

      Jedi::MarketData::MarketImporter.new(
        database,
        "dataset_b",
        JediMarketSpec.fixture("quotes_dataset_b.csv"),
        JediMarketSpec.fixture("labels.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      text = Jedi::MarketData::MarketQuoteLister.new(
        database,
        "FR4487601001"
      ).run

      text.should contain("2020-01-02")
      text.should contain("2020-01-03")
      text.should contain("Ouverture")
      text.should contain("Volume")
    end
  end

  it "applies date selection before record selection" do
    JediMarketSpec.with_workspace do |_workspace|
      JediMarketSpec.initialize_i18n
      database = JediMarketSpec.initialized_database

      Jedi::MarketData::MarketImporter.new(
        database,
        "dataset_b",
        JediMarketSpec.fixture("quotes_dataset_b.csv"),
        JediMarketSpec.fixture("labels.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      selection = Jedi::MarketData::HistorySelection.from_options(
        "l1",
        "ge:2020-01-02"
      )

      text = Jedi::MarketData::MarketQuoteLister.new(
        database,
        "FR4487601001",
        selection
      ).run

      text.should_not contain("2020-01-02")
      text.should contain("2020-01-03")
    end
  end
end
