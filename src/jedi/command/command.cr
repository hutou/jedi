module Jedi
  # Command line interface
  class Command
    # Parser
    private property command : String = ""
    private property subcommand : String = ""
    private property parser_level_1 : String = ""
    private property parser_level_2 : String = ""

    # Global options
    private property option_verbose : Bool = false # = false

    # Command/subcommand options
    # generic options
    private property option_records : String? = nil
    private property option_csv = false
    private property option_headers = false
    private property option_running = false
    private property option_update_now = false
    private property option_columns : String? = nil
    # specific options
    private property option_in_use = false
    private property option_net_stop = false
    private property option_extended = false
    private property option_group = false
    private property option_split : String? = nil
    private property option_sync : String? = nil
    # other options
    private property option_mode : String? = nil
    private property option_force = false
    private property option_money : String? = nil
    private property option_tick_buy : String? = nil
    private property option_tick_sell : String? = nil
    private property option_command : String? = nil
    # private property option_sort : Int32 = 1
    private property option_sort : String? = nil
    private property option_capital : Float64? = nil
    private property option_distance : String? = nil
    private property option_date : String? = nil
    private property option_reinit : String? = nil
    private property option_preset : String? = nil

    protected getter output : IO
    property conn_main

    def initialize(
      @conn_main : DB::Connection,
      @output : IO = STDOUT,
    )
    end

    def run
      commands = %w(
        security quote trade scale settings operation note
        database market tools version config
      )

      raw_command = ""

      main_parser = OptionParser.new do |parser|
        parser.summary_indent = "  "

        # Stop parsing at the first positional argument (= command).
        # Option arguments are not passed to before_each.
        parser.before_each do |arg|
          unless arg.starts_with?('-')
            raw_command = arg
            self.command = resolve_command!(arg, commands)
            parser.stop
          end
        end

        commands.each do |command|
          parser.banner = I18n.t(
            "jedi.banner",
            version: "#{Jedi::VERSION}"
          )

          key = (command =~ /version|config/) ? "jedi." : ""

          parser.on(
            command,
            I18n.t("#{key}#{command}.header")
          ) do
            parser.banner = I18n.t("#{key}#{command}.banner")
            self.command = command
          end

          parser.separator("") if command == "tools"
        end
        parser.separator(I18n.t("jedi.notes"))
        parser.separator(I18n.t("infra.global_options"))
        option_border(parser)

        option_invalid(parser)
        option_missing(parser)
      end

      main_parser.parse

      # A complete command is consumed by OptionParser.
      # An abbreviated command is unknown to OptionParser and therefore remains
      # in ARGV: remove it after it has been resolved.
      if !raw_command.empty? && raw_command != command
        ARGV.shift if ARGV.first? == raw_command
      end

      if x = @option_preset
        if x.starts_with?("-")
          raise_from_low_level LowLevelError.new(
            "a border preset is expected after --border",
            key: "infra.preset_border_expected",
            context: {:preset => "#{@option_preset}"},
            kind: LowLevelError::Kind::UserInput,
            log_context: {
              :source => Core::Utils.source(__FILE__, __LINE__),
            }
          )
        elsif (x = Tablo::Border::PreSet.parse?(x)).nil?
          raise_from_low_level LowLevelError.new(
            "invalid border preset '#{@option_preset}'",
            key: "infra.invalid_preset_border",
            context: {:preset => "#{@option_preset}"},
            kind: LowLevelError::Kind::UserInput,
            log_context: {
              :source => Core::Utils.source(__FILE__, __LINE__),
            }
          )
        else
          Tablo::Config::Defaults.border_definition = x
        end
      end

      # Default output mode
      apply_normal_output_mode!

      if command.empty?
        puts main_parser
        return
      end

      case command
      # Production commands
      when "security"
        SecuritySubCommand.new(@conn_main).parser_on_security
      when "quote"
        QuoteSubCommand.new(@conn_main).parser_on_quote
      when "trade"
        TradeSubCommand.new(@conn_main).parser_on_trade
      when "scale"
        ScaleSubCommand.new(@conn_main).parser_on_scale
      when "settings"
        SettingsSubCommand.new(@conn_main).parser_on_settings
      when "operation"
        OperationSubCommand.new(@conn_main).parser_on_operation
      when "note"
        NoteSubCommand.new(@conn_main).parser_on_note
        # Simulation or special commands
      when "database"
        DatabaseSubCommand.new(
          @conn_main,
          output: output
        ).parser_on_database
      when "market"
        MarketSubCommand.new(
          @conn_main,
          output: output
        ).parser_on_market
      when "tools"
        ToolsSubCommand.new(
          @conn_main,
          output: output
        ).parser_on_tools
        # Other commands
      when "version"
        puts I18n.t(
          "jedi.version.details",
          appname: "#{Path.new(PROGRAM_NAME).basename}",
          version: "#{Jedi::VERSION}",
          tablo: "#{Tablo::VERSION}",
          compile: "#{Crystal::DESCRIPTION.gsub(/\n\n/, "\n")}Commit: #{Jedi::GIT_COMMIT}"
        )
      when "config"
        if ARGV.empty?
          App.list_params
        elsif ARGV[0] == "--paths"
          App.list_paths
        else
          raise_from_low_level LowLevelError.new(
            "invalid config option '#{ARGV[0]}'",
            key: "infra.invalid_option",
            context: {:option => ARGV[0]},
            kind: LowLevelError::Kind::UserInput,
            log_context: {
              :source => Core::Utils.source(__FILE__, __LINE__),
            }
          )
        end
      end
    end

    private def resolve_command!(
      value : String,
      candidates : Array(String),
    ) : String
      # Un nom complet est toujours prioritaire
      return value if candidates.includes?(value)

      matches = candidates.select { |candidate| candidate.starts_with?(value) }

      case matches.size
      when 1
        matches.first
      when 0
        raise_from_low_level LowLevelError.new(
          "unknown command '#{value}'",
          key: "infra.unknown_command",
          context: {:command => value},
          kind: LowLevelError::Kind::UserInput,
          log_context: {
            :source => Core::Utils.source(__FILE__, __LINE__),
          }
        )
      else
        raise_from_low_level LowLevelError.new(
          "ambiguous command '#{value}': #{matches.join(", ")}",
          key: "infra.ambiguous_command",
          context: {
            :command => value,
            :matches => matches.join(", "),
          },
          kind: LowLevelError::Kind::UserInput,
          log_context: {
            :source => Core::Utils.source(__FILE__, __LINE__),
          }
        )
      end
    end

    private def resolve_subcommand!(
      value : String,
      candidates : Array(String),
    ) : String
      if value.starts_with?('-')
        raise_from_low_level LowLevelError.new(
          "option '#{value}' is not allowed before a subcommand",
          key: "infra.options_not_allowed_here",
          context: {:option => value},
          kind: LowLevelError::Kind::UserInput,
          log_context: {
            :source => Core::Utils.source(__FILE__, __LINE__),
          }
        )
      end

      # Un nom complet est toujours prioritaire
      return value if candidates.includes?(value)

      matches = candidates.select { |candidate| candidate.starts_with?(value) }

      case matches.size
      when 1
        matches.first
      when 0
        raise_from_low_level LowLevelError.new(
          "unknown #{command} subcommand '#{value}'",
          key: "infra.unknown_subcommand",
          context: {
            :command    => command,
            :subcommand => value,
          },
          kind: LowLevelError::Kind::UserInput,
          log_context: {
            :source => Core::Utils.source(__FILE__, __LINE__),
          }
        )
      else
        raise_from_low_level LowLevelError.new(
          "ambiguous #{command} subcommand '#{value}': #{matches.join(", ")}",
          key: "infra.ambiguous_subcommand",
          context: {
            :command    => command,
            :subcommand => value,
            :matches    => matches.join(", "),
          },
          kind: LowLevelError::Kind::UserInput,
          log_context: {
            :source => Core::Utils.source(__FILE__, __LINE__),
          }
        )
      end
    end

    private def check_has_contents(field, value)
      if (x = value).nil? || x.empty?
        raise_from_low_level LowLevelError.new(
          "missing contents for '#{field}'",
          key: "infra.contents_missing",
          context: {:field => field},
          kind: LowLevelError::Kind::UserInput,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end
      value.as(String)
    end

    private def argc_check(min = 0, max = 0)
      unless (min..max).includes?(ARGV.size) ||
             (ARGV.size >= min && max.nil?)
        # puts parser_level_2 # subcommand parser (=help)
        raise LowLevelError.new(
          "Number of arguments '#{ARGV.size}' out of bounds (min=#{min}, max=#{max})",
          key: "infra.arg_check_error",
          kind: LowLevelError::Kind::UserInput,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end
      ARGV.size
    end

    private def ident(arg)
      (tmp = arg.to_i64?).nil? ? arg : tmp
    end

    private def help(parser)
      parser.on("-h", "--help", I18n.t("infra.help")) do
        puts parser
        exit
      end
    end

    private def help_cmd
      parts = ["jedi"]
      parts << command unless command.empty?
      parts << subcommand unless subcommand.empty?
      parts << "--help" unless parts == ["jedi"]
      parts.join(" ")
    end

    protected def raise_from_low_level(ex : LowLevelError) : NoReturn
      if ex.kind == LowLevelError::Kind::UserInput
        App.raise_from_low_level(
          ex,
          context: {:cmd => help_cmd},
          help_key: "infra.jedi_help"
        )
      else
        App.raise_from_low_level(ex)
      end
    end

    #
    # System options
    #
    private def option_invalid(parser)
      parser.invalid_option do |option|
        raise_from_low_level LowLevelError.new(
          "invalid option '#{option}'",
          key: "infra.invalid_option",
          context: {:option => "#{option}"},
          kind: LowLevelError::Kind::UserInput,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end
    end

    private def option_missing(parser)
      parser.missing_option do |option|
        raise_from_low_level LowLevelError.new(
          "missing value for option '#{option}'",
          key: "infra.missing_option",
          context: {:option => "#{option}"},
          kind: LowLevelError::Kind::UserInput,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end
    end

    #
    # ----------------------------------------------------------------
    #
    #                 Global options
    #
    # ----------------------------------------------------------------
    #
    private def option_border(parser)
      parser.on("-b", "--border=PRESET",
        I18n.t("infra.border_preset")) do |param|
        @option_preset = param
      end
    end

    private def option_noconfirm(parser)
      parser.on("--noconfirm", I18n.t("infra.noconfirm")) do
        App.noconfirm = true
      end
    end

    private def option_verbose(parser)
      parser.on("-v", "--verbose", I18n.t("infra.verbose")) do
        @option_verbose = true
      end
    end

    private def apply_normal_output_mode! : Nil
      App.apply_output_mode!(
        simulation: false,
        verbose: @option_verbose
      )
    end

    private def apply_simulation_output_mode! : Nil
      App.apply_output_mode!(
        simulation: true,
        verbose: @option_verbose
      )
    end

    #
    # ----------------------------------------------------------------
    #
    #                 Command/subcommand options
    #
    # ----------------------------------------------------------------

    #
    # Non specific options, key in infra
    #

    private def option_records(parser)
      parser.on("-s", "--select=RECORDS", I18n.t("infra.option_records")) { |param|
        self.option_records = param
      }
    end

    private def option_csv(parser)
      parser.on("--csv", I18n.t("infra.option_csv")) {
        self.option_csv = true
      }
    end

    private def option_headers(parser)
      parser.on("--headers", I18n.t("infra.option_headers")) {
        self.option_headers = true
      }
    end

    private def option_running(parser)
      parser.on("-r", "--running", I18n.t("infra.option_running")) {
        self.option_running = true
      }
    end

    private def option_regex(parser)
      parser.on("[regex]", I18n.t("infra.option_regex")) {
        nil
      }
    end

    private def option_update_now(parser)
      parser.on("--update-now", I18n.t("infra.option_update_now")) {
        self.option_update_now = true
      }
    end

    private def option_columns(parser)
      parser.on("-c", "--column-indexes=INDEXES", I18n.t("infra.option_columns")) { |param|
        self.option_columns = param
      }
    end

    private def option_sync(parser)
      parser.on("--sync=POSITION", I18n.t("infra.option_sync")) { |param|
        self.option_sync = param
      }
    end

    private def option_split(parser)
      parser.on("--split=NEW:OLD", I18n.t("infra.option_split")) { |param|
        self.option_split = param
      }
    end

    private def option_reinit(parser)
      parser.on("--reinit=VALUE", I18n.t("infra.option_reinit")) { |param|
        self.option_reinit = param
      }
    end

    private def option_distance(parser)
      parser.on("--distance=COEFFICIENT", I18n.t("infra.option_distance")) { |param|
        self.option_distance = param
      }
    end

    #
    # Specific options, key given in command/subcommand
    #
    private def option_in_use(parser, key)
      parser.on("--in-use", key) { self.option_in_use = true }
    end

    private def option_extended(parser, key)
      parser.on("-x", "--extended", key) { self.option_extended = true }
    end

    private def option_group(parser, key)
      parser.on("-g", "--group", key) { self.option_group = true }
    end

    private def option_money(parser, key)
      parser.on("-m", "--money=DEFSTR", key) { |param|
        self.option_money = param
      }
    end

    private def option_tick_buy(parser, key)
      parser.on("--tick-buy=TICK_VALUE", key) { |param|
        self.option_tick_buy = param
      }
    end

    private def option_tick_sell(parser, key)
      parser.on("--tick-sell=TICK_VALUE", key) { |param|
        self.option_tick_sell = param
      }
    end

    private def option_net_stop(parser, key)
      parser.on("--net-stop", key) { |param|
        self.option_net_stop = true
      }
    end

    private def option_mode(parser, key)
      parser.on("-m", "--mode=MODE", key) { |param|
        self.option_mode = param
      }
    end

    private def option_force(parser, key)
      parser.on("--force", key) { self.option_force = true }
    end

    private def option_command(parser, key)
      parser.on("-c", "--command=COMMANDS", key) { |param|
        self.option_command = param
      }
    end

    #
    # Options to be verified
    #
    private def option_sort(parser, key)
      parser.on("--sort=KEY", key) { |param| self.option_sort = param }
    end

    private def option_capital(parser, command, subcommand)
      parser.on("--capital=AMOUNT",
        I18n.t("jedi.#{command}.#{subcommand}.option_capital")) { |param|
        if (value = param.to_f?).nil?
          raise_from_low_level LowLevelError.new(
            "invalid argument '#{param}' for --capital",
            key: "infra.option_invalid_argument",
            context: {:arg => param, :option => "--capital"},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)}
          )
        end
        self.option_capital = value
      }
    end

    private def option_date(parser)
      parser.on("--date=OP:DATE", I18n.t("infra.option_date")) { |param|
        self.option_date = param
      }
    end

    # private def option_date(parser, command, subcommand)
    #   parser.on("--date=OP:DATE",
    #     I18n.t("jedi.#{command}.#{subcommand}.option_date")) do |name|
    #     # Format and date validity check done in QuoteHistory class
    #     self.option_date = name
    #   end
    # end

    # private def option_date(parser, key)
    #   parser.on("--date=OP:DATE", key) { |name| self.option_date = name }
    # end
  end
end
