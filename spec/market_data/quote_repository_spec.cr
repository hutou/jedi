require "./spec_helper"

describe Jedi::MarketData::QuoteRepository do
  describe ".same?" do
    base = {
      date:   Time.utc(2026, 7, 1),
      open:   7.795,
      high:   7.795,
      low:    7.597,
      close:  7.62,
      volume: 186741_i64,
    }

    it "accepts OHLC differences up to one thousandth" do
      incoming = base.merge({low: 7.598})

      Jedi::MarketData::QuoteRepository.same?(base, incoming).should be_true
    end

    it "rejects OHLC differences greater than one thousandth" do
      incoming = base.merge({low: 7.608})

      Jedi::MarketData::QuoteRepository.same?(base, incoming).should be_false
    end

    it "keeps volume comparison strict" do
      incoming = base.merge({volume: 186742_i64})

      Jedi::MarketData::QuoteRepository.same?(base, incoming).should be_false
    end
  end
end
