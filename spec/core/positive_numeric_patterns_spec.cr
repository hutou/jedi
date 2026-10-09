require "../support/jedi_spec_helper"

describe "positive numeric input patterns" do
  it "distinguishes strictly positive decimals from zero" do
    ["1", "+1", "0.01", "10.0"].each do |value|
      value.should match(Jedi::POSITIVE_DECIMAL)
    end
    ["0", "+0", "0.0", "00.000"].each do |value|
      value.should_not match(Jedi::POSITIVE_DECIMAL)
      value.should match(Jedi::NON_NEGATIVE_DECIMAL)
    end
  end

  it "distinguishes strictly positive integers from zero" do
    ["1", "+1", "001"].each do |value|
      value.should match(Jedi::POSITIVE_INTEGER)
    end
    ["0", "+0", "000"].each do |value|
      value.should_not match(Jedi::POSITIVE_INTEGER)
      value.should match(Jedi::NON_NEGATIVE_INTEGER)
    end
  end
end
