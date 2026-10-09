require "../support/jedi_spec_helper"

module JediExchangeServiceInvariantsSpec
  extend self

  def create_security(
    conn,
    *,
    isin : String = "FR4487601001",
    name : String = "SPEC SECURITY",
    ticker : String = "SPEC",
    tax : Float64 = 0.0,
    quotation_price : Float64? = nil,
  ) : Jedi::PkId
    Jedi::Exchange::SecurityCreator.new(conn).call(
      isin: isin,
      name: name,
      ticker: ticker,
      tick_buy: Jedi::Exchange::Security::Tick.new(0.01),
      tick_sell: Jedi::Exchange::Security::Tick.new(0.01),
      tax: tax,
      quotation_price: quotation_price
    )
  end

  def security_count(conn) : Int64
    conn.scalar("SELECT COUNT(*) FROM security").as(Int64)
  end
end

describe Jedi::Exchange::QuoteSetter do
  it "rejects non-positive and non-finite prices without changing the security" do
    [0.0, -1.0, Float64::NAN, Float64::INFINITY].each do |price|
      JediSpec.with_db do |conn|
        JediSpec.insert_security(conn)
        security = Jedi::Exchange::Security.new(conn, 1_i64)

        ex = expect_raises(Jedi::LowLevelError) do
          Jedi::Exchange::QuoteSetter.new(security).set(price)
        end

        ex.key.should eq("quote.set.price_must_be_positive")
        security.reload!
        security.quotation_price.should be_nil
      end
    end
  end
end

describe Jedi::Exchange::SecurityCreator do
  it "rejects an invalid ISIN" do
    JediSpec.with_db do |conn|
      ex = expect_raises(Jedi::LowLevelError) do
        JediExchangeServiceInvariantsSpec.create_security(conn, isin: "INVALID")
      end

      ex.key.should eq("security.create.invalid_isin")
      JediExchangeServiceInvariantsSpec.security_count(conn).should eq(0_i64)
    end
  end

  it "rejects a blank name" do
    JediSpec.with_db do |conn|
      ex = expect_raises(Jedi::LowLevelError) do
        JediExchangeServiceInvariantsSpec.create_security(conn, name: "  ")
      end

      ex.key.should eq("security.create.name_required")
      JediExchangeServiceInvariantsSpec.security_count(conn).should eq(0_i64)
    end
  end

  it "accepts an empty ticker" do
    JediSpec.with_db do |conn|
      security_id = JediExchangeServiceInvariantsSpec.create_security(conn,
        ticker: "")

      JediExchangeServiceInvariantsSpec.security_count(conn).should eq(1_i64)
      Jedi::Exchange::Security.new(conn, security_id).ticker.should be_empty
    end
  end

  it "rejects negative and non-finite tax rates" do
    [-0.01, Float64::NAN, Float64::INFINITY].each do |tax|
      JediSpec.with_db do |conn|
        ex = expect_raises(Jedi::LowLevelError) do
          JediExchangeServiceInvariantsSpec.create_security(conn, tax: tax)
        end

        ex.key.should eq("security.create.invalid_tax")
        JediExchangeServiceInvariantsSpec.security_count(conn).should eq(0_i64)
      end
    end
  end

  it "rejects a non-positive or non-finite initial quotation" do
    [0.0, -1.0, Float64::NAN, Float64::INFINITY].each do |price|
      JediSpec.with_db do |conn|
        ex = expect_raises(Jedi::LowLevelError) do
          JediExchangeServiceInvariantsSpec.create_security(conn,
            quotation_price: price)
        end

        ex.key.should eq("security.create.invalid_quotation_price")
        JediExchangeServiceInvariantsSpec.security_count(conn).should eq(0_i64)
      end
    end
  end
end
