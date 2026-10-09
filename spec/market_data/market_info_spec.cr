require "./spec_helper"

describe Jedi::MarketData::MarketInfo do
  it "distinguishes the full import, latest quotation and validated freshness" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database

      Jedi::MarketData::MarketImporter.new(
        database,
        "dataset_a",
        JediMarketSpec.fixture("quotes_dataset_a.csv"),
        JediMarketSpec.fixture("labels.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      before = Jedi::MarketData::MarketInfo.new(database).run
      dataset_before = before.datasets.first

      quotes = workspace.write(
        "update.csv",
        <<-CSV
          FR4487601001;20200103;10.50;11.20;10.20;11.00;110
        CSV
      )
      labels = workspace.write(
        "update_labels.csv",
        <<-CSV
          ISIN;nom;ticker
          FR4487601001;Alpha;ALP
        CSV
      )

      Jedi::MarketData::DatasetUpdater.new(
        database,
        "dataset_a",
        quotes,
        labels,
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      after = Jedi::MarketData::MarketInfo.new(database).run
      dataset_after = after.datasets.first

      dataset_after.code.should eq("dataset_a")

      # A non-destructive dataset update must not redefine the period of the
      # last full import.
      dataset_after.import_date_first.should eq(dataset_before.import_date_first)
      dataset_after.import_date_last.should eq(dataset_before.import_date_last)
      dataset_after.imported_at.should eq(dataset_before.imported_at)

      # The currently available period, however, must include the update.
      dataset_after.current_date_first.should eq(dataset_before.current_date_first)
      dataset_after.current_date_last.should eq(Time.utc(2020, 1, 3))
      dataset_before.freshness_date_last.should eq(Time.utc(2020, 1, 2))
      dataset_after.freshness_date_last.should eq(Time.utc(2020, 1, 2))

      dataset_after.security_count.should eq(dataset_before.security_count)
      dataset_after.quote_count.should eq(dataset_before.quote_count + 1)

      after.quote_count.should eq(before.quote_count + 1)
      after.date_first.should eq(before.date_first)
      after.date_last.should eq(Time.utc(2020, 1, 3))

      after.integrity.valid?.should be_true

      ["fr", "en"].each do |locale|
        Jedi.init_i18n(locale)
        rendered = Jedi::MarketData::MarketInfoPresenter.new(after).to_s
        rendered.should contain(I18n.t("market.info.dataset_import_period"))
        rendered.should contain(I18n.t("market.info.dataset_current_period"))
        freshness_line = rendered.lines.find do |line|
          line.includes?(I18n.t("market.info.dataset_freshness_date_last"))
        end.not_nil!
        freshness_line.should contain("2020-01-02")
      end
      JediMarketSpec.initialize_i18n
    end
  end

  it "can restrict the report to one dataset" do
    JediMarketSpec.with_workspace do |_workspace|
      database = JediMarketSpec.initialized_database

      Jedi::MarketData::MarketImporter.new(
        database,
        "dataset_a",
        JediMarketSpec.fixture("quotes_dataset_a.csv"),
        JediMarketSpec.fixture("labels.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      report = Jedi::MarketData::MarketInfo.new(
        database,
        "dataset_a"
      ).run

      report.datasets.size.should eq(1)
      report.datasets.first.code.should eq("dataset_a")
    end
  end

  it "raises when the requested dataset does not exist" do
    JediMarketSpec.with_workspace do |_workspace|
      database = JediMarketSpec.initialized_database

      ex = expect_raises(Jedi::LowLevelError, /not found/) do
        Jedi::MarketData::MarketInfo.new(
          database,
          "missing"
        ).run
      end

      ex.log_context[:error_code]?.should eq("dataset_not_found")
      ex.log_context[:dataset_code]?.should eq("missing")
    end
  end
end
