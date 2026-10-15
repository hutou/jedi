require "../support/play_spec_helper"
require "../support/cli_spec_helper"

module JediTradeClosureSpec
  extend self

  MONEY = "r:1.5%,o:2,n:2"
  STOP  = "1:cl:100:9.8:-20"

  def sell(conn, *, quantity : Int32 = 100, price : Float64 = 11.0,
           mode : Jedi::TradingLife::Operation::Mode = Jedi::TradingLife::Operation::Mode::Market)
    Jedi::TradingLife::OperationCreator.new(conn).call(
      trade_ident: 1_i64,
      timestamp: Time.local(2026, 1, 1, 11, 0, 0),
      type: Jedi::TradingLife::Operation::Type::Sell,
      mode: mode,
      quantity: quantity,
      price: price,
      cfees: 2.0,
      tickcheck: false)
  end

  def controls(conn, trade_id : Int64 = 1_i64)
    conn.query_one("SELECT money, stop FROM trade WHERE id = ?", trade_id,
      as: {String?, String?})
  end

  def expect_cleared(conn, trade_id : Int64 = 1_i64)
    # Assert SQL NULL as well as the parsed values exposed by Trade.
    controls(conn, trade_id).should eq({nil, nil})
    trade = JediSpec.trade(conn, trade_id)
    trade.money.should be_nil
    trade.stop.should be_nil
  end
end

