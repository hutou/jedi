module Jedi
  class QuoteSubCommand < Command
    alias UpdateQuote = Proc(Exchange::Security, String?, String)

    @raw_price : String? = nil

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

    @update_quote : UpdateQuote

    def initialize(
      conn_main : DB::Connection,
      *,
      output : IO = STDOUT,
      update_quote : UpdateQuote? = nil,
    )
      super(conn_main, output: output)
      @update_quote = update_quote || ->(security : Exchange::Security, mode : String?) {
        Exchange::QuoteUpdater.new(security).call(option_mode: mode)
      }
    end

    def parser_on_quote
      subcommands = ["get", "set", "update", "refresh"]
      self.command = "quote"
      quote_parser = OptionParser.new do |parser|
        parser.summary_indent = "  "
        parser.banner = I18n.t("#{command}.banner")
        subcommands.each do |subcommand|
          prefix = "#{command}.#{subcommand}"
          parser.on(subcommand, I18n.t("#{prefix}.header")) do
            parser.banner = I18n.t("#{prefix}.banner")
            case subcommand
            when "get"     then get(parser, prefix)
            when "set"     then set(parser, prefix)
            when "update"  then update(parser, prefix)
            when "refresh" then refresh(parser, prefix)
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

      quote_parser.parse
      quote_run
    end

    private def quote_run
      case subcommand
      when "get"     then get
      when "set"     then set
      when "update"  then update
      when "refresh" then refresh
      end
    end

    #
    # --------------------- get ---------------------
    #
    private def get(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator ""
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def get
      isin = Core::Input.ensure_isin_valid!(ARGV.shift?,
        field: "isin", key: "quote.get.invalid_isin")
      Core::Input.ensure_argv_empty!

      quote = Exchange::QuoteFetcher.new(
        Exchange::QuoteTarget.new(isin: isin)).call
      puts quote.price
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- set ---------------------
    #
    private def set(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator ""
      parser.separator I18n.t("infra.options")
      parser.on("--price=PRICE",
        I18n.t("#{prefix}.price")) { |v| @raw_price = v }
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def set
      security_ident = ident(Core::Input.ensure_present!(ARGV.shift?,
        field: "Security: id | isin"))
      unless ARGV.empty?
        @raw_price = ARGV.shift
        Core::Input.ensure_argv_empty!
      end
      price = Core::Input.ensure_string_valid!(@raw_price,
        field: "price", regex: POSITIVE_DECIMAL, key: "infra.field_required").to_f
      security = Exchange::Security.new(@conn_main, ident: security_ident)
      Exchange::QuoteSetter.new(security).set(price)
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
      parser.separator I18n.t("infra.options")
      option_mode(parser, I18n.t("#{prefix}.option_mode"))
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def update
      security_ident = ident(Core::Input.ensure_present!(ARGV.shift?,
        field: "Security: id | isin"))
      Core::Input.ensure_argv_empty!
      security = Exchange::Security.new(@conn_main, ident: security_ident)
      @update_quote.call(security, option_mode)
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- refresh ---------------------
    #
    private def refresh(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("infra.filters")
      option_regex(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.filters.regex")
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator I18n.t("infra.options")
      option_mode(parser, I18n.t("#{prefix}.option_mode"))
      option_force(parser, I18n.t("#{prefix}.option_force"))
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def refresh
      regex_as_string = ARGV.shift?
      Core::Input.ensure_argv_empty!
      Exchange::QuoteRefresher.new(@conn_main).call regex: regex_as_string,
        option_mode: option_mode, option_force: option_force
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end
  end
end
