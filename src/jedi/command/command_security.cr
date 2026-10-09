module Jedi
  class SecuritySubCommand < Command
    @raw_isin : String? = nil
    @raw_name : String? = nil
    @raw_ticker : String? = nil
    @raw_tick_buy : String? = nil
    @raw_tick_sell : String? = nil
    @raw_tax_rate : String? = nil
    @raw_ident : String? = nil
    @raw_field : String? = nil
    @raw_value : String? = nil
    @raw_regex : String? = nil

    def parser_on_security
      subcommands = ["create", "delete", "list", "show", "update"]
      self.command = "security"
      security_parser = OptionParser.new do |parser|
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
            when "update" then update(parser, prefix)
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

      security_parser.parse
      security_run
    end

    private def security_run
      case subcommand
      when "create" then create
      when "delete" then delete
      when "list"   then list
      when "show"   then show
      when "update" then update
      end
    end

    #
    # --------------------- create ---------------------
    #
    private def create(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator I18n.t("infra.required_fields")
      parser.on("--isin=ISIN",
        I18n.t("#{prefix}.isin")) { |v| @raw_isin = v }
      parser.on("--name=NAME",
        I18n.t("#{prefix}.name")) { |v| @raw_name = v }
      parser.on("--ticker=TICKER",
        I18n.t("#{prefix}.ticker")) { |v| @raw_ticker = v }
      parser.separator ""
      parser.separator I18n.t("infra.optional_fields")
      parser.on("--tick-buy=TICK_BUY",
        I18n.t("#{prefix}.tick_buy")) { |v| @raw_tick_buy = v }
      parser.on("--tick-sell=TICK_SELL",
        I18n.t("#{prefix}.tick_sell")) { |v| @raw_tick_sell = v }
      parser.on("--tax-rate=TAX_RATE",
        I18n.t("#{prefix}.tax_rate")) { |v| @raw_tax_rate = v }
      parser.separator ""
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def create
      unless ARGV.size.zero?
        argc = Core::Input.ensure_argument_count!(3, 3,
          key: "infra.positional_arguments")
        @raw_isin, @raw_name, @raw_ticker = ARGV.shift(3)
      end
      isin = Core::Input.ensure_isin_valid!(@raw_isin,
        field: "isin", key: "infra.field_required")
      name = Core::Input.ensure_present!(@raw_name, field: "name")
      ticker = Core::Input.ensure_present!(@raw_ticker, field: "ticker")
      begin
        tick_buy = Exchange::Security::Tick.new(@raw_tick_buy || "0.0001")
      rescue ex : LowLevelError
        if key = ex.key
          raise LowLevelError.new(key: "tick_buy.invalid_value",
            context: ex.context,
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            cause: ex)
        end
        raise ex
      end

      begin
        tick_sell = Exchange::Security::Tick.new(@raw_tick_sell || "0.0001")
      rescue ex : LowLevelError
        if key = ex.key
          raise LowLevelError.new(key: "tick_sell.invalid_value",
            context: ex.context,
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            cause: ex)
        end
        raise ex
      end

      tmp = Core::Input.ensure_string_valid!(@raw_tax_rate || "0.0",
        field: "tax rate", regex: NON_NEGATIVE_DECIMAL_PCT, key: "infra.field_required")
      tax_rate = tmp.ends_with?("%") ? tmp.chomp('%').to_f / 100 : tmp.to_f
      Exchange::SecurityCreator.new(@conn_main).call isin: isin, name: name, ticker: ticker,
        tick_buy: tick_buy, tick_sell: tick_sell, tax: tax_rate
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- delete ---------------------
    #
    private def delete(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator ""
      parser.separator I18n.t("infra.options")
      option_noconfirm(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def delete
      security_ident = ident(Core::Input.ensure_present!(ARGV.shift?,
        field: "Security: id | ISIN"))
      Core::Input.ensure_argv_empty!
      Exchange::SecurityDeleter.new(@conn_main).call ident: security_ident
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
      parser.separator ""
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator I18n.t("infra.options")
      option_extended(parser, I18n.t("#{prefix}.option_extended"))
      option_csv(parser)
      option_headers(parser)
      option_columns(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def list
      regex_as_string = ARGV.shift?
      Core::Input.ensure_argv_empty!
      result = Exchange::SecurityLister.new(@conn_main).call regex_as_string,
        option_extended: option_extended, option_records: option_records,
        option_csv: option_csv, option_headers: option_headers,
        option_running: option_running, option_columns: option_columns
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
      parser.separator ""
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def show
      security_ident = ident(Core::Input.ensure_present!(ARGV.shift?,
        field: "Security: id | ISIN"))
      Core::Input.ensure_argv_empty!
      security = Exchange::Security.new(@conn_main, ident: security_ident)
      result = Exchange::SecurityPresenter.new(security).show
      puts result unless result.empty?
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- update ---------------------
    #
    private def update(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator ""
      parser.separator I18n.t("infra.optional_fields")
      parser.on("--isin=ISIN",
        I18n.t("#{prefix}.isin")) { |v| @raw_isin = v }
      parser.on("--name=NAME",
        I18n.t("#{prefix}.name")) { |v| @raw_name = v }
      parser.on("--ticker=TICKER",
        I18n.t("#{prefix}.ticker")) { |v| @raw_ticker = v }
      parser.on("--tick-buy=TICK_BUY",
        I18n.t("#{prefix}.tick_buy")) { |v| @raw_tick_buy = v }
      parser.on("--tick-sell=TICK_SELL",
        I18n.t("#{prefix}.tick_sell")) { |v| @raw_tick_sell = v }
      parser.on("--tax-rate=TAX_RATE",
        I18n.t("#{prefix}.tax_rate")) { |v| @raw_tax_rate = v }
      parser.separator ""
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def update
      security_ident = ident(Core::Input.ensure_present!(ARGV.shift?,
        field: "Security: id | ISIN"))
      Core::Input.ensure_argv_empty!
      security = Exchange::Security.new(@conn_main, ident: security_ident)
      Exchange::SecurityUpdater.new(security).call isin: @raw_isin, name: @raw_name, ticker: @raw_ticker,
        tick_buy: @raw_tick_buy, tick_sell: @raw_tick_sell, tax: @raw_tax_rate
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end
  end
end
