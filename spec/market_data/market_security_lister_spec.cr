require "./spec_helper"

describe Jedi::MarketData::MarketSecurityLister do
  it "lists all market securities with their dataset memberships" do
    JediMarketSpec.with_workspace do |_workspace|
      JediMarketSpec.initialize_i18n
      database = JediMarketSpec.initialized_database

      import_dataset(database, "dataset_a", "quotes_dataset_a.csv")
      import_dataset(database, "dataset_b", "quotes_dataset_b.csv")
      set_group_member(database, "PEA", "FR4487601001", true)

      text = Jedi::MarketData::MarketSecurityLister.new(database).run

      text.should contain("FR4487601001")
      text.should contain("ALP")
      text.should contain("Alpha")
      text.should contain("PEA")
      text.should contain("dataset_a, dataset_b")
      text.should contain("FR0000000002")
      text.should contain("BET")
      text.should contain("Beta")
    end
  end

  it "can restrict the list to a dataset without displaying the dataset column" do
    JediMarketSpec.with_workspace do |_workspace|
      JediMarketSpec.initialize_i18n
      database = JediMarketSpec.initialized_database

      import_dataset(database, "dataset_a", "quotes_dataset_a.csv")
      import_dataset(database, "dataset_b", "quotes_dataset_b.csv")

      text = Jedi::MarketData::MarketSecurityLister.new(
        database,
        "dataset_b"
      ).run

      text.should contain("FR4487601001")
      text.should_not contain("Dataset(s)")
      text.should_not contain("FR0000000002")
    end
  end

  it "can display the latest quotation date and close" do
    JediMarketSpec.with_workspace do |_workspace|
      JediMarketSpec.initialize_i18n
      database = JediMarketSpec.initialized_database

      import_dataset(database, "dataset_a", "quotes_dataset_a.csv")
      import_dataset(database, "dataset_b", "quotes_dataset_b.csv")

      text = Jedi::MarketData::MarketSecurityLister.new(
        database,
        nil,
        nil,
        last_quote: true
      ).run

      text.should contain("Date")
      text.should contain("Clôture")
      text.should contain("2020-01-03")
      text.should contain("11")
    end
  end

  it "supports named regex filters" do
    JediMarketSpec.with_workspace do |_workspace|
      JediMarketSpec.initialize_i18n
      database = JediMarketSpec.initialized_database

      import_dataset(database, "dataset_a", "quotes_dataset_a.csv")
      set_group_member(database, "PEA", "FR4487601001", true)

      text = Jedi::MarketData::MarketSecurityLister.new(
        database,
        nil,
        "group=PEA && ticker=^AL"
      ).run

      text.should contain("FR4487601001")
      text.should contain("Alpha")
      text.should_not contain("FR0000000002")
      text.should_not contain("Beta")
    end
  end

  it "raises when the requested dataset does not exist" do
    JediMarketSpec.with_workspace do |_workspace|
      database = JediMarketSpec.initialized_database

      ex = expect_raises(Jedi::LowLevelError, /not found/) do
        Jedi::MarketData::MarketSecurityLister.new(
          database,
          "missing"
        ).run
      end

      ex.log_context[:error_code]?.should eq("dataset_not_found")
      ex.log_context[:dataset_code]?.should eq("missing")
    end
  end
end

private def import_dataset(
  database : Jedi::MarketData::Database,
  code : String,
  quotes_fixture : String,
) : Nil
  Jedi::MarketData::MarketImporter.new(
    database,
    code,
    JediMarketSpec.fixture(quotes_fixture),
    JediMarketSpec.fixture("labels.csv"),
    date_order: Jedi::MarketData::DateOrder::Ymd
  ).run
end

private def set_group_member(
  database : Jedi::MarketData::Database,
  group : String,
  isin : String,
  member : Bool,
) : Nil
  database.with_connection do |conn|
    repository = Jedi::MarketData::GroupRepository.new(conn)
    repository.upsert(
      group,
      "test",
      nil,
      "2026-09-24T00:00:00Z",
    )
    if member
      repository.add_member(group, isin)
    else
      repository.remove_member(group, isin)
    end
  end
end
