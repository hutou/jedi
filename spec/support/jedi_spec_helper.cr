require "spec"
require "../../src/jedi"

module JediSpec
  extend self

  EPSILON = 1e-6

  def configure_app : Nil
    Jedi::App.config = YAML.parse(Jedi::App::YAML_CONFIG)
    Jedi::App.env = Jedi::App::Env::Test
    Jedi::App.paths = Jedi::App::Paths.new(
      "/tmp/jedi-spec",
      "/tmp/jedi-spec",
      "/tmp/jedi-spec",
      "/tmp/jedi-spec",
      "/tmp/jedi-spec/jedi_test.conf",
      "/tmp/jedi-spec/jedi_test.log",
      "/tmp/jedi-spec/jedi_test.db"
    )
    Jedi::App.lang = "en"
    Jedi::App.noconfirm = true
    Jedi::App.simulation = Jedi::SimulationMode::FromOperation
    Jedi::App.clear_messages
  end

  def with_db(&)
    configure_app

    path = "/tmp/jedi_spec_#{Time.utc.to_unix_ns}_#{rand(1_000_000)}.db"
    conn = Jedi::App.db_main_connect(path)

    begin
      create_schema(conn)
      yield conn
    ensure
      conn.close
      File.delete(path) if File.exists?(path)
      Jedi::App.clear_messages
    end
  end

  def create_schema(conn) : Nil
    db = Jedi::Database::Main.new(conn)
    db.create_table_security
    db.create_table_trade
    db.create_table_scale
    db.create_table_settings
    db.create_table_operation
    db.create_table_note
  end

  def type_two_scale(
    *,
    vr : Float64 = 0.10,
    ki : Float64 = 0.0,
    kb : Jedi::TradingRules::Kb = Jedi::TradingRules::Kb::Pwr,
  ) : Jedi::TradingRules::Scale::Operational
    ks = {
      -1 => 1.20,
       0 => 1.00,
       1 => 0.80,
    }

    Jedi::TradingRules::Scale::Operational.new(
      Jedi::TradingRules::Scale::Operational::Type::Two,
      "vr:10.0%, ks:0.8,1.2, ki:0.0%, kb:0",
      "vr:10.0%, ks:0.8,1.2, ki:0.0%, kb:0",
      ks,
      2,
      -2,
      ki,
      kb,
      nil,
      vr
    )
  end

  def type_one_scale : Jedi::TradingRules::Scale::Operational
    ks = {
      -1 => 1.20,
       0 => 1.00,
       1 => 0.80,
    }
    kc = {
      -2 => 0.80,
      -1 => 0.90,
       0 => 1.00,
       0 => 1.00,
       1 => 1.10,
       2 => 1.20,
    }

    Jedi::TradingRules::Scale::Operational.new(
      Jedi::TradingRules::Scale::Operational::Type::One,
      "kc:1.2,1.1,0.9,0.8, ks:0.8,1.2, ki:10.0%, kb:0",
      "kc:1.2,1.1,0.9,0.8, ks:0.8,1.2, ki:10.0%, kb:0",
      ks,
      2,
      -2,
      0.10,
      Jedi::TradingRules::Kb::Pwr,
      kc
    )
  end

  def insert_scale(
    conn,
    *,
    id : Int64 = 1_i64,
    name : String = "S_TEST",
    comment : String = "Spec scale",
    scale : Jedi::TradingRules::Scale::Operational = type_two_scale,
  ) : Int64
    conn.exec(
      "INSERT INTO scale (id, name, comment, operational) VALUES (?, ?, ?, ?)",
      id,
      name,
      comment,
      scale.to_json
    )
    id
  end

  def insert_security(
    conn,
    *,
    id : Int64 = 1_i64,
    isin : String = "FR4487601001",
    name : String = "SPEC SECURITY",
    ticker : String = "SPEC",
    tick_buy : Float64 = 0.01,
    tick_sell : Float64 = 0.01,
    tax : Float64 = 0.0,
    quotation_date : Time? = nil,
    quotation_website : String? = nil,
    quotation_mode : String? = nil,
    quotation_price : Float64? = nil,
    quotation_variation : Float64? = nil,
  ) : Int64
    conn.exec(
      "INSERT INTO security
       (id, isin, name, ticker, tick_buy, tick_sell, tax,
        quotation_date, quotation_website, quotation_mode, quotation_price, quotation_variation)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      id,
      isin,
      name,
      ticker,
      tick_buy,
      tick_sell,
      tax,
      quotation_date,
      quotation_website,
      quotation_mode,
      quotation_price,
      quotation_variation
    )
    id
  end

  def insert_trade(
    conn,
    *,
    id : Int64 = 1_i64,
    name : String = "T_TEST",
    money : String? = nil,
    stop : String? = nil,
    security_id : Int64 = 1_i64,
  ) : Int64
    conn.exec(
      "INSERT INTO trade (id, name, money, stop, security_id) VALUES (?, ?, ?, ?, ?)",
      id,
      name,
      money,
      stop,
      security_id
    )
    id
  end

  def insert_settings(
    conn,
    *,
    id : Int64 = 1_i64,
    trade_id : Int64 = 1_i64,
    scale_id : Int64 = 1_i64,
    q0 : Float64 = 100.0,
    c0 : Float64 = 10.0,
    position : String = "0:0:0",
    timestamp : Time = Time.local(2026, 1, 1, 9, 0, 0),
    reinit : String = "",
  ) : Int64
    conn.exec(
      "INSERT INTO settings
       (id, rank, timestamp, split, sync, reinit, q0, c0, position, kspc, kcpc, trade_id, scale_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      id,
      1,
      timestamp,
      "",
      "",
      reinit,
      q0,
      c0,
      position,
      1.0,
      1.0,
      trade_id,
      scale_id
    )
    id
  end

  def insert_operation(
    conn,
    *,
    id : Int64 = 1_i64,
    settings_id : Int64 = 1_i64,
    type : Jedi::TradingLife::Operation::Type = Jedi::TradingLife::Operation::Type::Buy,
    mode : Jedi::TradingLife::Operation::Mode = Jedi::TradingLife::Operation::Mode::Market,
    quantity : Int32 = 100,
    price : Float64 = 10.0,
    stock : Int32 = 100,
    position : String = "0:0:0",
    ksp : Float64 = 1.0,
    kcp : Float64 = 1.0,
    timestamp : Time = Time.local(2026, 1, 1, 10, 0, 0),
    buy : Int32? = nil,
    sell : Int32 = 0,
    trade_invest : Int32? = nil,
    global_invest : Int32? = nil,
  ) : Int64
    amount = (quantity * price * 100).round.to_i
    effective_buy = buy.nil? ? (type.buy? ? amount : 0) : buy.not_nil!
    effective_trade_invest = trade_invest.nil? ? effective_buy - sell : trade_invest.not_nil!
    effective_global_invest = global_invest.nil? ? effective_trade_invest : global_invest.not_nil!

    conn.exec(
      "INSERT INTO operation
       (id, timestamp, type, mode, quantity, price, buy, sell, trade_invest,
        global_invest, fees, stock, position, ksp, kcp, settings_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
      id,
      timestamp,
      type.to_s,
      mode.to_s,
      quantity,
      price,
      effective_buy,
      sell,
      effective_trade_invest,
      effective_global_invest,
      0,
      stock,
      position,
      ksp,
      kcp,
      settings_id
    )
    id
  end

  def seed_basic_trade(
    conn,
    *,
    money : String? = nil,
    stop : String? = nil,
    scale : Jedi::TradingRules::Scale::Operational = type_two_scale,
    stock : Int32 = 100,
    price : Float64 = 10.0,
  ) : Int64
    insert_security(conn)
    insert_scale(conn, scale: scale)
    insert_trade(conn, money: money, stop: stop)
    insert_settings(conn, q0: stock.to_f, c0: price)
    insert_operation(conn, quantity: stock, price: price, stock: stock)
    1_i64
  end

  def trade(conn, id : Int64 = 1_i64) : Jedi::TradingSystem::Trade
    Jedi::TradingSystem::Trade.new(conn, id)
  end
end

Spec.before_each do
  JediSpec.configure_app
end
