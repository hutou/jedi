require "./spec_helper"

describe Jedi::MarketData::GroupMembershipUpdater do
  it "can add and remove a security from an existing named group" do
    JediMarketSpec.with_workspace do |_workspace|
      database = JediMarketSpec.initialized_database

      Jedi::MarketData::MarketImporter.new(
        database,
        "dataset_a",
        JediMarketSpec.fixture("quotes_dataset_a.csv"),
        JediMarketSpec.fixture("labels.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      database.with_connection do |conn|
        Jedi::MarketData::GroupRepository.new(conn).upsert(
          "WATCHLIST",
          "manual",
          nil,
          "2026-09-24T00:00:00Z",
        )
      end

      added = Jedi::MarketData::GroupMembershipUpdater.new(
        database, "watchlist", "FR4487601001", true
      ).run
      added.group.code.should eq("WATCHLIST")
      added.changed.should be_true

      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM security_groups " \
        "WHERE group_code = 'WATCHLIST' AND isin = 'FR4487601001'"
      ).should eq(1_i64)

      removed = Jedi::MarketData::GroupMembershipUpdater.new(
        database, "WATCHLIST", "FR4487601001", false
      ).run
      removed.changed.should be_true

      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM security_groups " \
        "WHERE group_code = 'WATCHLIST' AND isin = 'FR4487601001'"
      ).should eq(0_i64)
    end
  end
end
