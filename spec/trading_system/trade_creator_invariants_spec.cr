require "../support/jedi_spec_helper"

describe Jedi::TradingSystem::TradeCreator do
  it "rejects invalid trade names" do
    ["", "A", "1A", "A-B", "A B"].each do |name|
      JediSpec.with_db do |conn|
        JediSpec.insert_security(conn)

        ex = expect_raises(Jedi::LowLevelError) do
          Jedi::TradingSystem::TradeCreator.new(conn).call(
            name: name,
            security_ident: 1_i64,
            money: nil)
        end

        ex.key.should eq("trade.create.invalid_name")
        conn.scalar("SELECT COUNT(*) FROM trade").as(Int64).should eq(0_i64)
      end
    end
  end

  it "rejects non-positive numeric security identifiers" do
    [0_i64, -1_i64].each do |security_ident|
      JediSpec.with_db do |conn|
        JediSpec.insert_security(conn)

        ex = expect_raises(Jedi::LowLevelError) do
          Jedi::TradingSystem::TradeCreator.new(conn).call(
            name: "TVALID",
            security_ident: security_ident,
            money: nil)
        end

        ex.key.should eq("trade.create.invalid_security_identifier")
        conn.scalar("SELECT COUNT(*) FROM trade").as(Int64).should eq(0_i64)
      end
    end
  end

  it "rejects malformed textual security identifiers" do
    JediSpec.with_db do |conn|
      JediSpec.insert_security(conn)

      ex = expect_raises(Jedi::LowLevelError) do
        Jedi::TradingSystem::TradeCreator.new(conn).call(
          name: "TVALID",
          security_ident: "INVALID",
          money: nil)
      end

      ex.key.should eq("trade.create.invalid_security_identifier")
      conn.scalar("SELECT COUNT(*) FROM trade").as(Int64).should eq(0_i64)
    end
  end
end
