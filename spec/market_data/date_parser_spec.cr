require "./spec_helper"

describe Jedi::MarketData::DateParser do
  it "parses all supported orders, separators and year widths" do
    cases = [
      {Jedi::MarketData::DateOrder::Dmy, Jedi::MarketData::DateSeparator::Slash, Jedi::MarketData::YearWidth::Two, "31/12/25"},
      {Jedi::MarketData::DateOrder::Dmy, Jedi::MarketData::DateSeparator::Slash, Jedi::MarketData::YearWidth::Four, "31/12/2025"},
      {Jedi::MarketData::DateOrder::Dmy, Jedi::MarketData::DateSeparator::Dash, Jedi::MarketData::YearWidth::Two, "31-12-25"},
      {Jedi::MarketData::DateOrder::Dmy, Jedi::MarketData::DateSeparator::Dash, Jedi::MarketData::YearWidth::Four, "31-12-2025"},
      {Jedi::MarketData::DateOrder::Dmy, Jedi::MarketData::DateSeparator::None, Jedi::MarketData::YearWidth::Two, "311225"},
      {Jedi::MarketData::DateOrder::Dmy, Jedi::MarketData::DateSeparator::None, Jedi::MarketData::YearWidth::Four, "31122025"},
      {Jedi::MarketData::DateOrder::Mdy, Jedi::MarketData::DateSeparator::Slash, Jedi::MarketData::YearWidth::Two, "12/31/25"},
      {Jedi::MarketData::DateOrder::Mdy, Jedi::MarketData::DateSeparator::Slash, Jedi::MarketData::YearWidth::Four, "12/31/2025"},
      {Jedi::MarketData::DateOrder::Mdy, Jedi::MarketData::DateSeparator::Dash, Jedi::MarketData::YearWidth::Two, "12-31-25"},
      {Jedi::MarketData::DateOrder::Mdy, Jedi::MarketData::DateSeparator::Dash, Jedi::MarketData::YearWidth::Four, "12-31-2025"},
      {Jedi::MarketData::DateOrder::Mdy, Jedi::MarketData::DateSeparator::None, Jedi::MarketData::YearWidth::Two, "123125"},
      {Jedi::MarketData::DateOrder::Mdy, Jedi::MarketData::DateSeparator::None, Jedi::MarketData::YearWidth::Four, "12312025"},
      {Jedi::MarketData::DateOrder::Ymd, Jedi::MarketData::DateSeparator::Slash, Jedi::MarketData::YearWidth::Two, "25/12/31"},
      {Jedi::MarketData::DateOrder::Ymd, Jedi::MarketData::DateSeparator::Slash, Jedi::MarketData::YearWidth::Four, "2025/12/31"},
      {Jedi::MarketData::DateOrder::Ymd, Jedi::MarketData::DateSeparator::Dash, Jedi::MarketData::YearWidth::Two, "25-12-31"},
      {Jedi::MarketData::DateOrder::Ymd, Jedi::MarketData::DateSeparator::Dash, Jedi::MarketData::YearWidth::Four, "2025-12-31"},
      {Jedi::MarketData::DateOrder::Ymd, Jedi::MarketData::DateSeparator::None, Jedi::MarketData::YearWidth::Two, "251231"},
      {Jedi::MarketData::DateOrder::Ymd, Jedi::MarketData::DateSeparator::None, Jedi::MarketData::YearWidth::Four, "20251231"},
    ]

    cases.each do |order, separator, year_width, value|
      layout = Jedi::MarketData::DateLayout.new(order, separator, year_width)
      Jedi::MarketData::DateParser.new(layout).parse(value).should eq(
        Time.utc(2025, 12, 31)
      )
    end
  end

  it "applies the configured two-digit year pivot" do
    layout = Jedi::MarketData::DateLayout.new(
      Jedi::MarketData::DateOrder::Dmy,
      Jedi::MarketData::DateSeparator::Slash,
      Jedi::MarketData::YearWidth::Two
    )
    parser = Jedi::MarketData::DateParser.new(layout, 70)

    parser.parse("01/01/69").should eq(Time.utc(2069, 1, 1))
    parser.parse("01/01/70").should eq(Time.utc(1970, 1, 1))
  end

  it "rejects an impossible date" do
    layout = Jedi::MarketData::DateLayout.new(
      Jedi::MarketData::DateOrder::Dmy,
      Jedi::MarketData::DateSeparator::Slash,
      Jedi::MarketData::YearWidth::Four
    )

    expect_raises(Jedi::LowLevelError, /invalid date/) do
      Jedi::MarketData::DateParser.new(layout).parse("31/02/2025")
    end
  end
end

describe Jedi::MarketData::DateFormatDetector do
  it "honours an explicitly selected DMY order" do
    layout = Jedi::MarketData::DateFormatDetector.detect(
      ["14/08/98", "15/08/98"],
      order: Jedi::MarketData::DateOrder::Dmy
    )

    layout.order.should eq(Jedi::MarketData::DateOrder::Dmy)
    layout.separator.should eq(Jedi::MarketData::DateSeparator::Slash)
    layout.year_width.should eq(Jedi::MarketData::YearWidth::Two)
  end

  it "refuses to guess an ambiguous order" do
    expect_raises(Jedi::LowLevelError, /ambiguous date format/) do
      Jedi::MarketData::DateFormatDetector.detect([
        "03/04/25",
        "04/05/25",
      ])
    end
  end
end
