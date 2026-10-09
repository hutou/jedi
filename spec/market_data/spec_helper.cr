require "../spec_helper"
require "file_utils"

module JediMarketSpec
  extend self

  @@sequence = 0

  struct Workspace
    getter root : String

    def initialize(@root : String)
    end

    def path(name : String) : String
      File.join(root, name)
    end

    def write(name : String, content : String) : String
      filename = path(name)
      Dir.mkdir_p(File.dirname(filename))
      File.write(filename, content)
      filename
    end
  end

  def with_workspace(& : Workspace ->) : Nil
    @@sequence += 1
    root = File.join(
      Dir.current,
      "tmp/spec/market_data",
      "#{Process.pid}-#{@@sequence}"
    )

    FileUtils.rm_rf(root)
    Dir.mkdir_p(root)

    previous_env = Jedi::App.env
    previous_paths = Jedi::App.paths

    overrides = Jedi::App::PathOverrides.new(
      env: Jedi::App::Env::Test,
      config_dir: File.join(root, "config"),
      log_dir: File.join(root, "log"),
      data_dir: File.join(root, "data"),
      market_dir: File.join(root, "market"),
      db_file: File.join(root, "data", "jedi_test.db")
    )

    Jedi::App.bootstrap(overrides)

    begin
      yield Workspace.new(root)
    ensure
      Jedi::App.paths = previous_paths
      Jedi::App.env = previous_env
      FileUtils.rm_rf(root)
    end
  end

  def initialize_i18n : Nil
    Jedi.init_i18n("fr")
  end

  def fixture(name : String) : String
    File.expand_path(
      File.join("../fixtures/market_data", name),
      __DIR__
    )
  end

  def initialized_database(
    source : String = "spec",
    universe : String = Jedi::App.default_market_universe,
  ) : Jedi::MarketData::Database
    database = Jedi::MarketData::Database.new(source, universe)
    Jedi::MarketData::MarketInitializer.new(database).run
    database
  end

  def count(
    database : Jedi::MarketData::Database,
    sql : String,
    *params,
  ) : Int64
    value = 0_i64

    database.with_connection do |conn|
      value = conn.query_one(sql, *params, as: Int64)
    end

    value
  end

  def text_value(
    database : Jedi::MarketData::Database,
    sql : String,
    *params,
  ) : String?
    value = nil.as(String?)

    database.with_connection do |conn|
      conn.query(sql, *params) do |rs|
        rs.each do
          value = rs.read(String)
          break
        end
      end
    end

    value
  end

  def with_argv(args : Array(String), & : ->) : Nil
    previous = ARGV.dup
    ARGV.clear
    ARGV.concat(args)

    begin
      yield
    ensure
      ARGV.clear
      ARGV.concat(previous)
    end
  end
end
