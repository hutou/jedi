require "./spec_helper"

describe Jedi::MarketData::Schema do
  it "creates the version 7 schema" do
    JediMarketSpec.with_workspace do |_workspace|
      database = JediMarketSpec.initialized_database
      tables = [] of String
      version = 0

      database.with_connection do |conn|
        version = Jedi::MarketData::Schema.version(conn)
        conn.query(
          "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name"
        ) do |rs|
          rs.each { tables << rs.read(String) }
        end
      end

      version.should eq(7)
      tables.should contain("datasets")
      tables.should contain("securities")
      tables.should contain("security_datasets")
      tables.should contain("market_groups")
      tables.should contain("security_groups")
      tables.should contain("quotes")
      tables.should contain("quote_datasets")
      tables.should contain("security_updates")
    end
  end

  it "enforces OHLC consistency in SQLite" do
    JediMarketSpec.with_workspace do |_workspace|
      database = JediMarketSpec.initialized_database

      expect_raises(SQLite3::Exception, /CHECK constraint failed/) do
        database.with_connection do |conn|
          conn.exec(
            <<-SQL
              INSERT INTO securities(isin, name, ticker)
              VALUES ('FR4487601001', 'Alpha', 'ALP')
            SQL
          )
          conn.exec(
            <<-SQL
              INSERT INTO quotes(isin, date, open, high, low, close, volume)
              VALUES ('FR4487601001', 20200102, 10.0, 10.0, 9.0, 10.5, 100)
            SQL
          )
        end
      end
    end
  end

  it "migrates a version 2 database and preserves PEA as a named group" do
    JediMarketSpec.with_workspace do |workspace|
      filename = workspace.path("schema_v2.db")

      DB.open("sqlite3:#{filename}") do |db|
        db.using_connection do |conn|
          conn.exec(
            <<-SQL
              CREATE TABLE metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              )
            SQL
          )
          conn.exec(
            <<-SQL
              CREATE TABLE datasets (
                code TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                history_from INTEGER,
                quotes_file TEXT NOT NULL,
                labels_file TEXT NOT NULL,
                imported_at TEXT NOT NULL,
                security_count INTEGER NOT NULL DEFAULT 0,
                quote_count INTEGER NOT NULL DEFAULT 0
              )
            SQL
          )
          conn.exec(
            <<-SQL
              CREATE TABLE securities (
                isin TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                ticker TEXT NOT NULL,
                pea_eligible INTEGER
              )
            SQL
          )
          conn.exec(
            "INSERT INTO securities(isin, name, ticker, pea_eligible) " \
            "VALUES ('FR4487601001', 'Alpha', 'ALP', 1)"
          )
          conn.exec("PRAGMA user_version = 2")

          Jedi::MarketData::Schema.validate!(conn)

          Jedi::MarketData::Schema.version(conn).should eq(7)
          conn.query_one(
            "SELECT COUNT(*) FROM pragma_table_info('datasets') " \
            "WHERE name IN ('date_first', 'date_last', 'freshness_date_last')",
            as: Int64
          ).should eq(3_i64)
          conn.query_one(
            "SELECT COUNT(*) FROM sqlite_master " \
            "WHERE type = 'table' AND name = 'security_updates'",
            as: Int64
          ).should eq(1_i64)
          conn.query_one(
            "SELECT COUNT(*) FROM security_groups " \
            "WHERE group_code = 'PEA' AND isin = 'FR4487601001'",
            as: Int64
          ).should eq(1_i64)
          conn.query_one(
            "SELECT COUNT(*) FROM pragma_table_info('securities') " \
            "WHERE name IN ('pea_eligible', 'pea_pme_eligible')",
            as: Int64
          ).should eq(0_i64)
        end
      end
    end
  end

  it "migrates version 6 by copying the full-import reference and preserving data" do
    JediMarketSpec.with_workspace do |workspace|
      filename = workspace.path("schema_v6.db")

      DB.open("sqlite3:#{filename}") do |db|
        db.using_connection do |conn|
          Jedi::MarketData::Schema::STATEMENTS.each do |statement|
            if statement == Jedi::MarketData::Schema::CREATE_DATASETS_SQL
              conn.exec(
                <<-SQL
                  CREATE TABLE datasets (
                    code TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    history_from INTEGER,
                    date_first INTEGER,
                    date_last INTEGER,
                    quotes_file TEXT NOT NULL,
                    labels_file TEXT NOT NULL,
                    imported_at TEXT NOT NULL,
                    security_count INTEGER NOT NULL DEFAULT 0,
                    quote_count INTEGER NOT NULL DEFAULT 0
                  )
                SQL
              )
            else
              conn.exec(statement)
            end
          end
          conn.exec("PRAGMA foreign_keys = ON")
          conn.exec("PRAGMA user_version = 6")
          Jedi::MarketData::Schema.set_metadata(conn, "schema_version", "6")
          Jedi::MarketData::Schema.set_metadata(conn, "last_dataset_update_at", "preserved")
          datasets = Jedi::MarketData::DatasetRepository.new(conn)
          datasets.insert("dataset_a", "Dataset A", nil, "quotes.csv", "labels.csv")
          datasets.insert("empty", "Empty", nil, "empty.csv", "labels.csv")
          conn.exec(
            <<-SQL
              UPDATE datasets
              SET date_first = 20260930, date_last = 20260930,
                  imported_at = '2026-09-30T20:00:00Z',
                  security_count = 1, quote_count = 2
              WHERE code = 'dataset_a'
            SQL
          )
          conn.exec("INSERT INTO securities VALUES ('FR4487601001', 'Alpha', 'ALP')")
          conn.exec("INSERT INTO security_datasets VALUES ('dataset_a', 'FR4487601001')")
          [20260930, 20261002].each do |date|
            conn.exec("INSERT INTO quotes VALUES ('FR4487601001', ?, 10, 11, 9, 10, 100)", args: [date])
            conn.exec("INSERT INTO quote_datasets VALUES ('dataset_a', 'FR4487601001', ?)", args: [date])
          end
          conn.exec("INSERT INTO market_groups(code) VALUES ('PEA')")
          conn.exec("INSERT INTO security_groups VALUES ('PEA', 'FR4487601001')")

          Jedi::MarketData::Schema.validate!(conn)
          Jedi::MarketData::Schema.validate!(conn)

          Jedi::MarketData::Schema.version(conn).should eq(7)
          conn.query_one("SELECT value FROM metadata WHERE key = 'schema_version'", as: String).should eq("7")
          conn.query_one("SELECT value FROM metadata WHERE key = 'last_dataset_update_at'", as: String).should eq("preserved")
          conn.query_one("SELECT COUNT(*) FROM quotes", as: Int64).should eq(2_i64)
          conn.query_one("SELECT COUNT(*) FROM quote_datasets", as: Int64).should eq(2_i64)
          conn.query_one("SELECT COUNT(*) FROM security_groups", as: Int64).should eq(1_i64)
          conn.query_one("SELECT imported_at FROM datasets WHERE code = 'dataset_a'", as: String).should eq("2026-09-30T20:00:00Z")
          datasets.full_import_date_last("dataset_a").should eq(Time.utc(2026, 9, 30))
          datasets.freshness_date_last("dataset_a").should eq(Time.utc(2026, 9, 30))
          datasets.freshness_date_last("empty").should be_nil
          datasets.refresh_stats("dataset_a")
          datasets.freshness_date_last("dataset_a").should eq(Time.utc(2026, 10, 2))
          datasets.full_import_date_last("dataset_a").should eq(Time.utc(2026, 9, 30))
        end
      end
    end
  end
end
