require "./spec_helper"

describe Jedi::MarketData::MarketInitializer do
  it "creates an empty market database" do
    JediMarketSpec.with_workspace do |_workspace|
      database = Jedi::MarketData::Database.new("abcbourse", Jedi::App.default_market_universe)
      report = Jedi::MarketData::MarketInitializer.new(database).run

      database.exists?.should be_true
      report.operation.should eq(Jedi::MarketData::ImportOperation::Init)
      JediMarketSpec.count(database, "SELECT COUNT(*) FROM datasets").should eq(0_i64)
    end
  end

  it "reports database_exists when the database already exists" do
    JediMarketSpec.with_workspace do |_workspace|
      database = JediMarketSpec.initialized_database("abcbourse")

      ex = expect_raises(Jedi::LowLevelError, /already exists/) do
        Jedi::MarketData::MarketInitializer.new(database).run
      end

      ex.log_context[:error_code]?.should eq("database_exists")
    end
  end
end
