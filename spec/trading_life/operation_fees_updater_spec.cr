require "../support/jedi_spec_helper"

module JediOperationFeesSpec
  extend self

  def close_trade(conn, *, trade_id : Int64 = 1_i64,
                  timestamp : Time = Time.local(2026, 1, 2, 10, 0, 0),
                  price : Float64 = 12.0, fees : Float64 = 4.20) : Int64
    Jedi::TradingLife::OperationCreator.new(conn).call(
      trade_ident: trade_id,
      timestamp: timestamp,
      type: Jedi::TradingLife::Operation::Type::Sell,
      mode: Jedi::TradingLife::Operation::Mode::Market,
      quantity: 100,
      price: price,
      cfees: fees,
      tickcheck: false)
  end

  def order_signature(trade)
    Jedi::TradingSystem::OrderEngine.new(trade).orders.transform_values do |order|
      {order.type, order.mode, order.position, order.quantity, order.price,
       order.spe, order.cpe, order.last_stock, order.operation_id,
       order.original_quantity, order.kind}
    end
  end
end

describe Jedi::TradingLife::OperationFeesUpdater do
  it "accepts the maximum fee amount representable in stored cents" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      Jedi::TradingLife::OperationFeesUpdater.new(conn).call(
        operation_id: 1_i64, amount: 21_474_836.47).should eq(1)

      Jedi::TradingLife::Operation.new(conn, 1_i64).fees.should eq(Int32::MAX)
    end
  end

  it "rejects negative, non-finite and overflowing amounts before any write" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      before = Jedi::TradingLife::Operation.new(conn, 1_i64).record
      [-0.01, Float64::NAN, Float64::INFINITY, -Float64::INFINITY,
       21_474_836.48, Float64::MAX].each do |amount|
        ex = expect_raises(Jedi::LowLevelError) do
          Jedi::TradingLife::OperationFeesUpdater.new(conn).call(
            operation_id: 1_i64, amount: amount)
        end
        ex.key.should eq("operation.fees.invalid_amount")
        ex.kind.should eq(Jedi::LowLevelError::Kind::UserInput)
        Jedi::TradingLife::Operation.new(conn, 1_i64).record.should eq(before)
      end
    end
  end

  it "rejects non-positive operation identifiers before any write" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      [0_i64, -1_i64].each do |id|
        ex = expect_raises(Jedi::LowLevelError) do
          Jedi::TradingLife::OperationFeesUpdater.new(conn).call(
            operation_id: id, amount: 2.50)
        end
        ex.key.should eq("operation.fees.invalid_id")
      end
      Jedi::TradingLife::Operation.new(conn, 1_i64).fees.should eq(0)
    end
  end

  it "does not insert a record when the operation is missing" do
    JediSpec.with_db do |conn|
      ex = expect_raises(Jedi::LowLevelError) do
        Jedi::TradingLife::OperationFeesUpdater.new(conn).call(
          operation_id: 1_i64, amount: 2.50)
      end
      ex.key.should eq("operation.query_failed")
      conn.scalar("SELECT COUNT(*) FROM operation").should eq(0_i64)
    end
  end

  it "recalculates total fees and net results while keeping gross metrics unchanged" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      JediOperationFeesSpec.close_trade(conn)
      JediSpec.insert_trade(conn, id: 2_i64, name: "T_FLAT")
      JediSpec.insert_settings(conn, id: 2_i64, trade_id: 2_i64,
        timestamp: Time.local(2026, 1, 3, 9, 0, 0))
      JediSpec.insert_operation(conn, id: 3_i64, settings_id: 2_i64,
        timestamp: Time.local(2026, 1, 3, 10, 0, 0))
      JediOperationFeesSpec.close_trade(conn, trade_id: 2_i64,
        timestamp: Time.local(2026, 1, 4, 10, 0, 0), price: 10.0, fees: 0.0)
      metrics_before = Jedi::TradingSystem::TradeMetrics.new(JediSpec.trade(conn)).calculate.not_nil!
      results_before = Jedi::TradingSystem::TradeResults.new(conn).list(option_update_now: false)
      results_before.should contain("195.80")

      Jedi::TradingLife::OperationFeesUpdater.new(conn).call(
        operation_id: 1_i64, amount: 1.25)

      metrics_after = Jedi::TradingSystem::TradeMetrics.new(JediSpec.trade(conn)).calculate.not_nil!
      metrics_after.should eq(metrics_before.copy_with(fees: 545))
      results_after = Jedi::TradingSystem::TradeResults.new(conn).list(option_update_now: false)
      results_after.should contain("194.55")
      results_after.should contain("5.45")
      results_after.should_not contain("195.80")
      {results_before, results_after}.each { |output| output.should contain("200.00") }
    end
  end

  it "keeps calculated orders identical with and without money management" do
    [nil, "r:1.5%,o:2,n:2"].each do |money|
      JediSpec.with_db do |conn|
        JediSpec.insert_security(conn, quotation_date: Time.local, quotation_price: 10.0)
        JediSpec.insert_scale(conn)
        JediSpec.insert_trade(conn, money: money)
        JediSpec.insert_settings(conn)
        JediSpec.insert_operation(conn)
        orders_before = JediOperationFeesSpec.order_signature(JediSpec.trade(conn))
        orders_before.should_not be_empty
        stop_before = JediSpec.trade(conn).stop

        Jedi::TradingLife::OperationFeesUpdater.new(conn).call(
          operation_id: 1_i64, amount: 25.0)

        JediOperationFeesSpec.order_signature(JediSpec.trade(conn)).should eq(orders_before)
        JediSpec.trade(conn).stop.should eq(stop_before)
      end
    end
  end
end
