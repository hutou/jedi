require "../support/jedi_spec_helper"

describe "Trade context persistence queries" do
  it "loads settings and operations only for the requested trade" do
    JediSpec.with_db do |conn|
      JediSpec.insert_security(conn)
      JediSpec.insert_scale(conn)

      JediSpec.insert_trade(conn, id: 1_i64, name: "T_ONE")
      JediSpec.insert_trade(conn, id: 2_i64, name: "T_TWO")

      JediSpec.insert_settings(
        conn,
        id: 1_i64,
        trade_id: 1_i64,
        timestamp: Time.local(2026, 1, 1, 9, 0, 0)
      )
      JediSpec.insert_settings(
        conn,
        id: 2_i64,
        trade_id: 2_i64,
        timestamp: Time.local(2026, 1, 1, 9, 30, 0)
      )

      JediSpec.insert_operation(
        conn,
        id: 1_i64,
        settings_id: 1_i64,
        timestamp: Time.local(2026, 1, 1, 10, 0, 0),
        stock: 100,
        position: "0:0:0"
      )
      JediSpec.insert_operation(
        conn,
        id: 2_i64,
        settings_id: 2_i64,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0),
        stock: 200,
        position: "0:0:0"
      )
      JediSpec.insert_operation(
        conn,
        id: 3_i64,
        settings_id: 1_i64,
        type: Jedi::TradingLife::Operation::Type::Sell,
        mode: Jedi::TradingLife::Operation::Mode::Limit,
        quantity: 20,
        price: 11.0,
        stock: 80,
        position: "0:0:+1",
        sell: 22_000,
        trade_invest: 78_000,
        global_invest: 78_000,
        timestamp: Time.local(2026, 1, 1, 12, 0, 0)
      )

      trade_one = Jedi::TradingSystem::Trade.new(conn, 1_i64)
      trade_two = Jedi::TradingSystem::Trade.new(conn, 2_i64)

      trade_one.settings_chain.size.should eq(1)
      trade_one.settings_chain.first.id.should eq(1_i64)
      trade_one.operations.size.should eq(2)
      trade_one.operations.map(&.id).should eq([1_i64, 3_i64])
      trade_one.last_operation.not_nil!.id.should eq(3_i64)
      trade_one.last_operation.not_nil!.position.should eq(
        Jedi::TradingRules::Position.new("0:0:+1")
      )

      trade_two.settings_chain.size.should eq(1)
      trade_two.settings_chain.first.id.should eq(2_i64)
      trade_two.operations.size.should eq(1)
      trade_two.operations.map(&.id).should eq([2_i64])
      trade_two.last_operation.not_nil!.id.should eq(2_i64)
    end
  end

  it "orders a trade settings chain and operations by timestamp then id" do
    JediSpec.with_db do |conn|
      JediSpec.insert_security(conn)
      JediSpec.insert_scale(conn)
      JediSpec.insert_trade(conn)

      JediSpec.insert_settings(
        conn,
        id: 2_i64,
        timestamp: Time.local(2026, 1, 1, 12, 0, 0)
      )
      JediSpec.insert_settings(
        conn,
        id: 1_i64,
        timestamp: Time.local(2026, 1, 1, 9, 0, 0)
      )

      JediSpec.insert_operation(
        conn,
        id: 3_i64,
        settings_id: 2_i64,
        timestamp: Time.local(2026, 1, 1, 12, 30, 0)
      )
      JediSpec.insert_operation(
        conn,
        id: 1_i64,
        settings_id: 1_i64,
        timestamp: Time.local(2026, 1, 1, 10, 0, 0)
      )
      JediSpec.insert_operation(
        conn,
        id: 2_i64,
        settings_id: 1_i64,
        timestamp: Time.local(2026, 1, 1, 11, 0, 0)
      )

      trade = Jedi::TradingSystem::Trade.new(conn, 1_i64)

      trade.settings_chain.map(&.id).should eq([1_i64, 2_i64])
      trade.operations.map(&.id).should eq([1_i64, 2_i64, 3_i64])
      trade.last_settings.not_nil!.id.should eq(2_i64)
      trade.last_operation.not_nil!.id.should eq(3_i64)
    end
  end
end
