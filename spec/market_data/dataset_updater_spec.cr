require "./spec_helper"

private def seed_dataset(
  database : Jedi::MarketData::Database,
) : Jedi::MarketData::ImportReport
  Jedi::MarketData::MarketImporter.new(
    database,
    "dataset_a",
    JediMarketSpec.fixture("quotes_dataset_a.csv"),
    JediMarketSpec.fixture("labels.csv"),
    date_order: Jedi::MarketData::DateOrder::Ymd
  ).run
end

describe Jedi::MarketData::DatasetUpdater do
  it "extends a dataset continuously and can add a new security" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      seed_dataset(database)

      quotes = workspace.write(
        "update.csv",
        <<-CSV
          FR4487601001;20200103;10.50;11.20;10.20;11.00;110
          FR0000000003;20200103;30.00;31.00;29.50;30.50;300
        CSV
      )
      labels = workspace.write(
        "labels.csv",
        <<-CSV
          ISIN;nom;ticker
          FR4487601001;Alpha;ALP
          FR0000000003;Gamma;GAM
        CSV
      )

      report = Jedi::MarketData::DatasetUpdater.new(
        database,
        "dataset_a",
        quotes,
        labels,
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      report.operation.should eq(Jedi::MarketData::ImportOperation::Update)
      report.dataset_date_last_before.should eq(Time.utc(2020, 1, 2))
      report.extension_date_first.should eq(Time.utc(2020, 1, 3))
      report.gap_days.should eq(1)
      report.gap_allowed.should be_false
      report.securities_inserted.should eq(1_i64)
      report.securities_linked.should eq(1_i64)
      report.quotes_inserted.should eq(2_i64)
      report.quotes_linked.should eq(2_i64)

      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM security_datasets WHERE dataset_code = ?",
        "dataset_a"
      ).should eq(3_i64)

      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM quote_datasets WHERE dataset_code = ?",
        "dataset_a"
      ).should eq(4_i64)
    end
  end

  it "rejects an extension gap and rolls the complete update back" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      seed_dataset(database)

      # The duplicate at the old boundary deliberately proves that an isolated
      # overlap cannot hide the much later first extension date.
      quotes = workspace.write(
        "gap.csv",
        <<-CSV
          FR4487601001;20200102;10.00;11.00;9.00;10.50;100
          FR4487601001;20200331;10.50;11.20;10.20;11.00;110
        CSV
      )
      labels = workspace.write(
        "labels.csv",
        <<-CSV
          ISIN;nom;ticker
          FR4487601001;Alpha;ALP
        CSV
      )

      ex = expect_raises(Jedi::LowLevelError, /history gap/) do
        Jedi::MarketData::DatasetUpdater.new(
          database,
          "dataset_a",
          quotes,
          labels,
          date_order: Jedi::MarketData::DateOrder::Ymd
        ).run
      end

      ex.log_context[:error_code]?.should eq("dataset_gap")
      ex.log_context[:last_date]?.should eq("2020-01-02")
      ex.log_context[:first_date]?.should eq("2020-03-31")
      ex.log_context[:gap_days]?.should eq("89")

      JediMarketSpec.count(database, "SELECT COUNT(*) FROM quotes").should eq(2_i64)
      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM quote_datasets WHERE dataset_code = ?",
        "dataset_a"
      ).should eq(2_i64)
      database.with_connection do |conn|
        Jedi::MarketData::DatasetRepository.new(conn).freshness_date_last("dataset_a").should eq(Time.utc(2020, 1, 2))
      end
    end
  end

  it "accepts the same gap only when allow_gap is explicit" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      seed_dataset(database)

      quotes = workspace.write(
        "gap.csv",
        <<-CSV
          FR4487601001;20200331;10.50;11.20;10.20;11.00;110
        CSV
      )
      labels = workspace.write(
        "labels.csv",
        <<-CSV
          ISIN;nom;ticker
          FR4487601001;Alpha;ALP
        CSV
      )

      report = Jedi::MarketData::DatasetUpdater.new(
        database,
        "dataset_a",
        quotes,
        labels,
        date_order: Jedi::MarketData::DateOrder::Ymd,
        allow_gap: true
      ).run

      report.gap_allowed.should be_true
      report.gap_days.should eq(89)
      report.extension_date_first.should eq(Time.utc(2020, 3, 31))
      report.quotes_inserted.should eq(1_i64)

      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM quote_datasets WHERE dataset_code = ?",
        "dataset_a"
      ).should eq(3_i64)
    end
  end

  it "allows a historical backfill even when it does not extend the dataset" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      seed_dataset(database)

      quotes = workspace.write(
        "backfill.csv",
        <<-CSV
          FR4487601001;20200101;9.80;10.20;9.50;10.00;90
        CSV
      )
      labels = workspace.write(
        "labels.csv",
        <<-CSV
          ISIN;nom;ticker
          FR4487601001;Alpha;ALP
        CSV
      )

      report = Jedi::MarketData::DatasetUpdater.new(
        database,
        "dataset_a",
        quotes,
        labels,
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      report.extension_date_first.should be_nil
      report.gap_days.should be_nil
      report.quotes_inserted.should eq(1_i64)
    end
  end
  it "accepts price differences up to one thousandth as identical duplicates" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      seed_dataset(database)

      quotes = workspace.write(
        "tolerance.csv",
        <<-CSV
          FR4487601001;20200102;10.001;11.001;9.001;10.501;100
        CSV
      )
      labels = workspace.write(
        "labels.csv",
        <<-CSV
          ISIN;nom;ticker
          FR4487601001;Alpha;ALP
        CSV
      )

      report = Jedi::MarketData::DatasetUpdater.new(
        database,
        "dataset_a",
        quotes,
        labels,
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      report.identical_duplicates.should eq(1_i64)
      report.quotes_skipped_conflicting.should eq(0_i64)
      report.quotes_inserted.should eq(0_i64)
    end
  end

  it "keeps stored quotations and reports material conflicts without aborting" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      seed_dataset(database)

      quotes = workspace.write(
        "conflict.csv",
        <<-CSV
          FR4487601001;20200102;10.00;11.00;8.98;10.50;100
          FR4487601001;20200103;10.50;11.20;10.20;11.00;110
        CSV
      )
      labels = workspace.write(
        "labels.csv",
        <<-CSV
          ISIN;nom;ticker
          FR4487601001;Alpha;ALP
        CSV
      )

      report = Jedi::MarketData::DatasetUpdater.new(
        database,
        "dataset_a",
        quotes,
        labels,
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      report.quotes_skipped_conflicting.should eq(1_i64)
      report.quote_conflicts.size.should eq(1)
      report.quotes_inserted.should eq(1_i64)

      database.with_connection do |conn|
        stored = Jedi::MarketData::QuoteRepository.new(conn).find(
          "FR4487601001",
          Time.utc(2020, 1, 2)
        ).not_nil!
        stored[:low].should eq(9.00)
      end
    end
  end
end
