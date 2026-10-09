require "../support/jedi_spec_helper"

module JediOperationCreatorInvariantsSpec
  extend self

  def create_operation(
    conn,
    *,
    quantity : Int32 = 10,
    price : Float64 = 9.0,
    cfees : Float64 | NamedTuple(rate: Float64, min: Float64) = 0.0,
    type : Jedi::TradingLife::Operation::Type = Jedi::TradingLife::Operation::Type::Buy,
    mode : Jedi::TradingLife::Operation::Mode = Jedi::TradingLife::Operation::Mode::Limit,
    tickcheck : Bool = false,
  ) : Jedi::PkId
    Jedi::TradingLife::OperationCreator.new(conn).call(
      trade_ident: 1_i64,
      timestamp: Time.local(2026, 1, 1, 11, 0, 0),
      type: type,
      mode: mode,
      quantity: quantity,
      price: price,
      cfees: cfees,
      tickcheck: tickcheck
    )
  end

  def operation_count(conn) : Int64
    conn.scalar("SELECT COUNT(*) FROM operation").as(Int64)
  end
end

describe Jedi::TradingLife::OperationCreator do
  it "rejects zero and negative quantities without advancing the position" do
    [0, -1].each do |quantity|
      JediSpec.with_db do |conn|
        JediSpec.seed_basic_trade(conn)

        ex = expect_raises(Jedi::LowLevelError) do
          JediOperationCreatorInvariantsSpec.create_operation(conn,
            quantity: quantity)
        end

        ex.key.should eq("operation.create.quantity_must_be_positive")
        JediOperationCreatorInvariantsSpec.operation_count(conn).should eq(1_i64)
        JediSpec.trade(conn).last_operation.not_nil!.position.should eq(
          Jedi::TradingRules::Position.new("0:0:0"))
      end
    end
  end

  it "rejects negative and non-finite prices" do
    [-1.0, Float64::NAN, Float64::INFINITY].each do |price|
      JediSpec.with_db do |conn|
        JediSpec.seed_basic_trade(conn)

        ex = expect_raises(Jedi::LowLevelError) do
          JediOperationCreatorInvariantsSpec.create_operation(conn, price: price)
        end

        ex.key.should eq("operation.create.price_must_be_positive")
        JediOperationCreatorInvariantsSpec.operation_count(conn).should eq(1_i64)
      end
    end
  end

  it "rejects a zero-priced purchase" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      ex = expect_raises(Jedi::LowLevelError) do
        JediOperationCreatorInvariantsSpec.create_operation(conn, price: 0.0)
      end

      ex.key.should eq("operation.create.zero_price_requires_full_liquidation")
      JediOperationCreatorInvariantsSpec.operation_count(conn).should eq(1_i64)
    end
  end

  it "accepts a zero-priced sale only when it liquidates the complete stock" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      conn.exec("UPDATE operation SET position = ? WHERE id = ?",
        "0:0:+1", 1_i64)

      operation_id = JediOperationCreatorInvariantsSpec.create_operation(conn,
        type: Jedi::TradingLife::Operation::Type::Sell,
        mode: Jedi::TradingLife::Operation::Mode::Market,
        quantity: 100,
        price: 0.0,
        tickcheck: true)

      operation = Jedi::TradingLife::Operation.new(conn, operation_id)
      operation.price.should eq(0.0)
      operation.sell.should eq(0)
      operation.stock.should eq(0)
      operation.trade_invest.should eq(100_000)
      operation.position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
      operation.ksp.finite?.should be_true
      operation.kcp.finite?.should be_true
    end
  end

  it "rejects a partial zero-priced sale" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      ex = expect_raises(Jedi::LowLevelError) do
        JediOperationCreatorInvariantsSpec.create_operation(conn,
          type: Jedi::TradingLife::Operation::Type::Sell,
          mode: Jedi::TradingLife::Operation::Mode::Market,
          quantity: 99,
          price: 0.0)
      end

      ex.key.should eq("operation.create.zero_price_requires_full_liquidation")
      JediOperationCreatorInvariantsSpec.operation_count(conn).should eq(1_i64)
    end
  end

  it "rejects negative or non-finite fixed fees" do
    [-0.01, Float64::NAN, Float64::INFINITY].each do |fees|
      JediSpec.with_db do |conn|
        JediSpec.seed_basic_trade(conn)

        ex = expect_raises(Jedi::LowLevelError) do
          JediOperationCreatorInvariantsSpec.create_operation(conn, cfees: fees)
        end

        ex.key.should eq("operation.create.invalid_fees")
        JediOperationCreatorInvariantsSpec.operation_count(conn).should eq(1_i64)
      end
    end
  end

  it "rejects negative or non-finite configured fee components" do
    [
      {rate: -0.01, min: 1.0},
      {rate: 0.01, min: -1.0},
      {rate: Float64::NAN, min: 1.0},
      {rate: 0.01, min: Float64::INFINITY},
    ].each do |fees|
      JediSpec.with_db do |conn|
        JediSpec.seed_basic_trade(conn)

        ex = expect_raises(Jedi::LowLevelError) do
          JediOperationCreatorInvariantsSpec.create_operation(conn, cfees: fees)
        end

        ex.key.should eq("operation.create.invalid_fees")
        JediOperationCreatorInvariantsSpec.operation_count(conn).should eq(1_i64)
      end
    end
  end

  it "accepts zero fees" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      JediOperationCreatorInvariantsSpec.create_operation(conn,
        cfees: {rate: 0.0, min: 0.0})

      JediOperationCreatorInvariantsSpec.operation_count(conn).should eq(2_i64)
    end
  end
end
