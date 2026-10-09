require "./spec_helper"

describe Jedi::MarketData::LabelsCsvReader do
  it "reads the ABCBourse labels format and skips its header" do
    securities = Jedi::MarketData::LabelsCsvReader.new(
      JediMarketSpec.fixture("labels.csv")
    ).to_a

    securities.size.should eq(2)
    securities.first.isin.should eq("FR4487601001")
    securities.first.name.should eq("Alpha")
    securities.first.ticker.should eq("ALP")
  end

  it "preserves semicolons contained in a security name" do
    security = Jedi::MarketData::LabelsCsvReader.new(
      JediMarketSpec.fixture("labels_name_with_separator.csv")
    ).to_a.first

    security.name.should eq("Alpha;Holding")
  end

  it "rejects a duplicated ISIN" do
    expect_raises(Jedi::LowLevelError, /duplicate ISIN/) do
      Jedi::MarketData::LabelsCsvReader.new(
        JediMarketSpec.fixture("labels_duplicate.csv")
      ).to_a
    end
  end
end
