require "../support/play_spec_helper"

module JediTradingSystemSpec
  PARAMS = "scale=S_TEST,q0=100,c0=10,tick=0.01"

  extend self

  def reload_trade(
    play : Jedi::Tools::Play,
    trade : Jedi::TradingSystem::Trade,
  ) : Jedi::TradingSystem::Trade
    Jedi::TradingSystem::Trade.new(play.conn_memory, trade.id)
  end

  def add_operation(
    play : Jedi::Tools::Play,
    trade : Jedi::TradingSystem::Trade,
    timestamp : Time,
    type : Jedi::TradingLife::Operation::Type,
    quantity : Int32,
    price : Float64,
  ) : Nil
    Jedi::TradingLife::OperationCreator.new(play.conn_memory).call(
      trade_ident: trade.id,
      timestamp: timestamp,
      type: type,
      mode: Jedi::TradingLife::Operation::Mode::Market,
      quantity: quantity,
      price: price,
      cfees: Jedi::App.fees,
      tickcheck: false
    )

    nil
  end

  def close_trade(
    play : Jedi::Tools::Play,
    trade : Jedi::TradingSystem::Trade,
    timestamp : Time,
    price : Float64,
  ) : Jedi::TradingSystem::Trade
    current = reload_trade(play, trade)
    stock = current.operations.last.stock
    raise "cannot close a trade without stock" if stock <= 0

    add_operation(
      play,
      current,
      timestamp,
      Jedi::TradingLife::Operation::Type::Sell,
      stock,
      price
    )
    reload_trade(play, current)
  end

  def create_empty_trade(
    play : Jedi::Tools::Play,
    *,
    name : String,
  ) : Jedi::TradingSystem::Trade
    trade_id = Jedi::TradingSystem::TradeCreator.new(play.conn_memory).call(
      name: name,
      money: Jedi::TradingSystem::Money.parse(""),
      stop: Jedi::TradingSystem::TradeStop.parse(""),
      security_ident: play.mem_trade.security_id
    )

    Jedi::TradingSystem::Trade.new(play.conn_memory, trade_id)
  end

  def create_trade(
    play : Jedi::Tools::Play,
    *,
    name : String,
    timestamp : Time,
    quantity : Int32,
    price : Float64,
  ) : Jedi::TradingSystem::Trade
    trade = create_empty_trade(
      play,
      name: name
    )

    scale_id = play.mem_trade.settings_chain.last.scale.id
    Jedi::TradingSystem::SettingsCreator.new(play.conn_memory).call(
      trade_ident: trade.id,
      scale_ident: scale_id,
      timestamp: timestamp
    )

    add_operation(
      play,
      trade,
      timestamp,
      Jedi::TradingLife::Operation::Type::Buy,
      quantity,
      price
    )

    reload_trade(play, trade)
  end

  def set_operation_schedule(
    conn : DB::Connection,
    base : Time,
    offsets : Array(Int32),
  ) : Nil
    operations = Jedi::TradingLife::Operations.new(conn).fetch
    unless operations.size == offsets.size
      raise "expected #{offsets.size} operations, got #{operations.size}"
    end

    operations.each_with_index do |operation, index|
      conn.exec(
        "UPDATE operation SET timestamp = ? WHERE id = ?",
        base + offsets[index].days,
        operation.id
      )
    end
  end

  def global_maximum_investment(
    # operations : Array(Jedi::TradingLife::Operation),
    operations : Jedi::TradingLife::Operations,
  ) : Int32
    current = 0
    maximum = 0

    operations.each do |operation|
      current += operation.buy - operation.sell
      maximum = [maximum, current].max
    end

    maximum
  end

  def annualized_return(
    gains : Int32,
    investment : Int32,
    duration : Int32,
  ) : Float64
    return 0.0 if investment <= 0

    positive_duration = duration > 0 ? duration : 1
    (((gains + investment).to_f / investment) **
      (365.0 / positive_duration) - 1) * 100
  end
end
