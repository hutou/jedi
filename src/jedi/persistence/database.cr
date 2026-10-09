module Jedi
  module Database
    class Main
      getter conn_db
      getter us_sep = "\x1f"
      getter rs_sep = "\x1e"

      def initialize(@conn_db : DB::Connection)
      end

      def create
        create_table_trade
        create_table_security
        create_table_scale
        create_table_settings
        create_table_operation
        create_table_note
        App.info(key: "database.create.done")
      end

      def drop_table_trade
        conn_db.exec(<<-SQL)
        DROP TABLE IF EXISTS "trade";
        SQL
      end

      def create_table_trade
        drop_table_trade
        conn_db.exec(<<-SQL)
        CREATE TABLE "trade" (
          "id" INTEGER,
          "name" TEXT NOT NULL UNIQUE COLLATE NOCASE,
          "money" TEXT,
          "stop" TEXT,
          "security_id" INTEGER NOT NULL,
          PRIMARY KEY ("id"),
          CHECK (trim("name") <> ''),
          CHECK ("security_id" > 0),
          FOREIGN KEY ("security_id") REFERENCES "security" ("id")
        );
        SQL
      end

      def drop_table_security
        conn_db.exec(<<-SQL)
        DROP TABLE IF EXISTS "security";
        SQL
      end

      def create_table_security
        drop_table_security
        conn_db.exec(<<-SQL)
        CREATE TABLE "security" (
          "id"	INTEGER,
          "isin"	TEXT NOT NULL UNIQUE COLLATE NOCASE,
          "name"	TEXT NOT NULL COLLATE NOCASE,
          "ticker" TEXT NOT NULL,
          "tick_buy"	REAL NOT NULL,
          "tick_sell"	REAL NOT NULL,
          "tax"	REAL NOT NULL,
          "quotation_date"	TEXT,
          "quotation_website"	TEXT,
          "quotation_mode"	TEXT,
          "quotation_price"	REAL,
          "quotation_variation"	REAL,
          PRIMARY KEY("id"),
          CHECK (length("isin") = 12),
          CHECK (trim("name") <> ''),
          CHECK ("tick_buy" > 0),
          CHECK ("tick_sell" > 0),
          CHECK ("tax" >= 0),
          CHECK ("quotation_price" IS NULL OR "quotation_price" > 0)
        );
        SQL
      end

      def drop_table_scale
        conn_db.exec(<<-SQL)
        DROP TABLE IF EXISTS "scale";
        SQL
      end

      def create_table_scale
        drop_table_scale
        conn_db.exec(<<-SQL)
        CREATE TABLE "scale" (
          "id" INTEGER,
          "name" TEXT NOT NULL UNIQUE COLLATE NOCASE,
          "comment" TEXT,
          "operational" TEXT,
          PRIMARY KEY ("id")
          );
        SQL
      end

      def drop_table_settings
        conn_db.exec(<<-SQL)
        DROP TABLE IF EXISTS "settings";
        SQL
      end

      def create_table_settings
        drop_table_settings
        conn_db.exec(<<-SQL)
        CREATE TABLE "settings" (
          "id" INTEGER,
          "rank" INTEGER,
          "timestamp" TEXT NOT NULL UNIQUE,
          "split" TEXT,
          "sync" TEXT,
          "reinit" TEXT,
          "q0" REAL,
          "c0" REAL,
          "position" TEXT,
          "kspc" REAL,
          "kcpc" REAL,
          "trade_id" INTEGER,
          "scale_id" INTEGER,
          PRIMARY KEY ("id"),
          FOREIGN KEY ("trade_id") REFERENCES "trade" ("id"),
          FOREIGN KEY ("scale_id") REFERENCES "scale" ("id")
        );
        SQL
      end

      def drop_table_operation
        conn_db.exec(<<-SQL)
        DROP TABLE IF EXISTS "operation";
        SQL
      end

      def create_table_operation
        drop_table_operation
        conn_db.exec(<<-SQL)
        CREATE TABLE "operation" (
          "id" INTEGER,
          "timestamp" TEXT NOT NULL,
          "type" TEXT NOT NULL,
          "mode" TEXT NOT NULL,
          "quantity" INTEGER NOT NULL,
          "price" REAL NOT NULL,
          "buy" INTEGER NOT NULL,
          "sell" INTEGER NOT NULL,
          "trade_invest" INTEGER NOT NULL,
          "global_invest" INTEGER NOT NULL,
          "fees" INTEGER NOT NULL,
          "stock" INTEGER NOT NULL,
          "position" TEXT NOT NULL,
          "ksp" REAL NOT NULL,
          "kcp" REAL NOT NULL,
          "settings_id" INTEGER NOT NULL,
          PRIMARY KEY ("id"),
          CHECK ("type" IN ('Buy', 'Sell')),
          CHECK ("mode" IN ('Market', 'Limit', 'Stop', 'StopLoss')),
          CHECK ("quantity" > 0),
          CHECK ("price" > 0 OR
                 ("price" = 0 AND "type" = 'Sell' AND "stock" = 0)),
          CHECK ("buy" >= 0),
          CHECK ("sell" >= 0),
          CHECK ("fees" >= 0),
          CHECK ("stock" >= 0),
          CHECK ("settings_id" > 0),
          FOREIGN KEY ("settings_id") REFERENCES "settings" ("id")
        );
        SQL
      end

      def drop_table_note
        conn_db.exec(<<-SQL)
        DROP TABLE IF EXISTS "note";
        SQL
      end

      def create_table_note
        drop_table_note
        conn_db.exec(<<-SQL)
        CREATE TABLE "note" (
            "id" INTEGER,
            "date" TEXT NOT NULL,
            "summary" TEXT NOT NULL,
            "contents" TEXT NOT NULL,
          PRIMARY KEY ("id")
        );
        SQL
      end

      def schema
        String.build do |io|
          io << (title = I18n.t("database.schema.title1")) << "\n"
          io << ("-" * title.size) << "\n"
          io << (schema = App.get_schema(conn_db)) << "\n"
          io << (title = I18n.t("database.schema.title2")) << "\n"
          io << ("-" * title.size) << "\n"
          io << Digest::SHA256.hexdigest(schema)
        end
      end

      def load(filename : String, output : IO = STDOUT) : Nil
        ensure_database_empty!
        ensure_dump_exists!(filename)

        previous_simulation = App.simulation
        # Avoid normal production side effects while replaying operations.
        App.simulation = SimulationMode::FromOperation

        begin
          conn_db.transaction do |transaction|
            load_records(filename, transaction, output)
          end
        ensure
          App.simulation = previous_simulation
        end
      end

      private def ensure_database_empty! : Nil
        count = 0_i64
        %w(security scale trade settings operation note).each do |table|
          count += conn_db.scalar("SELECT COUNT(*) FROM #{table}").as(Int64)
        end
        return if count.zero?

        raise LowLevelError.new(
          key: "database.load.notempty",
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def ensure_dump_exists!(filename : String) : Nil
        return if File.exists?(filename)

        raise LowLevelError.new(
          key: "database.load.not_exists",
          context: {:filename => filename},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def load_records(filename : String,
                               load_transaction : DB::Transaction,
                               output : IO) : Nil
        load_conn = load_transaction.connection
        tables = %w(security scale trade settings operation note)
        linenum = 0
        security = scale = trade = settings = operation = note = 0
        saved_money_stop = {} of String => {String, String}

        File.each_line(filename) do |line|
          linenum += 1
          if line.count(us_sep) < 3
            raise LowLevelError.new(
              key: "database.load.sepcount",
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end

          jedi, command, subcommand, args = line.split(us_sep, 4)
          unless jedi == "jedi"
            raise LowLevelError.new(
              key: "database.load.jedi_missing",
              context: {:linenum => linenum.to_s},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
          unless command.in?(tables)
            raise LowLevelError.new(
              key: "database.load.invalid_command",
              context: {:command => command, :linenum => linenum.to_s},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
          unless subcommand == "create"
            raise LowLevelError.new(
              key: "database.load.invalid_subcommand",
              context: {:subcommand => subcommand, :linenum => linenum.to_s},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end

          case command
          when /^security$/i
            security += 1
            load_security(load_conn, args, linenum)
          when /^scale$/i
            scale += 1
            name, comment, builder = args.split(us_sep)
            TradingRules::ScaleCreator.new(load_conn).call(
              name: name,
              comment: comment,
              builder: builder)
          when /^trade$/i
            trade += 1
            name, security_ident, money, stop = args.split(us_sep)
            saved_money_stop[name] = {money, stop} unless money.empty? && stop.empty?
            security_ref : PkId | String = if security_ident =~ /^\d+$/
              security_ident.to_i64
            else
              security_ident
            end
            TradingSystem::TradeCreator.new(load_conn).call(
              name: name,
              money: TradingSystem::Money.parse(""),
              stop: TradingSystem::TradeStop.parse(""),
              security_ident: security_ref)
          when /^settings$/i
            settings += 1
            trade_name, scale_name, date_str, time_str, split, sync, reinit = args.split(us_sep)
            date = Core::Input.ensure_date_valid!(date_str,
              field: "date", key: "infra.field_required")
            time = Core::Input.ensure_time_valid!(time_str,
              field: "time", key: "infra.field_required")
            timestamp = Time.local(date.year, date.month, date.day,
              time.hour, time.minute, time.second)

            TradingSystem::SettingsCreator.new(load_conn).call(
              trade_ident: trade_name,
              scale_ident: scale_name,
              timestamp: timestamp,
              option_split: split.empty? ? nil : Exchange::Security::Split.new(split),
              option_sync: sync.empty? ? nil : TradingRules::Position.new(sync),
              option_reinit: reinit.empty? ? nil : TradingSystem::ReInitOption.parse(reinit))
          when /^operation$/i
            operation += 1
            trade_name, date_str, time_str, type, mode, quantity, price, fees = args.split(us_sep)
            date = Core::Input.ensure_date_valid!(date_str,
              field: "date", key: "infra.field_required")
            time = Core::Input.ensure_time_valid!(time_str,
              field: "time", key: "infra.field_required")
            timestamp = Time.local(date.year, date.month, date.day,
              time.hour, time.minute, time.second)

            TradingLife::OperationCreator.new(load_transaction).call(
              trade_ident: trade_name,
              timestamp: timestamp,
              type: TradingLife::Operation::Type.parse(type),
              mode: TradingLife::Operation::Mode.parse(mode),
              quantity: quantity.to_i,
              price: price.to_f,
              cfees: fees.to_f,
              tickcheck: false)
          when /^note$/i
            note += 1
            date, summary, contents = args.split(us_sep)
            Journal::NoteCreator.new(load_conn).call(
              date: date,
              summary: summary.gsub(/#{rs_sep}/, "\n"),
              contents: contents.gsub(/#{rs_sep}/, "\n"),
              edit: false)
          end

          if linenum == 1
            output.puts I18n.t("database.load.headers_format") %
                        I18n.t("database.load.headers").split(",")
          end
          body = I18n.t("database.load.body_format") %
                 [security, scale, trade, settings, operation, note]
          output.print body, "\033[K\r"
        end

        restore_money_and_stops(load_conn, saved_money_stop)
        output.puts I18n.t("database.load.done")
      end

      private def load_security(load_conn : DB::Connection,
                                args : String,
                                linenum : Int32) : Nil
        fields = args.split(us_sep)
        unless fields.size.in?(6, 11)
          raise LowLevelError.new(
            key: "database.load.invalid_security_field_count",
            kind: LowLevelError::Kind::InvalidData,
            context: {
              :linenum => linenum.to_s,
              :count   => fields.size.to_s,
            },
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        isin, name, ticker, tick_buy, tick_sell, tax = fields[0, 6]
        quotation_date : Time? = nil
        quotation_website : String? = nil
        quotation_mode : String? = nil
        quotation_price : Float64? = nil
        quotation_variation : Float64? = nil

        if fields.size == 11
          quotation_date = parse_quotation_date(fields[6], linenum)
          quotation_website = optional_string(fields[7])
          quotation_mode = optional_string(fields[8])
          quotation_price = parse_quotation_float(fields[9], "quotation_price", linenum)
          quotation_variation = parse_quotation_float(fields[10], "quotation_variation", linenum)
        end

        Exchange::SecurityCreator.new(load_conn).call(
          isin: isin,
          name: name,
          ticker: ticker,
          tick_buy: Exchange::Security::Tick.new(tick_buy),
          tick_sell: Exchange::Security::Tick.new(tick_sell),
          tax: Core::Input.ensure_decimal_pct_valid!(tax, field: "tax",
            regex: NON_NEGATIVE_DECIMAL_PCT),
          quotation_date: quotation_date,
          quotation_website: quotation_website,
          quotation_mode: quotation_mode,
          quotation_price: quotation_price,
          quotation_variation: quotation_variation)
      end

      private def optional_string(value : String) : String?
        value.empty? ? nil : value
      end

      private def parse_quotation_date(value : String, linenum : Int32) : Time?
        return nil if value.empty?

        Time.parse_rfc3339(value)
      rescue ex
        raise LowLevelError.new(
          "invalid quotation date '#{value}' in dump line #{linenum}",
          key: "database.load.invalid_quotation_value",
          kind: LowLevelError::Kind::InvalidData,
          context: {
            :field   => "quotation_date",
            :value   => value,
            :linenum => linenum.to_s,
          },
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          cause: ex)
      end

      private def parse_quotation_float(value : String,
                                        field : String,
                                        linenum : Int32) : Float64?
        return nil if value.empty?
        if parsed = value.to_f64?
          return parsed
        end

        raise LowLevelError.new(
          "invalid quotation value '#{value}' for '#{field}' in dump line #{linenum}",
          key: "database.load.invalid_quotation_value",
          kind: LowLevelError::Kind::InvalidData,
          context: {
            :field   => field,
            :value   => value,
            :linenum => linenum.to_s,
          },
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def restore_money_and_stops(
        load_conn : DB::Connection,
        saved_money_stop : Hash(String, Tuple(String, String)),
      ) : Nil
        saved_money_stop.each do |name, values|
          trade = TradingSystem::Trade.new(load_conn, name)
          # Money validation belongs to TradeUpdater and remains inside the
          # load transaction, so a failure rolls the complete import back.
          TradingSystem::TradeUpdater.new(trade).call money: values[0]
          begin
            stop = TradingSystem::TradeStop.parse(values[1])
          rescue ex : LowLevelError
            raise LowLevelError.new(
              "invalid stored stop '#{values[1]}' for trade '#{trade.name}'",
              key: "trade.invalid_stored_stop",
              context: {
                :trade => trade.name,
                :stop  => values[1],
              },
              kind: LowLevelError::Kind::InvalidData,
              log_context: {
                :trade  => trade.name,
                :stop   => values[1],
                :source => Core::Utils.source(__FILE__, __LINE__),
              },
              cause: ex)
          end
          trade.stop_update(stop)
        end
      end

      def dump(output : IO = STDOUT) : Nil
        output_trades = [] of PkId
        output_securities = [] of PkId
        output_scaledefs = [] of PkId

        # Keep settings and operations as separate timeline entries. A hash
        # keyed only by timestamp and id could overwrite an operation with a
        # settings row when both happen to share the same values.
        timeline = [] of {Time, Int32, PkId, TradingSystem::Settings | TradingLife::Operation}
        TradingSystem::SettingsChain.new(conn_db).fetch.each do |settings|
          timeline << {settings.timestamp, 0, settings.id, settings}
          settings.operations.each do |operation|
            timeline << {operation.timestamp, 1, operation.id, operation}
          end
        end

        # Sort chronologically, with settings before operations at an equal
        # timestamp, then output every row after its dependencies.
        timeline.sort_by! { |entry| {entry[0], entry[1], entry[2]} }
        timeline.each do |entry|
          case item = entry[3]
          when TradingSystem::Settings
            settings = item
            trade = TradingSystem::Trade.new(conn_db, settings.trade_id)
            scaledef = TradingRules::Scale.new(conn_db, settings.scale_id)
            security = Exchange::Security.new(conn_db, trade.security_id)
            unless output_securities.includes?(security.id)
              dump_security(output, security)
              output_securities << security.id
            end
            unless output_trades.includes?(settings.trade_id)
              output.puts ["jedi", "trade", "create", trade.name, security.isin,
                           trade.money, trade.stop].join(us_sep)
              output_trades << trade.id
            end
            unless output_scaledefs.includes?(scaledef.id)
              output.puts ["jedi", "scale", "create", scaledef.name, scaledef.comment,
                           scaledef.operational.builder].join(us_sep) # builder, not definition,
              # otherwise, builder is "lost" on next loading !
              # scaledef.operational.definition].join(us_sep)
              output_scaledefs << scaledef.id
            end
            date = settings.timestamp.to_s("%Y-%m-%d")
            time = settings.timestamp.to_s("%H:%M:%S")
            split = settings.split.to_s
            sync = settings.sync.to_s
            reinit = settings.reinit
            output.puts ["jedi", "settings", "create", trade.name, scaledef.name,
                         date, time, split, sync, reinit].join(us_sep)
          when TradingLife::Operation
            operation = item
            trade = TradingSystem::Trade.new(conn_db, operation.settings.trade_id)
            date = operation.timestamp.to_s("%Y-%m-%d")
            time = operation.timestamp.to_s("%H:%M:%S")
            output.puts ["jedi", "operation", "create", trade.name, date, time,
                         operation.type, operation.mode, operation.quantity,
                         operation.price, operation.fees/100].join(us_sep)
          end
        end

        # Remaining securities must precede remaining trades because every
        # trade is resolved against its security as soon as it is loaded.
        Exchange::Securities.new(conn_db).fetch.each do |security|
          unless output_securities.includes?(security.id)
            dump_security(output, security)
            output_securities << security.id
          end
        end
        TradingSystem::Trades.new(conn_db).fetch.each do |trade|
          unless output_trades.includes?(trade.id)
            security = Exchange::Security.new(conn_db, trade.security_id)
            output.puts ["jedi", "trade", "create", trade.name, security.isin,
                         trade.money, trade.stop].join(us_sep)
            output_trades << trade.id
          end
        end
        TradingRules::Scales.new(conn_db).fetch.each do |scaledef|
          unless output_scaledefs.includes?(scaledef.id)
            output.puts ["jedi", "scale", "create", scaledef.name,
                         scaledef.comment, scaledef.operational.builder].join(us_sep)
            output_scaledefs << scaledef.id
          end
        end
        Journal::Notes.new(conn_db).fetch.each do |note|
          output.puts ["jedi", "note", "create", note.date.to_s("%Y-%m-%d"),
                       note.summary.gsub(/\n/, rs_sep),
                       note.contents.gsub(/\n/, rs_sep)].join(us_sep)
        end
      end

      private def dump_security(output : IO, security : Exchange::Security) : Nil
        # SQLite stores the instant in UTC; Security exposes it in local time.
        # The dump returns to UTC so it remains independent of the machine's
        # time zone, and load parses the same RFC 3339 instant.
        quotation_date = security.quotation_date
        quotation_website = security.quotation_website
        quotation_mode = security.quotation_mode
        quotation_price = security.quotation_price
        quotation_variation = security.quotation_variation

        fields = [
          "jedi",
          "security",
          "create",
          security.isin,
          security.name,
          security.ticker,
          security.tick_buy.value.to_s,
          security.tick_sell.value.to_s,
          security.tax.to_s,
        ]

        if quotation_date || quotation_website || quotation_mode ||
           quotation_price || quotation_variation
          fields << (quotation_date ? quotation_date.to_utc.to_rfc3339(fraction_digits: 9) : "")
          fields << (quotation_website || "")
          fields << (quotation_mode || "")
          fields << (quotation_price ? quotation_price.to_s : "")
          fields << (quotation_variation ? quotation_variation.to_s : "")
        end

        output.puts fields.join(us_sep)
      end
    end
  end
end
