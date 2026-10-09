require "./spec_helper"

describe Jedi::MarketData::MarketReplacer do
  it "replaces one dataset while preserving data linked to another dataset" do
    JediMarketSpec.with_workspace do |_workspace|
      database = JediMarketSpec.initialized_database

      Jedi::MarketData::MarketImporter.new(
        database,
        "dataset_a",
        JediMarketSpec.fixture("quotes_dataset_a.csv"),
        JediMarketSpec.fixture("labels.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      Jedi::MarketData::MarketImporter.new(
        database,
        "dataset_b",
        JediMarketSpec.fixture("quotes_dataset_b.csv"),
        JediMarketSpec.fixture("labels_alpha.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      report = Jedi::MarketData::MarketReplacer.new(
        database,
        "dataset_a",
        JediMarketSpec.fixture("quotes_dataset_a_replacement.csv"),
        JediMarketSpec.fixture("labels_beta.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      report.operation.should eq(Jedi::MarketData::ImportOperation::Replace)
      JediMarketSpec.count(database, "SELECT COUNT(*) FROM datasets").should eq(2_i64)
      JediMarketSpec.count(database, "SELECT COUNT(*) FROM securities").should eq(2_i64)
      JediMarketSpec.count(database, "SELECT COUNT(*) FROM quotes").should eq(3_i64)

      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM quote_datasets WHERE dataset_code = ?",
        "dataset_a"
      ).should eq(1_i64)
      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM quote_datasets WHERE dataset_code = ?",
        "dataset_b"
      ).should eq(2_i64)

      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM quotes WHERE isin = ? AND date = ?",
        "FR4487601001",
        20200102
      ).should eq(1_i64)
      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM quotes WHERE isin = ? AND date = ?",
        "FR0000000002",
        20200102
      ).should eq(0_i64)
    end
  end

  it "rolls back when replacement data are structurally invalid" do
    JediMarketSpec.with_workspace do |_workspace|
      database = JediMarketSpec.initialized_database

      Jedi::MarketData::MarketImporter.new(
        database,
        "dataset_a",
        JediMarketSpec.fixture("quotes_dataset_a.csv"),
        JediMarketSpec.fixture("labels.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      expect_raises(Jedi::LowLevelError) do
        Jedi::MarketData::MarketReplacer.new(
          database,
          "dataset_a",
          JediMarketSpec.fixture("quotes_structural_error.csv"),
          JediMarketSpec.fixture("labels_alpha.csv"),
          date_order: Jedi::MarketData::DateOrder::Ymd
        ).run
      end

      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM quote_datasets WHERE dataset_code = ?",
        "dataset_a"
      ).should eq(2_i64)
    end
  end
end
