module Jedi
  class TradeSubCommand < Command
    @raw_name : String? = nil
    @raw_security : String? = nil
    @raw_legend : String? = nil
    @raw_money : String? = nil
    @raw_regex : String? = nil
    @raw_tick_buy : String? = nil
    @raw_tick_sell : String? = nil
    @raw_reset_stop : Bool? = nil

    def parser_on_trade
      subcommands = ["create", "delete", "list", "orders", "update",
                     "show", "plot", "status", "results"]
      self.command = "trade"
      trade_parser = OptionParser.new do |parser|
        parser.summary_indent = "  "
        parser.banner = I18n.t("#{command}.banner")
        subcommands.each do |subcommand|
          prefix = "#{command}.#{subcommand}"
          parser.on(subcommand, I18n.t("#{prefix}.header")) do
            parser.banner = I18n.t("#{prefix}.banner")
            case subcommand
            when "create"  then create(parser, prefix)
            when "delete"  then delete(parser, prefix)
            when "list"    then list(parser, prefix)
            when "orders"  then orders(parser, prefix)
            when "update"  then update(parser, prefix)
            when "show"    then show(parser, prefix)
            when "plot"    then plot(parser, prefix)
            when "status"  then status(parser, prefix)
            when "results" then results(parser, prefix)
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

      trade_parser.parse
      trade_run
    end

    private def trade_run
      case subcommand
      when "create"  then create
      when "delete"  then delete
      when "list"    then list
      when "orders"  then orders
      when "update"  then update
      when "show"    then show
      when "plot"    then plot
      when "status"  then status
      when "results" then results
      end
    end

    #
    # --------------------- create ---------------------
    #
    private def create(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator I18n.t("infra.required_fields")
      parser.on("--name=NAME", I18n.t("#{prefix}.name")) { |v| @raw_name = v }
      parser.on("--security=ID", I18n.t("#{prefix}.id")) { |v| @raw_security = v }
      parser.on("--security=ISIN", I18n.t("#{prefix}.isin")) { |v| @raw_security = v }
      parser.separator ""
      parser.separator I18n.t("infra.optional_fields")
      parser.on("--money=MONEY", I18n.t("#{prefix}.money")) { |v| @raw_money = v }
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def create
      unless ARGV.empty?
        if @raw_name.nil? && @raw_security.nil?
          argc = Core::Input.ensure_argument_count!(2, 2,
            key: "infra.positional_arguments")
          @raw_name, @raw_security = ARGV.shift(2)
        end
      end
      # required args
      name = Core::Input.ensure_string_valid!(@raw_name, field: "name",
        regex: ALPHANUM, key: "infra.field_required")
      security_ident = ident(Core::Input.ensure_present!(@raw_security,
        field: "Security(id | isin)"))
      money =
        begin
          TradingSystem::Money.parse(@raw_money)
        rescue ex : LowLevelError
          raise LowLevelError.new(
            key: "trade.invalid_money",
            context: {:money => @raw_money.to_s},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            cause: ex)
        end
      Core::Input.ensure_argv_empty!
      TradingSystem::TradeCreator.new(conn_main).call name: name,
        security_ident: security_ident, money: money
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
      parser.separator I18n.t("infra.options")
      option_noconfirm(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def delete
      trade_ident = ident(Core::Input.ensure_present!(ARGV.shift?,
        field: "Trade: id | name"))
      Core::Input.ensure_argv_empty!
      TradingSystem::TradeDeleter.new(conn_main).call trade_ident
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
      option_csv(parser)
      option_headers(parser)
      option_extended(parser, I18n.t("#{prefix}.option_extended"))
      option_columns(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def list
      regex_as_string = ARGV.shift?
      Core::Input.ensure_argv_empty!
      result = TradingSystem::TradeLister.new(conn_main).call(
        regex: regex_as_string,
        option_records: option_records,
        option_csv: option_csv,
        option_headers: option_headers,
        option_extended: option_extended,
        option_running: option_running,
        option_columns: option_columns)
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
      parser.separator I18n.t("infra.optional_fields")
      parser.on("--name=NAME",
        I18n.t("#{prefix}.name")) { |v| @raw_name = v }
      parser.on("--money=MONEY",
        I18n.t("#{prefix}.money")) { |v| @raw_money = v }
      parser.separator ""
      parser.separator I18n.t("infra.options")
      parser.on("--reset-stop",
        I18n.t("#{prefix}.reset_stop")) { @raw_reset_stop = true }
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def update
      trade_ident = ident(Core::Input.ensure_present!(ARGV.shift?,
        field: "Trade: id | name"))
      Core::Input.ensure_argv_empty!
      trade = TradingSystem::Trade.new(conn_main, ident: trade_ident)
      TradingSystem::TradeUpdater.new(trade).call name: @raw_name,
        money: @raw_money, reset_stop: @raw_reset_stop
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
      trade_ident = ident(Core::Input.ensure_present!(ARGV.shift?,
        field: "Trade: id | name"))
      Core::Input.ensure_argv_empty!
      trade = TradingSystem::Trade.new(conn_main, ident: trade_ident)
      result = TradingSystem::TradePresenter.new(trade).show
      puts result unless result.empty?
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- plot ---------------------
    #
    private def plot(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("infra.options")
      parser.on("-l", "--legend=LEGEND",
        I18n.t("#{prefix}.legend")) { |v| @raw_legend = v }
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def plot
      trade_ident = ident(Core::Input.ensure_present!(ARGV.shift?,
        field: "Trade: id | name", key: "infra.field_required"))
      Core::Input.ensure_argv_empty!
      legend_position = @raw_legend || "bl"
      TradingSystem::TradePlotter.new(conn_main).call trade_ident,
        legend_position
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- orders ---------------------
    #
    private def orders(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("infra.filters")
      option_regex(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.filters.regex")
      parser.separator I18n.t("infra.options")
      option_tick_buy(parser, I18n.t("#{prefix}.option_tick_buy"))
      option_tick_sell(parser, I18n.t("#{prefix}.option_tick_sell"))
      option_net_stop(parser, I18n.t("#{prefix}.option_net_stop"))
      option_update_now(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def orders
      regex = ARGV.shift?
      Core::Input.ensure_argv_empty!
      result = TradingSystem::TradeOrders.new(conn_main).list regex: regex,
        option_net_stop: option_net_stop, option_update_now: option_update_now,
        option_tick_buy: (x = option_tick_buy).nil? ? nil : Exchange::Security::Tick.new(x).value,
        option_tick_sell: (x = option_tick_sell).nil? ? nil : Exchange::Security::Tick.new(x).value
      puts result unless result.empty?
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- status ---------------------
    #
    private def status(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("infra.filters")
      option_regex(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.filters.regex")
      parser.separator I18n.t("infra.options")
      option_update_now(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def status
      regex = ARGV.shift?
      Core::Input.ensure_argv_empty!
      result = TradingSystem::TradeStatus.new(conn_main).list regex: regex,
        option_update_now: option_update_now
      puts result unless result.empty?
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- results ---------------------
    #
    private def results(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("infra.filters")
      option_regex(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.filters.regex")
      option_running(parser)
      parser.separator ""
      parser.separator I18n.t("infra.options")
      option_update_now(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def results
      regex = ARGV.shift?
      Core::Input.ensure_argv_empty!
      result = TradingSystem::TradeResults.new(conn_main).list regex: regex,
        option_running: option_running, option_update_now: option_update_now
      puts result unless result.empty?
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end
  end
end