describe "Trade closure" do
  it "clears money and stop for a full stoploss sale" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn,
        money: JediTradeClosureSpec::MONEY, stop: JediTradeClosureSpec::STOP)

      id = JediTradeClosureSpec.sell(conn,
        mode: Jedi::TradingLife::Operation::Mode::StopLoss)

      operation = Jedi::TradingLife::Operation.new(conn, id)
      operation.stock.should eq(0)
      operation.fees.should eq(200)
      operation.sell.should eq(110_000)
      JediTradeClosureSpec.expect_cleared(conn)
      conn.scalar("SELECT COUNT(*) FROM settings").should eq(1_i64)
      conn.scalar("SELECT COUNT(*) FROM operation").should eq(2_i64)
    end
  end

  it "clears money and stop for any full manual sale" do
    [Jedi::TradingLife::Operation::Mode::Market,
     Jedi::TradingLife::Operation::Mode::Limit,
     Jedi::TradingLife::Operation::Mode::Stop].each do |mode|
      JediSpec.with_db do |conn|
        JediSpec.seed_basic_trade(conn,
          money: JediTradeClosureSpec::MONEY, stop: JediTradeClosureSpec::STOP)

        JediTradeClosureSpec.sell(conn, mode: mode)

        JediSpec.trade(conn).last_operation.not_nil!.stock.should eq(0)
        JediTradeClosureSpec.expect_cleared(conn)
      end
    end
  end

  it "also clears the controls for a total loss at a zero price" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn,
        money: JediTradeClosureSpec::MONEY, stop: JediTradeClosureSpec::STOP)

      JediTradeClosureSpec.sell(conn, price: 0.0)

      JediSpec.trade(conn).last_operation.not_nil!.stock.should eq(0)
      JediTradeClosureSpec.expect_cleared(conn)
    end
  end

  it "keeps money management active after a partial sale" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn,
        money: JediTradeClosureSpec::MONEY, stop: JediTradeClosureSpec::STOP,
        stock: 1000)

      JediTradeClosureSpec.sell(conn, quantity: 20)

      trade = JediSpec.trade(conn)
      trade.last_operation.not_nil!.stock.should eq(980)
      trade.money.should eq(Jedi::TradingSystem::Money.parse(JediTradeClosureSpec::MONEY))
      trade.stop.should_not be_nil
    end
  end

  it "does not clear the controls of another trade" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn,
        money: JediTradeClosureSpec::MONEY, stop: JediTradeClosureSpec::STOP)
      JediSpec.insert_trade(conn, id: 2_i64, name: "T_OTHER",
        money: JediTradeClosureSpec::MONEY, stop: JediTradeClosureSpec::STOP)
      JediSpec.insert_settings(conn, id: 2_i64, trade_id: 2_i64,
        timestamp: Time.local(2026, 1, 1, 9, 30, 0))
      JediSpec.insert_operation(conn, id: 2_i64, settings_id: 2_i64,
        timestamp: Time.local(2026, 1, 1, 10, 30, 0))
      before = JediTradeClosureSpec.controls(conn, 2_i64)

      JediTradeClosureSpec.sell(conn)

      JediTradeClosureSpec.expect_cleared(conn)
      JediTradeClosureSpec.controls(conn, 2_i64).should eq(before)
      JediSpec.trade(conn, 2_i64).last_operation.not_nil!.stock.should eq(100)
    end
  end

  it "uses SQL NULL even when money management was never activated" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, money: "", stop: "")

      JediTradeClosureSpec.sell(conn)

      JediTradeClosureSpec.expect_cleared(conn)
    end
  end

  it "rolls the sale back if the trade controls cannot be cleared" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, money: JediTradeClosureSpec::MONEY)
      conn.exec(<<-SQL)
        CREATE TRIGGER reject_trade_closure
        BEFORE UPDATE OF money ON trade
        WHEN NEW.money IS NULL
        BEGIN
          SELECT RAISE(ABORT, 'forced closure update failure');
        END;
        SQL

      expect_raises(SQLite3::Exception) { JediTradeClosureSpec.sell(conn) }
      conn.exec("DROP TRIGGER reject_trade_closure")
      # Reset the cached statement after the expected SQLite trigger error.
      conn.exec("UPDATE trade SET money = NULL, stop = NULL WHERE id = ?", 0_i64)

      conn.scalar("SELECT COUNT(*) FROM operation").should eq(1_i64)
      JediSpec.trade(conn).last_operation.not_nil!.stock.should eq(100)
      JediSpec.trade(conn).money.should_not be_nil
    end
  end

  it "rolls back the controls together with a surrounding transaction" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn,
        money: JediTradeClosureSpec::MONEY, stop: JediTradeClosureSpec::STOP)
      before = JediTradeClosureSpec.controls(conn)

      conn.transaction do |tx|
        Jedi::TradingLife::OperationCreator.new(tx).call(
          trade_ident: 1_i64,
          timestamp: Time.local(2026, 1, 1, 11, 0, 0),
          type: Jedi::TradingLife::Operation::Type::Sell,
          mode: Jedi::TradingLife::Operation::Mode::Market,
          quantity: 100,
          price: 11.0,
          cfees: 0.0,
          tickcheck: false)
        JediTradeClosureSpec.expect_cleared(tx.connection)
        tx.rollback
      end

      JediTradeClosureSpec.controls(conn).should eq(before)
      conn.scalar("SELECT COUNT(*) FROM operation").should eq(1_i64)
    end
  end

  it "leaves a reopened trade ready for an explicit money configuration" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, money: JediTradeClosureSpec::MONEY)
      JediTradeClosureSpec.sell(conn)

      Jedi::TradingLife::OperationDeleter.new(conn).delete.should eq(1)

      JediSpec.trade(conn).last_operation.not_nil!.stock.should eq(100)
      JediTradeClosureSpec.expect_cleared(conn)
      Jedi::TradingSystem::TradeUpdater.new(JediSpec.trade(conn)).call(
        money: JediTradeClosureSpec::MONEY)
      JediSpec.trade(conn).money.should_not be_nil
    end
  end

  it "refreshes the simulated trade after a stoploss closes it" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01,money=r:1.5%,o:2,n:2,loss=active",
      ["-1", "-1"]
    ) do |play|
      play.context.current_operation.stock.should eq(0)
      play.context.current_operation.mode.should eq(Jedi::TradingLife::Operation::Mode::StopLoss)
      JediTradeClosureSpec.expect_cleared(play.conn_memory, play.mem_trade.id)
      play.mem_trade.money.should be_nil
      play.mem_trade.stop.should be_nil
    end
  end

  it "clears a manual simulated close without changing the source database" do
    JediSpec.with_db do |main|
      JediSpec.seed_basic_trade(main,
        money: JediTradeClosureSpec::MONEY, stop: JediTradeClosureSpec::STOP)
      before = JediTradeClosureSpec.controls(main)

      JediSpec.with_db do |memory|
        play = Jedi::Tools::Play.new(main, memory, 1_i64,
          ["money=#{JediTradeClosureSpec::MONEY}", "-100@11"])

        play.context.current_operation.stock.should eq(0)
        JediTradeClosureSpec.expect_cleared(memory, play.mem_trade.id)
        play.mem_trade.money.should be_nil
        play.mem_trade.stop.should be_nil
      end

      JediTradeClosureSpec.controls(main).should eq(before)
      main.scalar("SELECT COUNT(*) FROM operation").should eq(1_i64)
    end
  end

  it "clears both fields when recording a closing sale through the CLI" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.seed_basic_trade(conn,
        money: JediTradeClosureSpec::MONEY, stop: JediTradeClosureSpec::STOP)

      JediCliSpec.run(conn, "operation", "create", "T_TEST",
        "--date=2026-01-01", "--time=11:00:00", "--type=Sell",
        "--mode=Market", "--quantity=100", "--price=11.0")

      JediSpec.trade(conn).last_operation.not_nil!.stock.should eq(0)
      JediTradeClosureSpec.expect_cleared(conn)
    end
  end

  it "allows clearing the controls of an older closed trade without changing history" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.seed_basic_trade(conn,
        money: JediTradeClosureSpec::MONEY, stop: JediTradeClosureSpec::STOP)
      JediSpec.insert_operation(conn, id: 2_i64,
        type: Jedi::TradingLife::Operation::Type::Sell,
        quantity: 100, price: 11.0, stock: 0, sell: 110_000,
        trade_invest: -10_000, global_invest: -10_000,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0))
      before = JediSpec.trade(conn).operations.to_a.map(&.record)

      JediCliSpec.run(conn, "trade", "update", "T_TEST", "--money=", "--reset-stop")

      JediTradeClosureSpec.expect_cleared(conn)
      JediSpec.trade(conn).operations.to_a.map(&.record).should eq(before)
    end
  end
end
