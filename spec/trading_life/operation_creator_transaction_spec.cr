require "../support/jedi_spec_helper"

describe Jedi::TradingLife::OperationCreator do
  it "rolls the operation back when the initial q0/c0 update fails" do
    JediSpec.with_db do |conn|
      JediSpec.insert_security(conn)
      JediSpec.insert_scale(conn)
      JediSpec.insert_trade(conn)
      JediSpec.insert_settings(conn, q0: 0.0, c0: 0.0)

      conn.exec(<<-SQL)
        CREATE TRIGGER reject_initial_q0_c0
        BEFORE UPDATE OF q0, c0 ON settings
        BEGIN
          SELECT RAISE(ABORT, 'forced q0/c0 update failure');
        END;
        SQL

      expect_raises(SQLite3::Exception) do
        Jedi::TradingLife::OperationCreator.new(conn).call(
          trade_ident: 1_i64,
          timestamp: Time.local(2026, 1, 1, 10, 0, 0),
          type: Jedi::TradingLife::Operation::Type::Buy,
          mode: Jedi::TradingLife::Operation::Mode::Market,
          quantity: 100,
          price: 10.0,
          cfees: 0.0,
          tickcheck: false
        )
      end
      # Reset the cached statement after the expected trigger error.
      conn.exec("DROP TRIGGER reject_initial_q0_c0")
      conn.exec("UPDATE settings SET q0 = ?, c0 = ? WHERE id = ?",
        0.0, 0.0, 1_i64)

      conn.scalar("SELECT COUNT(*) FROM operation").as(Int64).should eq(0_i64)
      conn.query_one("SELECT q0, c0 FROM settings WHERE id = ?", 1_i64,
        as: {Float64, Float64}).should eq({0.0, 0.0})
    end
  end
end
