require "./spec_helper"

describe Jedi::MarketData::GroupSynchronizer do
  it "normalizes valid group codes and rejects invalid ones" do
    Jedi::MarketData::GroupSynchronizer.normalize_group_code!("watch-list")
      .should eq("WATCH-LIST")

    error = expect_raises(Jedi::LowLevelError) do
      Jedi::MarketData::GroupSynchronizer.normalize_group_code!("invalid group")
    end
    error.key.should eq("market.invalid_group")
    error.log_context[:error_code].should eq("invalid_group_code")
  end

  it "replaces a named group from ISIN or ticker references" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database

      Jedi::MarketData::MarketImporter.new(
        database,
        "dataset_a",
        JediMarketSpec.fixture("quotes_dataset_a.csv"),
        JediMarketSpec.fixture("labels.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      report = Jedi::MarketData::GroupSynchronizer.new(
        database,
        "pea",
        JediMarketSpec.fixture("pea_references.txt"),
        reference_source: "prorealtime",
        as_of: Time.utc(2026, 9, 10)
      ).run

      report.group_code.should eq("PEA")
      report.group_rows_read.should eq(5_i64)
      report.group_references_read.should eq(3_i64)
      report.group_matched.should eq(2_i64)
      report.unknown_isins.should eq(["UNKNOWN"])
      report.added_group_isins.should eq(["FR0000000002", "FR4487601001"])
      report.removed_group_isins.empty?.should be_true

      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM security_groups WHERE group_code = 'PEA'"
      ).should eq(2_i64)

      JediMarketSpec.text_value(
        database,
        "SELECT reference_source FROM market_groups WHERE code = 'PEA'"
      ).should eq("prorealtime")
      JediMarketSpec.count(
        database,
        "SELECT reference_date FROM market_groups WHERE code = 'PEA'"
      ).should eq(20260910_i64)

      replacement = workspace.write("pea_replacement.txt", "ALP Alpha\n")
      second = Jedi::MarketData::GroupSynchronizer.new(
        database,
        "PEA",
        replacement,
      ).run

      second.added_group_isins.empty?.should be_true
      second.removed_group_isins.should eq(["FR0000000002"])
      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM security_groups WHERE group_code = 'PEA'"
      ).should eq(1_i64)
    end
  end

  it "does not replace a group when no reference matches" do
    JediMarketSpec.with_workspace do |workspace|
      database = JediMarketSpec.initialized_database
      references = workspace.write("unknown.txt", "UNKNOWN\n")

      expect_raises(Jedi::LowLevelError, /no security/) do
        Jedi::MarketData::GroupSynchronizer.new(
          database,
          "WATCHLIST",
          references,
        ).run
      end

      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM market_groups WHERE code = 'WATCHLIST'"
      ).should eq(0_i64)
    end
  end
end
