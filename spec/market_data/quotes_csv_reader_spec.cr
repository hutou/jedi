require "./spec_helper"

describe Jedi::MarketData::QuotesCsvReader do
  it "skips a leading standalone ABCBourse date" do
    rows = Jedi::MarketData::QuotesCsvReader.new(
      JediMarketSpec.fixture("pea_quotes.csv"),
      date_order: Jedi::MarketData::DateOrder::Ymd
    ).to_a

    rows.size.should eq(2)
    rows.first.isin.should eq("FR4487601001")
    rows.first.quote[:date].should eq(Time.utc(2026, 8, 3))
  end

  it "applies the selector before OHLCV validation" do
    retained = [] of Jedi::MarketData::QuoteRow
    selector = ->(_isin : String, date : Time) {
      date >= Time.utc(2020, 1, 1)
    }
    anomalies = [] of Jedi::MarketData::QuoteAnomaly
    handler = ->(anomaly : Jedi::MarketData::QuoteAnomaly) {
      anomalies << anomaly
      nil
    }

    reader = Jedi::MarketData::QuotesCsvReader.new(
      JediMarketSpec.fixture("quotes_mixed.csv"),
      date_order: Jedi::MarketData::DateOrder::Ymd
    )
    reader.each(selector, handler) { |row| retained << row }

    retained.size.should eq(3)
    anomalies.size.should eq(1)
    anomalies.first.date.should eq(Time.utc(2020, 1, 3))
    anomalies.first.reason.should contain("close is greater than high")
  end

  it "raises on structural numeric conversion errors" do
    reader = Jedi::MarketData::QuotesCsvReader.new(
      JediMarketSpec.fixture("quotes_structural_error.csv"),
      date_order: Jedi::MarketData::DateOrder::Ymd
    )

    expect_raises(Jedi::LowLevelError, /invalid open value/) do
      reader.to_a
    end
  end

  it "accepts volumes greater than Int32::MAX" do
    JediMarketSpec.with_workspace do |workspace|
      filename = workspace.write(
        "large_volume.csv",
        "FR4487601001;07/03/25;1.00;1.10;0.90;1.05;4220557368\n"
      )

      rows = Jedi::MarketData::QuotesCsvReader.new(
        filename,
        date_order: Jedi::MarketData::DateOrder::Dmy
      ).to_a

      rows.size.should eq(1)
      rows.first.quote[:volume].should eq(4_220_557_368_i64)
    end
  end

  it "logs the Crystal source for an invalid volume conversion" do
    JediMarketSpec.with_workspace do |workspace|
      filename = workspace.write(
        "invalid_volume.csv",
        "FR4487601001;07/03/25;1.00;1.10;0.90;1.05;999999999999999999999999\n"
      )

      ex = expect_raises(Jedi::LowLevelError, /invalid volume/) do
        Jedi::MarketData::QuotesCsvReader.new(
          filename,
          date_order: Jedi::MarketData::DateOrder::Dmy
        ).to_a
      end

      ex.log_context[:source]?.should_not be_nil
      ex.log_context[:source].should contain("jedi/market_data/quotes_csv_reader.cr:")
      ex.log_context[:filename].should eq(filename)
      ex.log_context[:line].should eq("1")
    end
  end

  it "rejects a standalone date after quotation data" do
    expect_raises(Jedi::LowLevelError, /expected at least 2 fields/) do
      Jedi::MarketData::QuotesCsvReader.new(
        JediMarketSpec.fixture("quotes_header_after_data.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).to_a
    end
  end
end
