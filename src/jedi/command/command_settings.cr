module Jedi
  # class Command
  class SettingsSubCommand < Command
    @raw_date : String? = nil
    @raw_time : String? = nil
    @raw_scale : String? = nil

    def parser_on_settings
      subcommands = ["create", "delete", "list", "show"]
      self.command = "settings"
      settings_parser = OptionParser.new do |parser|
        parser.summary_indent = "  "
        parser.banner = I18n.t("#{command}.banner")
        subcommands.each do |subcommand|
          prefix = "#{command}.#{subcommand}"
          parser.on(subcommand, I18n.t("#{prefix}.header")) do
            parser.banner = I18n.t("#{prefix}.banner")
            case subcommand
            when "create" then create(parser, prefix)
            when "delete" then delete(parser, prefix)
            when "list"   then list(parser, prefix)
            when "show"   then show(parser, prefix)
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
        puts parser_level_1
        return
      end

      raw_subcommand = ARGV.first
      resolved_subcommand = resolve_subcommand!(
        raw_subcommand,
        subcommands
      )

      self.subcommand = ARGV[0] = resolved_subcommand

      settings_parser.parse
      settings_run
    end

    private def settings_run
      case subcommand
      when "create" then create
      when "delete" then delete
      when "list"   then list
      when "show"   then show
      end
    end

    #
    # --------------------- create ---------------------
    #
    private def create(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("infra.required_fields")
      parser.on("--scale=ID",
        I18n.t("#{prefix}.required_scale_id")) { |v| @raw_scale = v }
      parser.on("--scale=NAME",
        I18n.t("#{prefix}.required_scale_name")) { |v| @raw_scale = v }
      parser.on("--date=DATE",
        I18n.t("#{prefix}.required_date")) { |v| @raw_date = v }
      parser.on("--time=TIME",
        I18n.t("#{prefix}.required_time")) { |v| @raw_time = v }
      parser.separator ""
      parser.separator I18n.t("infra.options")
      option_sync(parser)
      parser.separator ""
      option_split(parser)
      parser.separator ""
      option_reinit(parser)
      parser.separator ""
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def create
      trade_ident = ident(Core::Input.ensure_present!(ARGV.shift?,
        field: "Trade: id | name"))

      unless ARGV.size.zero?
        argc = Core::Input.ensure_argument_count!(3, 3,
          key: "infra.positional_arguments")
        @raw_scale, @raw_date, @raw_time = ARGV.shift(argc)
      end
      scale_ident = ident(Core::Input.ensure_present!(@raw_scale,
        field: "Scale: id | name"))
      raw_date = Core::Input.ensure_date_valid!(@raw_date,
        field: "date", key: "infra.field_required")
      raw_time = Core::Input.ensure_time_valid!(@raw_time,
        field: "time", key: "infra.field_required")
      datetime = Time.local(raw_date.year, raw_date.month, raw_date.day,
        raw_time.hour, raw_time.minute, raw_time.second)
      reinit_option =
        begin
          (x = option_reinit).nil? ? nil : TradingSystem::ReInitOption.parse(x)
        rescue ex : LowLevelError
          raise LowLevelError.new(
            key: "settings.invalid_reinit",
            context: {:value => x.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            cause: ex)
        end
      split_option = # begin
        (x = option_split).nil? ? nil : Exchange::Security::Split.new(x)
      # rescue ex : LowLevelError
      #   raise LowLevelError.new(
      #     key: "settings.invalid_split",
      #     context: {:value => x.to_s},
      #     log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
      #     cause: ex)
      # end

      sync_option =
        begin
          (x = option_sync).nil? ? nil : TradingRules::Position.new(x)
        rescue ex : LowLevelError
          raise LowLevelError.new(
            key: "settings.invalid_sync",
            context: {:value => x.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            cause: ex)
        end
      Core::Input.ensure_argv_empty!
      TradingSystem::SettingsCreator.new(conn_main).call trade_ident: trade_ident,
        scale_ident: scale_ident, timestamp: datetime, option_split: split_option,
        option_sync: sync_option, option_reinit: reinit_option
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- delete ---------------------
    #
    private def delete(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator I18n.t("infra.options")
      option_noconfirm(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def delete
      # no argument accepted
      Core::Input.ensure_argv_empty!
      TradingSystem::SettingsDeleter.new(conn_main).call
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- list ---------------------
    #
    private def list(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("infra.filters")
      option_running(parser)
      parser.separator ""
      option_regex(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.filters.regex")
      parser.separator ""
      option_records(parser)
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator I18n.t("infra.options")
      option_group(parser, I18n.t("#{prefix}.option_group"))
      option_columns(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def list
      regex_as_string = ARGV.shift?
      Core::Input.ensure_argv_empty!
      result = TradingSystem::SettingsLister.new(conn_main).call regex: regex_as_string,
        option_records: option_records, option_group: option_group,
        option_columns: option_columns, option_running: option_running
      puts result unless result.empty?
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- show ---------------------
    #
    private def show(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def show
      ident = Core::Input.ensure_string_valid!(ARGV.shift?,
        field: "ident", regex: /\A\d+\z/, key: "infra.field_required").to_i64
      Core::Input.ensure_argv_empty!
      settings = TradingSystem::Settings.new(conn_main, ident: ident)
      result = TradingSystem::SettingsPresenter.new(settings).show
      puts result unless result.empty?
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end
  end
end
