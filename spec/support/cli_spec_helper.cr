require "./jedi_spec_helper"

Jedi.init_i18n("en")

module JediCliSpec
  extend self

  def with_cli_db(&)
    JediSpec.with_db do |conn|
      memory_path = "/tmp/jedi_cli_memory_#{Time.utc.to_unix_ns}_#{rand(1_000_000)}.db"
      memory_conn = DB.connect("sqlite3://#{memory_path}")

      begin
        Jedi::App.conn_main = conn
        Jedi::App.conn_memory = memory_conn
        yield conn
      ensure
        memory_conn.close
        File.delete(memory_path) if File.exists?(memory_path)
        Jedi::App.clear_messages
      end
    end
  end

  def run(conn : DB::Connection, args : Array(String)) : String
    saved_argv = ARGV.dup
    output = IO::Memory.new
    begin
      ARGV.clear
      args.each { |arg| ARGV << arg }
      Jedi::App.conn_main = conn
      Jedi::App.clear_messages
      Jedi::Command.new(conn, output: output).run
    ensure
      ARGV.clear
      saved_argv.each { |arg| ARGV << arg }
      Jedi::App.clear_messages
    end
    output.to_s
  end

  def run(conn : DB::Connection, *args : String) : String
    run(conn, args.to_a)
  end

  def expect_failure(conn : DB::Connection, args : Array(String), key : String? = nil) : Jedi::AppException
    ex = expect_raises(Jedi::AppException) do
      run(conn, args)
    end

    ex.key.should eq(key) unless key.nil?
    ex
  end

  def expect_failure(conn : DB::Connection, *args : String, key : String? = nil) : Jedi::AppException
    expect_failure(conn, args.to_a, key)
  end

  def table_count(conn : DB::Connection, table : String) : Int64
    conn.scalar("SELECT COUNT(*) FROM #{table}").as(Int64)
  end

  def seed_cli_trade(
    conn : DB::Connection,
    *,
    money : String? = nil,
    scale : Jedi::TradingRules::Scale::Operational = JediSpec.type_two_scale,
  ) : Nil
    JediSpec.insert_security(conn)
    JediSpec.insert_scale(conn, scale: scale)
    JediSpec.insert_trade(conn, money: money)
    JediSpec.insert_settings(conn)
    JediSpec.insert_operation(conn)
  end
end
