require "./spec_helper"

describe Jedi::MarketData::MarketImporter do
  it "filters old rows before OHLC validation and records recent anomalies" do
    JediMarketSpec.with_workspace do |_workspace|
      database = JediMarketSpec.initialized_database

      report = Jedi::MarketData::MarketImporter.new(
        database,
        "mixed",
        JediMarketSpec.fixture("quotes_mixed.csv"),
        JediMarketSpec.fixture("labels.csv"),
        from_date: Time.utc(2020, 1, 1),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      report.labels_read.should eq(2_i64)
      report.quotes_read.should eq(5_i64)
      report.quotes_inserted.should eq(2_i64)
      report.quotes_skipped_before_start.should eq(1_i64)
      report.quotes_skipped_without_label.should eq(1_i64)
      report.quotes_skipped_invalid.should eq(1_i64)
      report.invalid_quote_isins.should eq(["FR4487601001"])
      report.date_first.should eq(Time.utc(2020, 1, 2))
      report.date_last.should eq(Time.utc(2020, 1, 2))

      JediMarketSpec.count(database, "SELECT COUNT(*) FROM securities").should eq(2_i64)
      JediMarketSpec.count(database, "SELECT COUNT(*) FROM quotes").should eq(2_i64)
      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM quote_datasets WHERE dataset_code = ?",
        "mixed"
      ).should eq(2_i64)
    end
  end

  it "skips an OHLCV anomaly even when its volume exceeds Int32::MAX" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      quotes = workspace.write(
        "large_volume_anomaly.csv",
        "FR0014004QR6;06/03/25;1.00;1.10;0.90;1.05;1000\n" +
        "FR0014004QR6;07/03/25;0.00;0.001;0.00;0.00;4220557368\n"
      )
      labels = workspace.write(
        "labels.csv",
        "FR0014004QR6;Test security;TEST\n"
      )

      report = Jedi::MarketData::MarketImporter.new(
        database,
        "large_volume_anomaly",
        quotes,
        labels,
        date_order: Jedi::MarketData::DateOrder::Dmy
      ).run

      report.quotes_read.should eq(2_i64)
      report.quotes_inserted.should eq(1_i64)
      report.quotes_skipped_invalid.should eq(1_i64)
      report.invalid_quote_isins.should eq(["FR0014004QR6"])
      JediMarketSpec.count(database, "SELECT COUNT(*) FROM quotes").should eq(1_i64)
    end
  end

  it "refuses to import the same dataset twice" do
    JediMarketSpec.with_workspace do |_workspace|
      database = JediMarketSpec.initialized_database

      importer = Jedi::MarketData::MarketImporter.new(
        database,
        "dataset_a",
        JediMarketSpec.fixture("quotes_dataset_a.csv"),
        JediMarketSpec.fixture("labels.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      )
      importer.run

      ex = expect_raises(Jedi::LowLevelError, /already exists/) do
        importer.run
      end

      ex.log_context[:error_code]?.should eq("dataset_exists")
    end
  end

  it "rolls back the dataset on a structural quotation error" do
    JediMarketSpec.with_workspace do |_workspace|
      database = JediMarketSpec.initialized_database

      expect_raises(Jedi::LowLevelError, /invalid open value/) do
        Jedi::MarketData::MarketImporter.new(
          database,
          "broken",
          JediMarketSpec.fixture("quotes_structural_error.csv"),
          JediMarketSpec.fixture("labels_alpha.csv"),
          date_order: Jedi::MarketData::DateOrder::Ymd
        ).run
      end

      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM datasets WHERE code = ?",
        "broken"
      ).should eq(0_i64)
      JediMarketSpec.count(database, "SELECT COUNT(*) FROM quotes").should eq(0_i64)
    end
  end
end
