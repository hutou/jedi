require "../support/jedi_spec_helper"

describe Jedi::TradingSystem::OrderEngine do
  it "generates only positive visible standard orders around the last price" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)

      trade = JediSpec.trade(conn)
      last_operation = trade.last_operation.not_nil!
      orders = Jedi::TradingSystem::OrderEngine.new(trade).orders

      orders.has_key?(:down).should be_true
      orders.has_key?(:up).should be_true

      orders.each_value do |order|
        order.quantity.should be > 0
        order.last_stock.should eq(last_operation.stock)
        order.operation_id.should eq(last_operation.id)
      end

      down = orders[:down]
      down.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      down.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      down.price.should be < last_operation.price

      up = orders[:up]
      up.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      up.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      up.price.should be > last_operation.price
    end
  end

  it "uses buy ticks for buy orders and sell ticks for sell orders" do
    JediSpec.with_db do |conn|
      JediSpec.insert_security(conn, tick_buy: 0.05, tick_sell: 0.10)
      JediSpec.insert_scale(conn)
      JediSpec.insert_trade(conn)
      JediSpec.insert_settings(conn, q0: 100.0, c0: 10.03)
      JediSpec.insert_operation(conn, quantity: 100, price: 10.03, stock: 100)

      trade = JediSpec.trade(conn)
      orders = Jedi::TradingSystem::OrderEngine.new(trade).orders

      down = orders[:down]
      down.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      trade.security.tick_buy.price_valid?(down.price).should be_true
      down.price.should be_close(9.00, JediSpec::EPSILON)

      up = orders[:up]
      up.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      trade.security.tick_sell.price_valid?(up.price).should be_true
      up.price.should be_close(11.10, JediSpec::EPSILON)
    end
  end

  it "builds next standard order positions from the last operation position" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn)
      JediSpec.insert_operation(
        conn,
        id: 2_i64,
        quantity: 20,
        price: 9.0,
        stock: 120,
        position: "0:0:-1",
        buy: 18_000,
        trade_invest: 118_000,
        global_invest: 118_000
      )

      orders = Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn)).orders

      orders[:up].position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      orders[:down].position.should eq(Jedi::TradingRules::Position.new("0:1:0"))
    end
  end

  it "does not expose zero-quantity orders when the trade is blocked" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, stock: 1, price: 10.0)

      engine = Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn))
      orders = engine.orders

      orders.empty?.should be_true
      engine.operating_status.should eq(Jedi::TradingSystem::OrderEngine::OperatingStatus::Blocked)
      engine.operating_warnings.empty?.should be_false
    end
  end

  it "marks one-unit current orders as degraded without suppressing them" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(conn, stock: 5, price: 10.0)

      engine = Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn))
      orders = engine.orders

      orders[:down].quantity.should eq(1)
      orders[:up].quantity.should eq(1)
      engine.operating_status.should eq(
        Jedi::TradingSystem::OrderEngine::OperatingStatus::Degraded
      )
      engine.operating_warnings.size.should eq(2)
    end
  end

  it "projects future operability upward rather than through stop-loss steps" do
    JediSpec.with_db do |conn|
      scale = JediSpec.type_two_scale(
        vr: 0.10,
        ki: 0.12,
        kb: Jedi::TradingRules::Kb::Mtp
      )
      JediSpec.seed_basic_trade(conn, scale: scale, stock: 20, price: 10.0)

      engine = Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn))
      orders = engine.orders

      orders[:down].quantity.should eq(4)
      orders[:up].quantity.should eq(4)
      engine.operating_status.should eq(
        Jedi::TradingSystem::OrderEngine::OperatingStatus::Normal
      )
      engine.operating_warnings.should be_empty
    end
  end

  it "displays a warning for a small future upward order without degrading current orders" do
    JediSpec.with_db do |conn|
      scale = JediSpec.type_two_scale(
        vr: 0.10,
        ki: 0.10,
        kb: Jedi::TradingRules::Kb::Mtp
      )
      JediSpec.seed_basic_trade(conn, scale: scale, stock: 20, price: 10.0)
      conn.exec(
        "UPDATE security SET quotation_date = ?, quotation_price = ? WHERE id = ?",
        Time.local,
        10.0,
        1_i64
      )

      engine = Jedi::TradingSystem::OrderEngine.new(JediSpec.trade(conn))
      engine.orders

      engine.operating_status.should eq(
        Jedi::TradingSystem::OrderEngine::OperatingStatus::Normal
      )
      engine.operating_warnings.should eq([
        I18n.t("trade.orders.operating_mode_warning"),
      ])

      Jedi::App.clear_messages
      Jedi::TradingSystem::TradeOrders.new(conn).list(
        option_net_stop: false,
        option_update_now: false
      )
      Jedi::App.messages.any? do |message|
        message.key == "trade.orders.operating_warning"
      end.should be_true
    end
  end

  it "clears a persisted stop when money management is disabled" do
    JediSpec.with_db do |conn|
      JediSpec.seed_basic_trade(
        conn,
        money: nil,
        stop: "1:CL:100:8.0:-300.0"
      )

      trade = JediSpec.trade(conn)
      trade.stop.should_not be_nil

      orders = Jedi::TradingSystem::OrderEngine.new(trade).orders

      orders.has_key?(:down).should be_true
      orders.has_key?(:up).should be_true
      orders.has_key?(:loss).should be_false
      trade.stop.should be_nil
    end
  end
end
