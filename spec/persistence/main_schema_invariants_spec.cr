require "../support/jedi_spec_helper"

describe Jedi::Database::Main do
  it "enforces core security invariants in SQLite" do
    JediSpec.with_db do |conn|
      sql = "INSERT INTO security (isin, name, ticker, tick_buy, tick_sell, tax) " \
            "VALUES (?, ?, ?, ?, ?, ?)"
      expect_raises(SQLite3::Exception) do
        conn.exec(sql,
          "INVALID", "", "", 0.0, 0.0, -0.01)
      end
      # Reset the cached SQLite statement after the expected constraint error.
      conn.exec(sql, "FR4487601001", "VALID", "", 0.01, 0.01, 0.0)
      conn.scalar("SELECT ticker FROM security WHERE isin = ?",
        "FR4487601001").as(String).should be_empty
    end
  end

  it "enforces positive operation quantities and valid prices in SQLite" do
    JediSpec.with_db do |conn|
      JediSpec.insert_security(conn)
      JediSpec.insert_scale(conn)
      JediSpec.insert_trade(conn)
      JediSpec.insert_settings(conn)

      expect_raises(SQLite3::Exception) do
        JediSpec.insert_operation(conn, quantity: 0, price: 0.0, stock: 0)
      end
      # Reset the cached SQLite statement after the expected constraint error.
      JediSpec.insert_operation(conn, id: 2_i64)
    end
  end

  it "allows a zero price only for a full liquidation sale in SQLite" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      JediSpec.insert_operation(conn,
        id: 2_i64,
        type: Jedi::TradingLife::Operation::Type::Sell,
        mode: Jedi::TradingLife::Operation::Mode::Market,
        quantity: 100,
        price: 0.0,
        stock: 0,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0),
        trade_invest: 100_000,
        global_invest: 100_000)

      conn.scalar("SELECT price FROM operation WHERE id = 2").as(Float64)
        .should eq(0.0)
    end

    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      expect_raises(SQLite3::Exception) do
        JediSpec.insert_operation(conn,
          id: 2_i64,
          type: Jedi::TradingLife::Operation::Type::Sell,
          mode: Jedi::TradingLife::Operation::Mode::Market,
          quantity: 99,
          price: 0.0,
          stock: 1,
          timestamp: Time.local(2026, 1, 1, 11, 0, 0))
      end
      # Reset the cached SQLite statement after the expected constraint error.
      JediSpec.insert_operation(conn,
        id: 3_i64,
        type: Jedi::TradingLife::Operation::Type::Sell,
        mode: Jedi::TradingLife::Operation::Mode::Market,
        quantity: 100,
        price: 0.0,
        stock: 0,
        timestamp: Time.local(2026, 1, 1, 12, 0, 0),
        trade_invest: 100_000,
        global_invest: 100_000)
    end
  end

  it "enforces foreign keys for orphan inserts and referenced deletes" do
    JediSpec.with_db do |conn|
      conn.scalar("PRAGMA foreign_keys").as(Int64).should eq(1_i64)
      JediSpec.seed_basic_trade(conn)

      expect_raises(SQLite3::Exception) do
        JediSpec.insert_trade(conn,
          id: 2_i64,
          name: "ORPHAN TRADE",
          security_id: 999_i64)
      end
      # Reset the cached statement after the expected constraint error.
      JediSpec.insert_trade(conn,
        id: 2_i64,
        name: "TEMPORARY TRADE",
        security_id: 1_i64)
      conn.exec("DELETE FROM trade WHERE id = ?", 2_i64)

      expect_raises(SQLite3::Exception) do
        conn.exec("DELETE FROM settings WHERE id = ?", 1_i64)
      end
      # Reset the cached statement after the expected constraint error.
      JediSpec.insert_settings(conn,
        id: 2_i64,
        timestamp: Time.local(2026, 1, 1, 9, 1, 0))
      conn.exec("DELETE FROM settings WHERE id = ?", 2_i64)

      conn.scalar("SELECT COUNT(*) FROM trade").as(Int64).should eq(1_i64)
      conn.scalar("SELECT COUNT(*) FROM settings").as(Int64).should eq(1_i64)
      conn.scalar("SELECT COUNT(*) FROM operation").as(Int64).should eq(1_i64)
    end
  end

  it "keeps the compiled schema digest synchronized with the created schema" do
    JediSpec.with_db do |conn|
      Digest::SHA256.hexdigest(Jedi::App.get_schema(conn)).should eq(
        Jedi::App::DB_SCHEMA_DIGEST)
    end
  end
end
