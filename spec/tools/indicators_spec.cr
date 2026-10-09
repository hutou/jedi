require "../spec_helper"

describe Jedi::Tools::Indicators do
  it "distinguishes the raw price slope from the normalized percentage slope" do
    filename = File.expand_path(
      "../fixtures/tools/indicators_linear_quotes.csv",
      __DIR__,
    )
    history = Jedi::Tools::QuoteHistory.new(filename)
    indicators = Jedi::Tools::Indicators.new(history)

    indicators.regression_slope.should be_close(1.0, 0.000_000_1)
    indicators.regression_intercept.should be_close(100.0, 0.000_000_1)
    indicators.normalized_regression_slope.should be_close(
      0.01,
      0.000_000_1,
    )
    indicators.normalized_regression_slope_percent.should be_close(
      1.0,
      0.000_000_1,
    )
    indicators.regression_slope_percent.should be_close(1.0, 0.000_000_1)
    indicators.correlation_coefficient.should be_close(1.0, 0.000_000_1)
    indicators.determination_coefficient.should be_close(1.0, 0.000_000_1)
  end
end
