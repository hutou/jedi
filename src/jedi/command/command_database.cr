module Jedi
  class DatabaseSubCommand < Command
    def initialize(
      conn_main : DB::Connection,
      *,
      output : IO = STDOUT,
    )
      super(
        conn_main,
        output: output
      )
    end

    def parser_on_database
      subcommands = ["dump", "load", "schema"]
      self.command = "database"
      database_parser = OptionParser.new do |parser|
        parser.summary_indent = "  "
        parser.banner = I18n.t("#{command}.banner")
        subcommands.each do |subcommand|
          prefix = "#{command}.#{subcommand}"
          parser.on(subcommand, I18n.t("#{prefix}.header")) do
            parser.banner = I18n.t("#{prefix}.banner")
            case subcommand
            when "dump"   then dump(parser, prefix)
            when "load"   then load(parser, prefix)
            when "schema" then schema(parser, prefix)
            end
            self.subcommand = subcommand
          end
        end
        option_invalid(parser)
        option_missing(parser)
        self.parser_level_1 = parser.to_s
        parser.separator("")
      end

      if ARGV.empty?
        output.puts parser_level_1
        return
      end

      raw_subcommand = ARGV.first
      resolved_subcommand = resolve_subcommand!(
        raw_subcommand,
        subcommands
      )

      self.subcommand = ARGV[0] = resolved_subcommand

      database_parser.parse
      database_run
    end

    private def database_run
      case @subcommand
      when "dump"   then dump
      when "load"   then load
      when "schema" then schema
      end
    end

    #
    # --------------------- dump ---------------------
    #
    private def dump(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def dump
      argc_check(0, 0)
      Database::Main.new(conn_main).dump(output)
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- load ---------------------
    #
    private def load(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def load
      apply_simulation_output_mode!
      argc_check(1, 1)
      Database::Main.new(conn_main).load(ARGV.shift, output)
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- schema ---------------------
    #
    private def schema(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def schema
      argc_check(0, 0)
      result = Database::Main.new(App.conn_main).schema
      output.puts result unless result.empty?
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end
  end
end
