require "../spec_helper"
require "../support/cli_spec_helper"

describe Jedi::Command, "CLI operation fees" do
  it "corrects an older operation in a closed trade without changing its other fields" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.insert_security(conn)
      JediSpec.insert_scale(conn)
      JediSpec.insert_trade(conn)
      JediSpec.insert_settings(conn)
      JediCliSpec.run(conn, "operation", "create", "T_TEST",
        "2026-01-01", "10:00:00", "Buy", "Market", "100", "10.0")
      JediCliSpec.run(conn, "operation", "create", "T_TEST",
        "2026-01-02", "10:00:00", "Sell", "Market", "100", "12.0")
      before = Jedi::TradingLife::Operations.new(conn).fetch.to_a.map(&.record)
      before.first[:fees].should eq(350)
      before.last[:stock].should eq(0)

      JediCliSpec.run(conn, "operation", "fees", "1", "1.25")

      after = Jedi::TradingLife::Operations.new(conn).fetch.to_a.map(&.record)
      after.should eq(before.map do |record|
        record[:id] == 1_i64 ? record.merge(fees: 125) : record
      end)
      JediCliSpec.table_count(conn, "settings").should eq(1)
    end
  end

  it "allows zero fees and safely repeats the same correction" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.seed_basic_trade(conn)
      JediCliSpec.run(conn, "operation", "fees", "1", "2.50")
      2.times { JediCliSpec.run(conn, "operation", "fees", "1", "0") }

      Jedi::TradingLife::Operation.new(conn, 1_i64).fees.should eq(0)
      JediCliSpec.table_count(conn, "operation").should eq(1)
    end
  end

  it "rounds the replacement amount to cents" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.seed_basic_trade(conn)
      JediCliSpec.run(conn, "operation", "fees", "1", "3.456")

      Jedi::TradingLife::Operation.new(conn, 1_i64).fees.should eq(346)
    end
  end

  it "accepts operation identifiers larger than Int32" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.seed_basic_trade(conn)
      JediSpec.insert_operation(conn, id: 3_000_000_000_i64)
      JediCliSpec.run(conn, "operation", "fees", "3000000000", "4.20")

      Jedi::TradingLife::Operation.new(conn, 3_000_000_000_i64).fees.should eq(420)
      Jedi::TradingLife::Operation.new(conn, 1_i64).fees.should eq(0)
    end
  end

  it "shows corrected fees in lists, CSV exports and database backups" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.seed_basic_trade(conn)
      JediCliSpec.run(conn, "operation", "fees", "1", "2.50")

      lister = Jedi::TradingLife::OperationLister.new(conn)
      lister.call(option_columns: "0,16").should contain("2.50")
      csv = lister.call(option_csv: true)
      CSV.parse(csv).first[10].should eq("250")
      dump = IO::Memory.new
      Jedi::Database::Main.new(conn).dump(dump)
      operation_line = dump.to_s.lines.find(&.includes?("\x1foperation\x1fcreate\x1f")).not_nil!
      operation_line.split("\x1f").last.to_f.should eq(2.50)
    end
  end

  it "requires exactly an operation identifier and an amount" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.seed_basic_trade(conn)
      [([] of String), ["1"], ["1", "2", "extra"]].each do |arguments|
        JediCliSpec.expect_failure(conn,
          ["operation", "fees"] + arguments, "infra.positional_arguments")
      end
      Jedi::TradingLife::Operation.new(conn, 1_i64).fees.should eq(0)
    end
  end

  it "rejects invalid and overflowing operation identifiers" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.seed_basic_trade(conn)
      ["0", "-1", "T_TEST", "1.5", "9223372036854775808"].each do |id|
        JediCliSpec.expect_failure(conn,
          ["operation", "fees", "--", id, "2.50"], "operation.fees.invalid_id")
      end
      Jedi::TradingLife::Operation.new(conn, 1_i64).fees.should eq(0)
    end
  end

  it "rejects malformed, negative, non-finite and overflowing amounts" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.seed_basic_trade(conn)
      ["-0.01", "NaN", "Infinity", "1,25", "bad", "21474836.48", "9" * 400].each do |amount|
        JediCliSpec.expect_failure(conn,
          ["operation", "fees", "--", "1", amount], "operation.fees.invalid_amount")
      end
      Jedi::TradingLife::Operation.new(conn, 1_i64).fees.should eq(0)
    end
  end

  it "reports a missing operation without creating one" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.seed_basic_trade(conn)
      JediCliSpec.expect_failure(conn,
        ["operation", "fees", "999", "2.50"], "operation.query_failed")

      JediCliSpec.table_count(conn, "operation").should eq(1)
      Jedi::TradingLife::Operation.new(conn, 1_i64).fees.should eq(0)
    end
  end

  it "carries corrected historical fees into a new play simulation" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.seed_basic_trade(conn)
      JediCliSpec.run(conn, "operation", "fees", "1", "1.25")
      JediCliSpec.run(conn, "tools", "play", "--", "1", "1")

      operations = Jedi::TradingLife::Operations.new(Jedi::App.conn_memory).fetch.to_a
      operations.size.should eq(2)
      operations.first.fees.should eq(125)
      operations.last.quantity.should eq(20)
      operations.last.price.should eq(11.0)
      operations.last.fees.should eq(77)
      Jedi::TradingLife::Operation.new(conn, 1_i64).fees.should eq(125)
      JediCliSpec.table_count(conn, "operation").should eq(1)
    end
  end
end
