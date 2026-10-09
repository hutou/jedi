module Jedi
  module MarketData
    module Schema
      extend self

      VERSION = 7

      CREATE_METADATA_SQL = <<-SQL
        CREATE TABLE metadata (
          key   TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      SQL

      CREATE_DATASETS_SQL = <<-SQL
        CREATE TABLE datasets (
          code                TEXT PRIMARY KEY,
          name                TEXT NOT NULL,
          history_from        INTEGER,
          date_first          INTEGER,
          date_last           INTEGER,
          freshness_date_last INTEGER,
          quotes_file         TEXT NOT NULL,
          labels_file         TEXT NOT NULL,
          imported_at         TEXT NOT NULL,
          security_count      INTEGER NOT NULL DEFAULT 0,
          quote_count         INTEGER NOT NULL DEFAULT 0,

          CHECK (code <> ''),
          CHECK (name <> ''),
          CHECK (
            history_from IS NULL
            OR history_from BETWEEN 19000101 AND 21991231
          ),
          CHECK (
            date_first IS NULL
            OR date_first BETWEEN 19000101 AND 21991231
          ),
          CHECK (
            date_last IS NULL
            OR date_last BETWEEN 19000101 AND 21991231
          ),
          CHECK (
            freshness_date_last IS NULL
            OR freshness_date_last BETWEEN 19000101 AND 21991231
          ),
          CHECK (
            date_first IS NULL
            OR date_last IS NULL
            OR date_first <= date_last
          ),
          CHECK (security_count >= 0),
          CHECK (quote_count >= 0)
        )
      SQL

      CREATE_SECURITIES_SQL = <<-SQL
        CREATE TABLE securities (
          isin   TEXT PRIMARY KEY,
          name   TEXT NOT NULL,
          ticker TEXT NOT NULL,

          CHECK (length(isin) = 12),
          CHECK (name <> ''),
          CHECK (ticker <> '')
        )
      SQL

      # Intermediate schema used only while upgrading databases older than
      # version 5. Version 5 introduced a non-null PEA flag; version 6 migrates
      # that flag to the generic many-to-many group tables below.
      CREATE_SECURITIES_V5_SQL = <<-SQL
        CREATE TABLE securities (
          isin         TEXT PRIMARY KEY,
          name         TEXT NOT NULL,
          ticker       TEXT NOT NULL,
          pea_eligible INTEGER NOT NULL DEFAULT 0,

          CHECK (length(isin) = 12),
          CHECK (name <> ''),
          CHECK (ticker <> ''),
          CHECK (pea_eligible IN (0, 1))
        )
      SQL

      CREATE_SECURITIES_TICKER_INDEX_SQL = <<-SQL
        CREATE INDEX securities_ticker_idx
          ON securities(ticker)
      SQL

      CREATE_MARKET_GROUPS_SQL = <<-SQL
        CREATE TABLE market_groups (
          code             TEXT PRIMARY KEY COLLATE NOCASE,
          reference_source TEXT,
          reference_date   INTEGER,
          synchronized_at  TEXT,

          CHECK (code <> ''),
          CHECK (
            reference_date IS NULL
            OR reference_date BETWEEN 19000101 AND 21991231
          ),
          CHECK (synchronized_at IS NULL OR synchronized_at <> '')
        )
      SQL

      CREATE_SECURITY_GROUPS_SQL = <<-SQL
        CREATE TABLE security_groups (
          group_code TEXT NOT NULL COLLATE NOCASE,
          isin       TEXT NOT NULL,

          PRIMARY KEY (group_code, isin),

          FOREIGN KEY (group_code)
            REFERENCES market_groups(code)
            ON DELETE CASCADE,

          FOREIGN KEY (isin)
            REFERENCES securities(isin)
            ON DELETE CASCADE
        ) WITHOUT ROWID
      SQL

      CREATE_SECURITY_GROUPS_ISIN_INDEX_SQL = <<-SQL
        CREATE INDEX security_groups_isin_idx
          ON security_groups(isin)
      SQL

      CREATE_SECURITY_DATASETS_SQL = <<-SQL
        CREATE TABLE security_datasets (
          dataset_code TEXT NOT NULL,
          isin         TEXT NOT NULL,

          PRIMARY KEY (dataset_code, isin),

          FOREIGN KEY (dataset_code)
            REFERENCES datasets(code)
            ON DELETE CASCADE,

          FOREIGN KEY (isin)
            REFERENCES securities(isin)
            ON DELETE CASCADE
        ) WITHOUT ROWID
      SQL

      CREATE_SECURITY_DATASETS_ISIN_INDEX_SQL = <<-SQL
        CREATE INDEX security_datasets_isin_idx
          ON security_datasets(isin)
      SQL

      CREATE_QUOTES_SQL = <<-SQL
        CREATE TABLE quotes (
          isin   TEXT    NOT NULL,
          date   INTEGER NOT NULL,
          open   REAL    NOT NULL,
          high   REAL    NOT NULL,
          low    REAL    NOT NULL,
          close  REAL    NOT NULL,
          volume INTEGER NOT NULL,

          PRIMARY KEY (isin, date),

          FOREIGN KEY (isin)
            REFERENCES securities(isin)
            ON DELETE CASCADE,

          CHECK (date BETWEEN 19000101 AND 21991231),
          CHECK (open > 0),
          CHECK (high > 0),
          CHECK (low > 0),
          CHECK (close > 0),
          CHECK (volume >= 0),
          CHECK (low <= open),
          CHECK (low <= close),
          CHECK (high >= open),
          CHECK (high >= close)
        ) WITHOUT ROWID
      SQL

      CREATE_QUOTE_DATASETS_SQL = <<-SQL
        CREATE TABLE quote_datasets (
          dataset_code TEXT    NOT NULL,
          isin         TEXT    NOT NULL,
          date         INTEGER NOT NULL,

          PRIMARY KEY (dataset_code, isin, date),

          FOREIGN KEY (dataset_code)
            REFERENCES datasets(code)
            ON DELETE CASCADE,

          FOREIGN KEY (isin, date)
            REFERENCES quotes(isin, date)
            ON DELETE CASCADE
        ) WITHOUT ROWID
      SQL

      CREATE_QUOTE_DATASETS_QUOTE_INDEX_SQL = <<-SQL
        CREATE INDEX quote_datasets_quote_idx
          ON quote_datasets(isin, date)
      SQL

      CREATE_SECURITY_UPDATES_SQL = <<-SQL
        CREATE TABLE security_updates (
          isin            TEXT PRIMARY KEY,
          updated_at      TEXT    NOT NULL,
          date_first      INTEGER NOT NULL,
          date_last       INTEGER NOT NULL,
          quotes_read     INTEGER NOT NULL,
          quotes_inserted INTEGER NOT NULL,
          source_file     TEXT    NOT NULL,

          FOREIGN KEY (isin)
            REFERENCES securities(isin)
            ON DELETE CASCADE,

          CHECK (date_first BETWEEN 19000101 AND 21991231),
          CHECK (date_last BETWEEN 19000101 AND 21991231),
          CHECK (date_first <= date_last),
          CHECK (quotes_read >= 0),
          CHECK (quotes_inserted >= 0),
          CHECK (source_file <> '')
        )
      SQL

      STATEMENTS = {
        CREATE_METADATA_SQL,
        CREATE_DATASETS_SQL,
        CREATE_SECURITIES_SQL,
        CREATE_SECURITIES_TICKER_INDEX_SQL,
        CREATE_MARKET_GROUPS_SQL,
        CREATE_SECURITY_GROUPS_SQL,
        CREATE_SECURITY_GROUPS_ISIN_INDEX_SQL,
        CREATE_SECURITY_DATASETS_SQL,
        CREATE_SECURITY_DATASETS_ISIN_INDEX_SQL,
        CREATE_QUOTES_SQL,
        CREATE_QUOTE_DATASETS_SQL,
        CREATE_QUOTE_DATASETS_QUOTE_INDEX_SQL,
        CREATE_SECURITY_UPDATES_SQL,
      }

      def create(conn : DB::Connection) : Nil
        conn.exec("PRAGMA foreign_keys = ON")

        STATEMENTS.each do |statement|
          conn.exec(statement)
        end

        conn.exec("PRAGMA user_version = #{VERSION}")
        set_metadata(conn, "schema_version", VERSION.to_s)
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot create market database schema: " \
          "#{ex.message || ex.class.name}",
          log_context: {:schema_version => VERSION.to_s},
          cause: ex
        )
      end

      def version(conn : DB::Connection) : Int32
        conn.query_one("PRAGMA user_version", as: Int64).to_i32
      rescue ex
        raise LowLevelError.new(
          "cannot read market database schema version: " \
          "#{ex.message || ex.class.name}",
          cause: ex
        )
      end

      def validate!(conn : DB::Connection) : Nil
        current = version(conn)

        case current
        when VERSION
          nil
        when 6
          migrate_v6_to_v7(conn)
        when 5
          migrate_v5_to_v6(conn)
          migrate_v6_to_v7(conn)
        when 4
          migrate_to_v5(conn, 4)
          migrate_v5_to_v6(conn)
          migrate_v6_to_v7(conn)
        when 3
          migrate_to_v5(conn, 3)
          migrate_v5_to_v6(conn)
          migrate_v6_to_v7(conn)
        when 2
          migrate_v2_to_v3(conn)
          migrate_to_v5(conn, 3)
          migrate_v5_to_v6(conn)
          migrate_v6_to_v7(conn)
        else
          raise LowLevelError.new(
            "unsupported market database schema version #{current}; " \
            "expected #{VERSION}",
            log_context: {
              :schema_version  => current.to_s,
              :expected_schema => VERSION.to_s,
            }
          )
        end
      end

      def set_metadata(conn : DB::Connection, key : String, value : String) : Nil
        conn.exec(
          <<-SQL,
            INSERT OR REPLACE INTO metadata(key, value)
            VALUES (?, ?)
          SQL
          key,
          value
        )
      rescue ex
        raise LowLevelError.new(
          "cannot write market database metadata '#{key}': " \
          "#{ex.message || ex.class.name}",
          log_context: {
            :metadata_key   => key,
            :metadata_value => value,
          },
          cause: ex
        )
      end

      private def migrate_v2_to_v3(conn : DB::Connection) : Nil
        conn.transaction do |tx|
          migration_conn = tx.connection
          migration_conn.exec(
            "ALTER TABLE datasets ADD COLUMN date_first INTEGER"
          )
          migration_conn.exec(
            "ALTER TABLE datasets ADD COLUMN date_last INTEGER"
          )
          migration_conn.exec(CREATE_SECURITY_UPDATES_SQL)
          migration_conn.exec("PRAGMA user_version = 3")
          set_metadata(migration_conn, "schema_version", "3")
          set_metadata(
            migration_conn,
            "schema_migrated_at",
            Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")
          )
        end
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot migrate market database schema from version 2 to " \
          "version 3: #{ex.message || ex.class.name}",
          log_context: {
            :schema_version  => "2",
            :expected_schema => "3",
          },
          cause: ex
        )
      end

      private def migrate_to_v5(conn : DB::Connection, from_version : Int32) : Nil
        conn.exec("PRAGMA foreign_keys = OFF")
        conn.exec("PRAGMA legacy_alter_table = ON")

        conn.transaction do |tx|
          migration_conn = tx.connection
          migration_conn.exec("ALTER TABLE securities RENAME TO securities_v4")
          migration_conn.exec(CREATE_SECURITIES_V5_SQL)
          migration_conn.exec(
            <<-SQL
              INSERT INTO securities(isin, name, ticker, pea_eligible)
              SELECT isin, name, ticker, COALESCE(pea_eligible, 0)
              FROM securities_v4
            SQL
          )
          migration_conn.exec("DROP TABLE securities_v4")
          migration_conn.exec(CREATE_SECURITIES_TICKER_INDEX_SQL)

          %w(
            pea_pme_source
            pea_pme_imported_at
            pea_pme_count
            pea_pme_as_of
          ).each do |key|
            migration_conn.exec("DELETE FROM metadata WHERE key = ?", key)
          end

          migration_conn.exec("PRAGMA user_version = 5")
          set_metadata(migration_conn, "schema_version", "5")
          set_metadata(
            migration_conn,
            "schema_migrated_at",
            Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")
          )
        end
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot migrate market database schema from version #{from_version} to " \
          "version 5: #{ex.message || ex.class.name}",
          log_context: {
            :schema_version  => from_version.to_s,
            :expected_schema => "5",
          },
          cause: ex
        )
      ensure
        conn.exec("PRAGMA legacy_alter_table = OFF")
        conn.exec("PRAGMA foreign_keys = ON")
      end

      private def migrate_v5_to_v6(conn : DB::Connection) : Nil
        conn.exec("PRAGMA foreign_keys = OFF")
        conn.exec("PRAGMA legacy_alter_table = ON")

        conn.transaction do |tx|
          migration_conn = tx.connection
          timestamp = Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")

          migration_conn.exec("ALTER TABLE securities RENAME TO securities_v5")
          migration_conn.exec(CREATE_SECURITIES_SQL)
          migration_conn.exec(
            <<-SQL
              INSERT INTO securities(isin, name, ticker)
              SELECT isin, name, ticker
              FROM securities_v5
            SQL
          )

          migration_conn.exec(CREATE_MARKET_GROUPS_SQL)
          migration_conn.exec(CREATE_SECURITY_GROUPS_SQL)
          migration_conn.exec(CREATE_SECURITY_GROUPS_ISIN_INDEX_SQL)

          migration_conn.exec(
            <<-SQL,
              INSERT INTO market_groups(
                code, reference_source, reference_date, synchronized_at
              )
              SELECT
                'PEA',
                (SELECT value FROM metadata WHERE key = 'pea_source'),
                CAST((SELECT value FROM metadata WHERE key = 'pea_as_of') AS INTEGER),
                COALESCE(
                  (SELECT value FROM metadata WHERE key = 'pea_imported_at'),
                  ?
                )
              WHERE EXISTS (
                SELECT 1 FROM securities_v5 WHERE pea_eligible = 1
              ) OR EXISTS (
                SELECT 1 FROM metadata
                WHERE key IN ('pea_source', 'pea_as_of', 'pea_imported_at')
              )
            SQL
            timestamp
          )

          migration_conn.exec(
            <<-SQL
              INSERT INTO security_groups(group_code, isin)
              SELECT 'PEA', isin
              FROM securities_v5
              WHERE pea_eligible = 1
            SQL
          )

          migration_conn.exec("DROP TABLE securities_v5")
          migration_conn.exec(CREATE_SECURITIES_TICKER_INDEX_SQL)

          %w(
            pea_source
            pea_imported_at
            pea_count
            pea_as_of
          ).each do |key|
            migration_conn.exec("DELETE FROM metadata WHERE key = ?", key)
          end

          migration_conn.exec("PRAGMA user_version = 6")
          set_metadata(migration_conn, "schema_version", "6")
          set_metadata(migration_conn, "schema_migrated_at", timestamp)
        end
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot migrate market database schema from version 5 to " \
          "version 6: #{ex.message || ex.class.name}",
          log_context: {
            :schema_version  => "5",
            :expected_schema => "6",
          },
          cause: ex
        )
      ensure
        conn.exec("PRAGMA legacy_alter_table = OFF")
        conn.exec("PRAGMA foreign_keys = ON")
      end

      private def migrate_v6_to_v7(conn : DB::Connection) : Nil
        conn.transaction do |tx|
          migration_conn = tx.connection
          migration_conn.exec(
            <<-SQL
              ALTER TABLE datasets ADD COLUMN freshness_date_last INTEGER
              CHECK (
                freshness_date_last IS NULL
                OR freshness_date_last BETWEEN 19000101 AND 21991231
              )
            SQL
          )
          # Keep the previous freshness reference until the next dataset update
          # recomputes it from the quotations actually linked to that dataset.
          migration_conn.exec("UPDATE datasets SET freshness_date_last = date_last")
          migration_conn.exec("PRAGMA user_version = 7")
          set_metadata(migration_conn, "schema_version", "7")
          set_metadata(
            migration_conn,
            "schema_migrated_at",
            Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")
          )
        end
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot migrate market database schema from version 6 to " \
          "version 7: #{ex.message || ex.class.name}",
          log_context: {
            :schema_version  => "6",
            :expected_schema => "7",
          },
          cause: ex
        )
      end
    end
  end
end
