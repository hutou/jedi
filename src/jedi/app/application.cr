module Jedi
  module App
    # ====================================================================
    #
    #                       enum Env
    #
    # ====================================================================
    enum Env
      Prod
      Dev
      Test
    end

    # ====================================================================
    #
    #                       struct Paths
    #
    # ====================================================================
    struct Paths
      getter config_dir : String
      getter log_dir : String
      getter data_dir : String
      getter market_dir : String
      getter config_file : String
      getter log_file : String
      getter db_file : String

      def initialize(
        @config_dir : String,
        @log_dir : String,
        @data_dir : String,
        @market_dir : String,
        @config_file : String,
        @log_file : String,
        @db_file : String,
      )
      end
    end

    # ====================================================================
    #
    #                       struct PathOverrides
    #
    # ====================================================================
    struct PathOverrides
      getter env : Env?
      getter config_dir : String?
      getter log_dir : String?
      getter data_dir : String?
      getter market_dir : String?
      getter db_file : String?

      def initialize(
        @env : Env? = nil,
        @config_dir : String? = nil,
        @log_dir : String? = nil,
        @data_dir : String? = nil,
        @market_dir : String? = nil,
        @db_file : String? = nil,
      )
      end
    end

    # ====================================================================
    #
    #                       module PathResolver
    #
    # ====================================================================
    module PathResolver
      APP_NAME = "jedi"

      private struct DefaultDirs
        getter config_dir : String
        getter log_dir : String
        getter data_dir : String
        getter market_dir : String

        def initialize(@config_dir : String, @log_dir : String, @data_dir : String, @market_dir : String)
        end
      end

      def self.resolve(env : Env, overrides : PathOverrides = PathOverrides.new) : Paths
        defaults = default_dirs(env)

        config_dir = normalize_dir(
          first_present(
            overrides.config_dir,
            ENV["JEDI_CONFIG_DIR"]?,
            defaults.config_dir
          )
        )

        log_dir = normalize_dir(
          first_present(
            overrides.log_dir,
            ENV["JEDI_LOG_DIR"]?,
            defaults.log_dir
          )
        )

        data_dir = normalize_dir(
          first_present(
            overrides.data_dir,
            ENV["JEDI_DATA_DIR"]?,
            defaults.data_dir
          )
        )
        market_dir = normalize_dir(
          first_present(
            overrides.market_dir,
            ENV["JEDI_MARKET_DIR"]?,
            defaults.market_dir
          )
        )
        basename =
          case env
          in Env::Prod then "jedi"
          in Env::Dev  then "jedi_dev"
          in Env::Test then "jedi_test"
          end

        config_file = File.expand_path(File.join(config_dir, "#{basename}.conf"))
        log_file = File.expand_path(File.join(log_dir, "#{basename}.log"))

        db_file = File.expand_path(
          first_present(
            overrides.db_file,
            ENV["JEDI_DB_FILE"]?,
            File.join(data_dir, "#{basename}.db")
          )
        )

        Paths.new(
          config_dir: config_dir,
          log_dir: log_dir,
          data_dir: data_dir,
          market_dir: market_dir,
          config_file: config_file,
          log_file: log_file,
          db_file: db_file
        )
      end

      private def self.default_dirs(env : Env) : DefaultDirs
        case env
        in Env::Prod
          DefaultDirs.new(
            xdg_config_home(APP_NAME),
            xdg_state_home(APP_NAME),
            xdg_data_home(APP_NAME),
            File.join(xdg_data_home(APP_NAME), "market")
          )
        in Env::Dev
          base = local_env_base("dev")
          DefaultDirs.new(
            "#{base}/conf",
            "#{base}/log",
            "#{base}/data",
            "#{base}/market"
          )
        in Env::Test
          base = local_env_base("test")
          DefaultDirs.new(
            "#{base}/conf",
            "#{base}/log",
            "#{base}/data",
            "#{base}/market"
          )
        end
      end

      private def self.local_env_base(env_name : String) : String
        curdir = Dir.current
        root = if File.basename(curdir) == "jedi"
                 curdir
               else
                 File.join(curdir, "jedi")
               end
        File.join(root, "env_#{env_name}")
      end

      private def self.first_present(*values : String?) : String
        values.each do |value|
          return value unless value.nil? || value.blank?
        end
        raise LowLevelError.new(
          "no application path value could be resolved",
          key: "app.paths.no_value_resolved",
          kind: LowLevelError::Kind::Technical,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def self.normalize_dir(path : String) : String
        expanded = File.expand_path(path)
        expanded == "/" ? expanded : expanded.rstrip('/')
      end

      private def self.xdg_config_home(app_name : String) : String
        base = ENV["XDG_CONFIG_HOME"]? || "#{home_dir}/.config"
        "#{base}/#{app_name}"
      end

      private def self.xdg_state_home(app_name : String) : String
        base = ENV["XDG_STATE_HOME"]? || "#{home_dir}/.local/state"
        "#{base}/#{app_name}"
      end

      private def self.xdg_data_home(app_name : String) : String
        base = ENV["XDG_DATA_HOME"]? || "#{home_dir}/.local/share"
        "#{base}/#{app_name}"
      end

      private def self.home_dir : String
        ENV["HOME"]? ||
          raise LowLevelError.new(
            "HOME is not defined",
            key: "app.paths.home_not_defined",
            kind: LowLevelError::Kind::Domain,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end
    end

    # ====================================================================
    #
    #                       struct MoneyLimits
    #
    # ====================================================================
    struct MoneyLimits
      getter risk_rate_min : Float64
      getter risk_rate_max : Float64
      getter target_coeff_min : Float64
      getter target_coeff_max : Float64
      getter steps_down_min : Int32
      getter steps_down_max : Int32

      def initialize(
        @risk_rate_min : Float64,
        @risk_rate_max : Float64,
        @target_coeff_min : Float64,
        @target_coeff_max : Float64,
        @steps_down_min : Int32,
        @steps_down_max : Int32,
      )
        validate!
      end

      private def validate! : Nil
        validate_range!(
          name: "risk_rate",
          min: risk_rate_min,
          max: risk_rate_max
        )

        validate_range!(
          name: "target_coeff",
          min: target_coeff_min,
          max: target_coeff_max
        )

        validate_range!(
          name: "steps_down",
          min: steps_down_min,
          max: steps_down_max
        )
      end

      private def validate_range!(name : String, min, max) : Nil
        return if min <= max

        raise LowLevelError.new(
          "invalid money limits: #{name} min=#{min}, max=#{max}",
          key: "app.money.invalid_limits",
          context: {
            :name => name,
            :min  => min.to_s,
            :max  => max.to_s,
          },
          kind: LowLevelError::Kind::InvalidData,
          log_context: {
            :name   => name,
            :min    => min.to_s,
            :max    => max.to_s,
            :source => Core::Utils.source(__FILE__, __LINE__),
          }
        )
      end
    end

    # ====================================================================
    #
    #                       module App begin
    #
    # ====================================================================

    class_property? noconfirm = false
    class_property simulation : SimulationMode = SimulationMode::None
    class_property! lang : String

    class_property env : Env?
    class_property paths : Paths?

    class_property! conn_main : DB::Connection
    class_property! conn_memory : DB::Connection
    class_property fees : NamedTuple(rate: Float64, min: Float64)?

    # Variables used by option_??? methods
    # initialized from CONFIG in init_stage1
    class_property capital : Int32 = 0
    class_property distance : Float64 = 0.0
    class_property risk_rate : Float64 = 0.0
    class_property initial_investment : Int32 = 0
    class_property! config : YAML::Any

    DB_SCHEMA_DIGEST = "dae44bb8be7aca0f9af2a888f7c4afcc734e297d8f90c600b52ed60b8b262934"

    # --------------------------------------------------------------------
    #                       Yaml definitions and config
    # --------------------------------------------------------------------
    YAML_CONFIG = <<-'YAML'
    border: ascii
    market_data:
      default_universe: france
      mode_order: ["live", "eod"]
      api_order: ["alphavantage"]
      website_order: ["abcbourse", "tradingsat", "boursorama"]
      api_providers:
        alphavantage:
          api_key: "yyyyy"
          symbol_candidates:
            mode: "ticker_plus_suffixes"
            suffixes: [".PAR", ".PA", ""]
          quote:
            base_url: "https://www.alphavantage.co"
            path: "/query"
            query:
              function: "GLOBAL_QUOTE"
              symbol: "{symbol}"
              apikey: "{api_key}"
            symbol_path: ["Global Quote","01. symbol"]
            price_path: ["Global Quote","05. price"]
            trading_day_path: ["Global Quote","07. latest trading day"]
            prev_close_path: ["Global Quote","08. previous close"]
            change_path: ["Global Quote","09. change"]
            change_percent_path: ["Global Quote","10. change percent"]
            change_percent_strip_percent: true
      websites:
        abcbourse:
          url: "https://www.abcbourse.com/cotation/{key}"
          key_strategy:
            candidates:
              - template: "{ticker}p"
              - template: "{isin}"
          regex_price: 'id="lastcx">(?<price>\d+(?:[.,]\d+)*)\s*&#x20AC;'
          regex_variation: 'id="varcx"\s+class="quote_(up|down)b">(?<variation>(&#x2B;|&#x2D;|\+|-)?\d+(?:[.,]\d+)*)%' 
        tradingsat:
          url: "https://www.tradingsat.com/{key}"
          key_strategy:
            candidates:
              - template: "{name_slug}-{isin}"
                vars:
                  name_slug:
                    from: "name"
                    ops:
                      - "downcase"
                      - {gsub: {pattern: "\\.", replace: ""}}
                      - {gsub: {pattern: " ", replace: "-"}}
          regex_price: 'class="price">(?<price>\d+(?:[,.]\d+)*)\s*€'
          regex_variation: 'class="variation var-(down|neutral|up)">(?<variation>[+-]?\d+(?:[,.]\d+)*)\s*%'
        boursorama:
          url: "https://www.boursorama.com/cours/{key}/"
          key_strategy:
            candidates:
              - template: "1rP{ticker}"
              - template: "1rEP{ticker}"
              - template: "{ticker}"
                ops:
                  ticker: ["upcase", "trim"]
          regex_price: 'c-faceplate__info.+?price.+?ist-last>(?<price>\d+(?:[,.]\d+)*)<'
          regex_variation: 'c-faceplate__info.+?fluctuation.+?ist-variation>(?<variation>[+-]?\d+(?:[.,]\d+)*)%'
    fees:
      rate:
        0.003_5
      min:
        0.0
    watchrate:
      10.0
    diagnostic_steps:
      3
    quotlife:
      240.0
    tickcheck:
      true
    trading:
      capital: 20000
        # risk_rate set by money definition string
        # distance not used as initial investment is left to the user
    money:
      risk_rate_min: 0.005
      risk_rate_max: 0.05
      target_coeff_min: 0.5
      target_coeff_max: 5.0
      steps_down_min: 1
      steps_down_max: 5
    simulation:
      capital:
        20000
      distance:
        0.2
      risk_rate:
        0.015
    YAML

    # Merge policy:
    # - Hash: deep merge
    # - Scalar: override
    # - Array: override (simple + predictable)
    def self.deep_merge(base : YAML::Any, override : YAML::Any) : YAML::Any
      # If types differ, override wins
      if base.raw.class != override.raw.class
        return override
      end

      case base.raw
      when Hash
        b = base.as_h
        o = override.as_h
        merged = {} of YAML::Any => YAML::Any
        b.each { |k, v| merged[k] = v }

        o.each do |k, ov|
          if merged.has_key?(k)
            merged[k] = deep_merge(merged[k], ov)
          else
            merged[k] = ov
          end
        end

        YAML::Any.new(merged)
      when Array
        override
      else
        override
      end
    end

    # --------------------------------------------------------------------
    #                       Bootstrap, paths, environment
    # --------------------------------------------------------------------
    def self.default_env : Env
      Env::Prod
    end

    ENV_ALLOWED_VALUES = "prod, dev, test"

    def self.parse_env(value : String?) : Env
      raw = value || ENV["JEDI_ENV"]? || nil
      return default_env if raw.nil? || raw.blank?

      case raw.downcase
      when "prod", "production"
        Env::Prod
      when "dev", "development"
        Env::Dev
      when "test"
        Env::Test
      else
        raise LowLevelError.new(
          "invalid application environment '#{raw}'",
          key: "app.invalid_environment",
          context: {
            :env     => raw,
            :allowed => ENV_ALLOWED_VALUES,
          },
          kind: LowLevelError::Kind::UserInput,
          log_context: {
            :env     => raw,
            :allowed => ENV_ALLOWED_VALUES,
            :source  => Core::Utils.source(__FILE__, __LINE__),
          }
        )
      end
    end

    def self.bootstrap(overrides : PathOverrides = PathOverrides.new) : Nil
      resolved_env = overrides.env || parse_env(nil)
      resolved_paths = PathResolver.resolve(resolved_env, overrides)

      self.env = resolved_env
      self.paths = resolved_paths
    end

    def self.paths! : Paths
      paths.not_nil!
    end

    def self.env! : Env
      env.not_nil!
    end

    def self.config_file : String
      paths!.config_file
    end

    def self.log_file : String
      paths!.log_file
    end

    def self.db_file : String
      paths!.db_file
    end

    def self.ensure_parent_dir(path : String) : Nil
      dir = File.dirname(path)
      Dir.mkdir_p(dir, 0o755) unless Dir.exists?(dir)
    end

    # --------------------------------------------------------------------
    #                       Config application methods
    # --------------------------------------------------------------------
    def self.quotations_websites
      websites = {} of String => Hash(String, String | Int32)
      App.config["quotations"]["websites"].as_h.each do |k, v|
        ks = k.as_s
        websites[ks] = {} of String => String | Int32
        v.as_h.each do |k2, v2|
          k2s = k2.as_s
          if k2s == "key_type"
            websites[ks][k2s] = v2.as_i
          else
            websites[ks][k2s] = v2.as_s
          end
        end
      end
      websites
    end

    def self.border
      case App.config["border"].as_s.downcase
      when "ascii"         then Tablo::Border::PreSet::Ascii
      when "reducedascii"  then Tablo::Border::PreSet::ReducedAscii
      when "reducedmodern" then Tablo::Border::PreSet::ReducedModern
      when "markdown"      then Tablo::Border::PreSet::Markdown
      when "modern"        then Tablo::Border::PreSet::Modern
      when "fancy"         then Tablo::Border::PreSet::Fancy
      when "empty"         then Tablo::Border::PreSet::Empty
      when "blank"         then Tablo::Border::PreSet::Blank
      else                      Tablo::Border::PreSet::Fancy
      end
    end

    def self.money_limits : MoneyLimits
      x = App.config["money"]["risk_rate_min"]
      rrmin = if x.as_s?
                # Core::ZZZConversion.read_decimal_pct(x.as_s, "Minimum risk rate")
                Core::Input.ensure_decimal_pct_valid!(x.as_s, field: "Minimum risk rate")
              else
                x.as_f
              end
      x = App.config["money"]["risk_rate_max"]
      rrmax = if x.as_s?
                # Core::ZZZConversion.read_decimal_pct(x.as_s, "Maximum risk rate")
                Core::Input.ensure_decimal_pct_valid!(x.as_s, field: "Maximum risk rate")
              else
                x.as_f
              end

      MoneyLimits.new(
        risk_rate_min: rrmin,
        risk_rate_max: rrmax,
        target_coeff_min: App.config["money"]["target_coeff_min"].as_f,
        target_coeff_max: App.config["money"]["target_coeff_max"].as_f,
        steps_down_min: App.config["money"]["steps_down_min"].as_i,
        steps_down_max: App.config["money"]["steps_down_max"].as_i
      )
    end

    def self.locale
      "system"
    end

    def self.default_market_universe : String
      App.config["market_data"]["default_universe"].as_s
    end

    def self.tickcheck
      App.config["tickcheck"].as_bool
    end

    def self.quotlife
      App.config["quotlife"].as_f
    end

    def self.diagnostic_steps
      App.config["diagnostic_steps"].as_i
    end

    def self.watchrate
      App.config["watchrate"].as_f
    end

    def self.fees
      {rate: App.config["fees"]["rate"].as_f, min: App.config["fees"]["min"].as_f}
    end

    def self.dedicated_capital
      App.config["trading"]["capital"].as_f
    end

    # --------------------------------------------------------------------
    #                       Initialization : database, conf, log
    # --------------------------------------------------------------------
    def self.db_main_connect(dbfile) : DB::Connection
      connection = DB.connect("sqlite3://#{dbfile}")
      begin
        connection.exec("PRAGMA foreign_keys = ON")
      rescue ex
        connection.close
        raise ex
      end
      connection
    end

    def self.dbcheck(filename)
      if File.exists?(filename)
        if File.empty?(filename)
          raise LowLevelError.new(
            "empty Jedi database file '#{filename}'",
            key: "app.dbfile.empty",
            context: {:filename => filename},
            kind: LowLevelError::Kind::InvalidData,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        else
          begin
            db = DB.open "sqlite3://#{filename}"
            db.query_one("PRAGMA schema_version", as: Int32)
          rescue
            raise LowLevelError.new(
              "invalid SQLite database file '#{filename}'",
              key: "app.dbfile.invalid_sqlite",
              context: {:filename => filename},
              kind: LowLevelError::Kind::InvalidData,
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end

          schema = get_schema(db)
          db.close

          if schema =~ /table.*trade/i &&
             schema =~ /table.*security/i &&
             schema =~ /table.*scale/i &&
             schema =~ /table.*settings/i &&
             schema =~ /table.*operation/i &&
             schema =~ /table.*note/i
            schema_digest = Digest::SHA256.hexdigest(schema)

            if schema_digest == DB_SCHEMA_DIGEST
              connection = db_main_connect(filename).as(DB::Connection)
              schema = get_schema(connection)
              database_sha256 = Digest::SHA256.hexdigest(schema)
              schema_filepath = File.join(File.dirname(App.config_file), "main_#{database_sha256}")
              File.write(schema_filepath, schema) unless File.exists?(schema_filepath)

              config_sha256 = DB_SCHEMA_DIGEST

              if database_sha256 != config_sha256
                puts I18n.t("app.database.schema", schema: "#{schema}")
                raise LowLevelError.new(
                  "Jedi database schema digest mismatch",
                  key: "app.dbfile.mismatch",
                  context: {:database_sha256 => database_sha256,
                            :config_sha256   => config_sha256},
                  kind: LowLevelError::Kind::InvalidData,
                  log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
              end

              connection.as(DB::Connection)
            else
              puts schema
              puts schema_digest
              raise LowLevelError.new(
                "obsolete Jedi database schema in '#{filename}'",
                key: "app.dbfile.not_current",
                context: {:filename => filename},
                kind: LowLevelError::Kind::InvalidData,
                log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
            end
          else
            raise LowLevelError.new(
              "file '#{filename}' is not a Jedi database",
              key: "app.dbfile.not_jedi_database",
              context: {:filename => filename},
              kind: LowLevelError::Kind::InvalidData,
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
        end
      else
        raise LowLevelError.new(
          "Jedi database file not found: #{filename}",
          key: "app.dbfile.not_found",
          context: {:filename => filename},
          kind: LowLevelError::Kind::Domain,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end
    end

    def self.init_stage1
      App.config = YAML.parse(YAML_CONFIG)

      if File.exists?(App.config_file)
        file_config = YAML.parse(File.read(App.config_file))
        unless file_config.raw.nil?
          App.config = deep_merge(App.config, file_config)
        end
      end

      self.capital = App.config["simulation"]["capital"].as_i
      self.distance = App.config["simulation"]["distance"].as_f
      self.risk_rate = App.config["simulation"]["risk_rate"].as_f
      self.initial_investment = ((capital * risk_rate) / distance).to_i
    end

    def self.init_stage2
      config_file = App.config_file
      log_file = App.log_file
      db_file = App.db_file

      config_missing = !File.exists?(config_file)
      log_missing = !File.exists?(log_file)
      db_missing = !File.exists?(db_file)

      yes_char = I18n.t("infra.yes_chars")[0].upcase

      if config_missing
        confirmed = App.confirm(
          I18n.t("app.initialization.conf_file_confirm",
            filename: "#{config_file}"),
          yes_char
        )

        raise_initialization_cancelled! unless confirmed
      end

      if log_missing
        confirmed = App.confirm(
          I18n.t("app.initialization.log_file_confirm",
            filename: "#{log_file}"),
          yes_char
        )

        raise_initialization_cancelled! unless confirmed
      end

      if db_missing
        confirmed = App.confirm(
          I18n.t("app.initialization.data_file_confirm",
            filename: "#{db_file}"),
          yes_char
        )

        raise_initialization_cancelled! unless confirmed
      end

      if config_missing
        ensure_parent_dir(config_file)
        File.touch(config_file)
      end

      if log_missing
        ensure_parent_dir(log_file)
        File.touch(log_file)
      end

      if db_missing
        ensure_parent_dir(db_file)

        conn = db_main_connect(db_file)
        begin
          Database::Main.new(conn).create
        ensure
          conn.close
        end
      end

      App.conn_main = dbcheck(db_file)
      self.conn_memory = db_main_connect("%3Amemory%3A")
    end

    private def self.raise_initialization_cancelled! : NoReturn
      raise LowLevelError.new(
        "application initialization cancelled",
        key: "app.initialization.cancelled",
        context: Context.new,
        kind: LowLevelError::Kind::Domain,
        log_context: {:source => Core::Utils.source(__FILE__, __LINE__)}
      )
    end

    def self.get_schema(conn)
      lines = [] of String
      sql = "select * from sqlite_master;"

      conn.query_each(sql) do |line|
        type = line.read(String)
        name = line.read(String)
        # skip sqlite technical data tables
        next if name =~ /sqlite_/i

        _tbl_name = line.read(String)
        _root_page = line.read(Int64)
        sql = line.read(String)

        to_sort = [] of String
        paren = ""

        new_sql = String.build do |str|
          sql.each_line do |inline|
            if inline =~ /^\s*(\")|(CREATE)/
              str << inline << "\n"
            elsif inline =~ /^ *\)/
              paren = inline
            else
              to_sort << inline.gsub(/ *\(/, "(")
            end
          end

          to_sort.sort!.each_with_index(1) do |sline, ind|
            if ind == to_sort.size
              str << sline.chomp(",") << "\n"
            else
              str << (sline[-1] == ',' ? sline : sline + ",") << "\n"
            end
          end

          unless paren.empty?
            str << paren.gsub(/ +/, "") << "\n"
          end
        end

        line = type == "index" ? "Z#{new_sql}" : new_sql
        lines << line
      end

      lines.sort.map do |line|
        wline = if line[0] == 'Z'
                  line[1..-1]
                else
                  line
                end

        wline.gsub(/\t| +/, " ")
      end.join("\n")
    end

    # --------------------------------------------------------------------
    #                       Display config
    # --------------------------------------------------------------------

    def self.list_paths(io : IO = STDOUT) : Nil
      io.puts "Runtime"
      io.puts "  environment : #{env!.to_s.downcase}"
      io.puts "  config_dir  : #{paths!.config_dir}"
      io.puts "  config_file : #{paths!.config_file}"
      io.puts "  log_dir     : #{paths!.log_dir}"
      io.puts "  log_file    : #{paths!.log_file}"
      io.puts "  data_dir    : #{paths!.data_dir}"
      io.puts "  db_file     : #{paths!.db_file}"
      io.puts "  market_dir  : #{paths!.market_dir}"
    end

    def self.list_params(io : IO = STDOUT) : Nil
      list_paths(io)
      io.puts
      io.puts "Configuration"
      io.puts YAML.dump(App.config)
    end
  end
end
