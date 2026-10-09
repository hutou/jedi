require "../support/jedi_spec_helper"

module JediTickRoundingSpec
  extend self

  def seed_trade_with_ticks(
    conn,
    *,
    tick_buy : Float64,
    tick_sell : Float64,
    money : String? = nil,
    price : Float64 = 10.03,
    stock : Int32 = 100,
  ) : Nil
    JediSpec.insert_security(conn, tick_buy: tick_buy, tick_sell: tick_sell)
    JediSpec.insert_scale(conn)
    JediSpec.insert_trade(conn, money: money)
    JediSpec.insert_settings(conn, q0: stock.to_f, c0: price)
    JediSpec.insert_operation(conn, quantity: stock, price: price, stock: stock)
  end
end

describe Jedi::TradingSystem::OrderEngine do
  it "rounds buy limit orders down with tick_buy and sell limit orders up with tick_sell" do
    JediSpec.with_db do |conn|
      JediTickRoundingSpec.seed_trade_with_ticks(
        conn,
        tick_buy: 0.05,
        tick_sell: 0.10,
        price: 10.03
      )

      trade = JediSpec.trade(conn)
      orders = Jedi::TradingSystem::OrderEngine.new(trade).orders

      down = orders[:down]
      down.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      down.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      down.price.should be <= down.cpe
      trade.security.tick_buy.price_valid?(down.price).should be_true

      up = orders[:up]
      up.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      up.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      up.price.should be >= up.cpe
      trade.security.tick_sell.price_valid?(up.price).should be_true
    end
  end

  it "uses the buy tick only for buy orders and the sell tick only for sell orders" do
    JediSpec.with_db do |conn|
      JediTickRoundingSpec.seed_trade_with_ticks(
        conn,
        tick_buy: 0.05,
        tick_sell: 0.20,
        price: 10.03
      )

      trade = JediSpec.trade(conn)
      orders = Jedi::TradingSystem::OrderEngine.new(trade).orders

      down = orders[:down]
      trade.security.tick_buy.price_valid?(down.price).should be_true
      # 9.0 is valid for tick 0.20 too, so also verify the expected conservative
      # buy-side rounded value produced from the raw Jedi price.
      down.price.should be_close(9.00, JediSpec::EPSILON)

      up = orders[:up]
      trade.security.tick_sell.price_valid?(up.price).should be_true
      up.price.should be_close(11.20, JediSpec::EPSILON)
    end
  end

  it "rounds loss stoploss orders down with tick_sell" do
    JediSpec.with_db do |conn|
      JediTickRoundingSpec.seed_trade_with_ticks(
        conn,
        tick_buy: 0.01,
        tick_sell: 0.05,
        money: "r:1.5%,o:2,n:2",
        price: 10.0
      )

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

      trade = JediSpec.trade(conn)
      orders = Jedi::TradingSystem::OrderEngine.new(trade).orders
      loss = orders[:loss]

      loss.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      loss.mode.should eq(Jedi::TradingLife::Operation::Mode::StopLoss)
      loss.kind.should eq(Jedi::TradingSystem::TradeStop::Kind::CL)
      trade.security.tick_sell.price_valid?(loss.price).should be_true
      loss.price.should be_close(7.30, JediSpec::EPSILON)

      persisted_stop = trade.stop.not_nil!
      persisted_stop.price.should be_close(loss.price, JediSpec::EPSILON)
    end
  end
end
