module Jedi
  class MarketSubCommand < Command
    SUBCOMMANDS = [
      "init", "import", "replace", "update", "sync-group",
      "group", "info", "list", "quote",
    ]

    @option_universe : String? = nil
    @option_date_order : String? = nil
    @option_year_pivot : Int32 = 70
    @option_from : String? = nil
    @option_as_of : String? = nil
    @option_reference_source : String? = nil
    @option_dataset : String? = nil
    @option_allow_gap : Bool = false
    @option_group_add : Bool = false
    @option_group_remove : Bool = false
    @option_last_quote : Bool = false

    @current_operation : String = ""
    @current_source : String = ""
    @current_dataset : String = ""

    def initialize(
      conn_main : DB::Connection,
      *,
      output : IO = STDOUT,
    )
      super(conn_main, output: output)
    end

    def parser_on_market : Nil
      self.command = "market"

      market_parser = OptionParser.new do |parser|
        parser.summary_indent = "  "
        parser.banner = I18n.t("#{command}.banner")

        SUBCOMMANDS.each do |market_subcommand|
          key = subcommand_key(market_subcommand)
          prefix = "#{command}.#{key}"

          parser.on(market_subcommand, I18n.t("#{prefix}.header")) do
            parser.banner = I18n.t("#{prefix}.banner")
            case market_subcommand
            when "init"       then init(parser, prefix)
            when "import"     then import_dataset(parser, prefix)
            when "replace"    then replace(parser, prefix)
            when "update"     then update(parser, prefix)
            when "sync-group" then sync_group(parser, prefix)
            when "group"      then group(parser, prefix)
            when "info"       then info(parser, prefix)
            when "list"       then list(parser, prefix)
            when "quote"      then quote(parser, prefix)
            end
            self.subcommand = market_subcommand
            self.parser_level_2 = parser.to_s
          end
        end

        option_invalid(parser)
        option_missing(parser)
        self.parser_level_1 = parser.to_s
        parser.separator ""
      end

      if ARGV.empty?
        output.puts parser_level_1
        return
      end

      resolved_subcommand = resolve_subcommand!(ARGV.first, SUBCOMMANDS)
      self.subcommand = ARGV[0] = resolved_subcommand

      market_parser.parse
      market_run
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    private def market_run : Nil
      @current_operation = subcommand

      case subcommand
      when "init"       then present_report(init)
      when "import"     then present_report(import_dataset)
      when "replace"    then present_report(replace)
      when "update"     then present_report(update)
      when "sync-group" then present_report(sync_group)
      when "group"      then group
      when "info"       then output.puts MarketData::MarketInfoPresenter.new(info).to_s
      when "list"       then output_result(list)
      when "quote"      then output_result(quote)
      end

      App.flush_messages
    rescue ex : LowLevelError
      raise_from_low_level(market_low_level_error(ex))
    end

    #
    # --------------------- init ---------------------
    #
    private def init(parser : OptionParser, prefix : String) : Nil
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("infra.options")
      option_market_universe(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def init : MarketData::ImportReport
      argc_check(1, 1)
      database = market_database(ARGV.shift)
      MarketData::MarketInitializer.new(database).run
    end

    #
    # --------------------- import ---------------------
    #
    private def import_dataset(parser : OptionParser, prefix : String) : Nil
      dataset_import_parser(parser, prefix)
    end

    private def import_dataset : MarketData::ImportReport
      database, dataset, quotes_filename, labels_filename = dataset_import_arguments

      MarketData::MarketImporter.new(
        database,
        dataset,
        quotes_filename,
        labels_filename,
        from_date: from_date,
        date_order: date_order,
        year_pivot: @option_year_pivot
      ).run
    end

    #
    # --------------------- replace ---------------------
    #
    private def replace(parser : OptionParser, prefix : String) : Nil
      dataset_import_parser(parser, prefix, noconfirm: true)
    end

    private def replace : MarketData::ImportReport?
      database, dataset, quotes_filename, labels_filename = dataset_import_arguments

      unless replace_confirmed?(database, dataset)
        App.info(key: "infra.cancelled")
        return nil
      end

      MarketData::MarketReplacer.new(
        database,
        dataset,
        quotes_filename,
        labels_filename,
        from_date: from_date,
        date_order: date_order,
        year_pivot: @option_year_pivot
      ).run
    end

    #
    # --------------------- update ---------------------
    #
    private def update(parser : OptionParser, prefix : String) : Nil
      dataset_import_parser(parser, prefix, allow_gap: true)
    end

    private def update : MarketData::ImportReport
      database, dataset, quotes_filename, labels_filename = dataset_import_arguments

      MarketData::DatasetUpdater.new(
        database,
        dataset,
        quotes_filename,
        labels_filename,
        from_date: from_date,
        date_order: date_order,
        year_pivot: @option_year_pivot,
        allow_gap: @option_allow_gap
      ).run
    end

    #
    # --------------------- sync-group ---------------------
    #
    private def sync_group(parser : OptionParser, prefix : String) : Nil
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("infra.options")
      option_market_universe(parser)
      option_market_as_of(parser)
      option_market_reference_source(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def sync_group : MarketData::ImportReport
      argc_check(3, 3)
      source = ARGV.shift
      group_code = market_group_code(ARGV.shift?)
      filename = ARGV.shift
      database = market_database(source)

      MarketData::GroupSynchronizer.new(
        database,
        group_code,
        filename,
        @option_reference_source,
        as_of
      ).run
    end

    #
    # --------------------- group ---------------------
    #
    private def group(parser : OptionParser, prefix : String) : Nil
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("infra.options")
      option_market_universe(parser)
      option_market_group_add(parser)
      option_market_group_remove(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def group : Nil
      argc_check(3, 3)
      source = ARGV.shift
      group_code = market_group_code(ARGV.shift?)
      isin = Core::Input.ensure_isin_valid!(
        ARGV.shift,
        field: "isin",
        key: "infra.field_required"
      )
      database = market_database(source)

      if @option_group_add == @option_group_remove
        raise LowLevelError.new(
          "exactly one of --add or --remove is required",
          key: "market.group.one_action_required",
          kind: LowLevelError::Kind::UserInput,
          log_context: {
            :option_add    => @option_group_add.to_s,
            :option_remove => @option_group_remove.to_s,
            :source        => Core::Utils.source(__FILE__, __LINE__),
          }
        )
      end

      member = @option_group_add
      result = MarketData::GroupMembershipUpdater.new(
        database,
        group_code,
        isin,
        member
      ).run

      App.info(
        key: "market.group.updated",
        params: {
          :isin       => result.security.isin,
          :ticker     => result.security.ticker,
          :group      => result.group.code,
          :membership => I18n.t(
            member ? "market.group.member" : "market.group.not_member"
          ),
        }
      )
    end

    #
    # --------------------- info ---------------------
    #
    private def info(parser : OptionParser, prefix : String) : Nil
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("infra.options")
      option_market_universe(parser)
      option_market_dataset(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def info : MarketData::MarketInfoReport
      argc_check(1, 1)
      database = market_database(ARGV.shift, dataset: @option_dataset)
      MarketData::MarketInfo.new(database, @option_dataset).run
    end

    #
    # --------------------- list ---------------------
    #
    private def list(parser : OptionParser, prefix : String) : Nil
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("infra.filters")
      option_regex(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.filters.regex")
      parser.separator I18n.t("infra.options")
      option_market_universe(parser)
      option_market_dataset(parser)
      option_market_last_quote(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def list : String
      argc_check(1, 2)
      source = ARGV.shift
      regex = ARGV.shift?
      database = market_database(source, dataset: @option_dataset)

      MarketData::MarketSecurityLister.new(
        database,
        @option_dataset,
        regex,
        last_quote: @option_last_quote
      ).run
    end

    #
    # --------------------- quote ---------------------
    #
    private def quote(parser : OptionParser, prefix : String) : Nil
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("infra.options")
      option_market_universe(parser)
      option_records(parser)
      option_date(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def quote : String
      argc_check(2, 2)
      source = ARGV.shift
      isin = Core::Input.ensure_isin_valid!(
        ARGV.shift,
        field: "isin",
        key: "infra.field_required"
      )
      database = market_database(source)
      selection = MarketData::HistorySelection.from_options(
        option_records,
        option_date
      )

      MarketData::MarketQuoteLister.new(database, isin, selection).run
    end

    #
    # --------------------- shared command helpers ---------------------
    #
    private def dataset_import_parser(
      parser : OptionParser,
      prefix : String,
      *,
      allow_gap : Bool = false,
      noconfirm : Bool = false,
    ) : Nil
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("infra.options")
      option_market_universe(parser)
      option_market_date_order(parser)
      option_market_year_pivot(parser)
      option_market_from(parser)
      option_market_allow_gap(parser) if allow_gap
      option_noconfirm(parser) if noconfirm
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def dataset_import_arguments : {MarketData::Database, String, String, String}
      argc_check(4, 4)
      source = ARGV.shift
      dataset = ARGV.shift
      quotes_filename = ARGV.shift
      labels_filename = ARGV.shift
      database = market_database(source, dataset: dataset)
      {database, dataset, quotes_filename, labels_filename}
    end

    private def market_universe : String
      @option_universe || App.default_market_universe
    end

    private def market_database(
      source : String,
      *,
      dataset : String? = nil,
    ) : MarketData::Database
      @current_source = source
      @current_dataset = dataset || ""
      MarketData::Database.new(source, market_universe)
    end

    private def present_report(report : MarketData::ImportReport?) : Nil
      return if report.nil?
      output.puts MarketData::MarketReportPresenter.new(report).to_s
    end

    private def output_result(result : String) : Nil
      output.puts result unless result.empty?
    end

    private def replace_confirmed?(
      database : MarketData::Database,
      dataset : String,
    ) : Bool
      return true if App.noconfirm?

      App.confirm(
        I18n.t(
          "market.replace.confirm",
          {
            database: database.filename,
            dataset:  dataset,
          }
        ),
        I18n.t("infra.no_chars")[0].upcase
      )
    end

    private def date_order : MarketData::DateOrder?
      case value = @option_date_order.try(&.downcase)
      when nil, "auto" then nil
      when "ymd"       then MarketData::DateOrder::Ymd
      when "dmy"       then MarketData::DateOrder::Dmy
      when "mdy"       then MarketData::DateOrder::Mdy
      else
        raise LowLevelError.new(
          "invalid date order '#{value}'",
          key: "market.invalid_date_order",
          context: {:value => value.to_s},
          kind: LowLevelError::Kind::UserInput,
          log_context: {
            :option => "--date-order",
            :value  => value.to_s,
            :source => Core::Utils.source(__FILE__, __LINE__),
          }
        )
      end
    end

    private def from_date : Time?
      parse_iso_date(@option_from, "market.invalid_from", "--from")
    end

    private def as_of : Time?
      parse_iso_date(@option_as_of, "market.invalid_as_of", "--as-of")
    end

    private def market_group_code(value : String?) : String
      MarketData::GroupSynchronizer.normalize_group_code!(value)
    end

    private def parse_iso_date(
      value : String?,
      key : String,
      option : String,
    ) : Time?
      return nil unless value
      Time.parse_utc(value, "%F")
    rescue ex
      raise LowLevelError.new(
        "invalid ISO date '#{value}' for #{option}",
        key: key,
        context: {:value => value.to_s},
        kind: LowLevelError::Kind::UserInput,
        log_context: {
          :option => option,
          :value  => value.to_s,
          :source => Core::Utils.source(__FILE__, __LINE__),
        },
        cause: ex
      )
    end

    #
    # --------------------- exception mapping ---------------------
    #
    private def market_low_level_error(ex : LowLevelError) : LowLevelError
      return ex if ex.key

      source = @current_source.empty? ? "?" : @current_source
      database = ex.log_context[:filename]? ||
                 "#{source}_#{market_universe}.db"
      error_code = ex.log_context[:error_code]?

      log_context = ex.log_context.dup
      log_context[:operation] = @current_operation
      log_context[:market_source] = source
      log_context[:market_universe] = market_universe
      unless @current_dataset.empty?
        log_context[:dataset_code] = @current_dataset
      end

      case error_code
      when "database_exists"
        LowLevelError.new(
          "market database already exists",
          key: "market.database_already_exists",
          context: {:database => database},
          kind: LowLevelError::Kind::Domain,
          log_context: log_context,
          cause: ex
        )
      when "dataset_exists"
        LowLevelError.new(
          "market dataset already exists",
          key: "market.dataset_already_exists",
          context: {
            :database => database,
            :dataset  => @current_dataset,
          },
          kind: LowLevelError::Kind::Domain,
          log_context: log_context,
          cause: ex
        )
      when "dataset_not_found"
        dataset = ex.log_context[:dataset_code]? || @current_dataset

        LowLevelError.new(
          "market dataset not found",
          key: "market.dataset_not_found",
          context: {
            :database => database,
            :dataset  => dataset,
          },
          kind: LowLevelError::Kind::Domain,
          log_context: log_context,
          cause: ex
        )
      when "dataset_gap"
        LowLevelError.new(
          "market dataset update would create a history gap",
          key: "market.dataset_gap",
          context: {
            :dataset      => ex.log_context[:dataset_code]? || @current_dataset,
            :last_date    => ex.log_context[:last_date]? || "?",
            :first_date   => ex.log_context[:first_date]? || "?",
            :gap_days     => ex.log_context[:gap_days]? || "?",
            :max_gap_days => ex.log_context[:max_gap_days]? || "?",
          },
          kind: LowLevelError::Kind::Domain,
          log_context: log_context,
          cause: ex
        )
      when "group_not_found"
        LowLevelError.new(
          "market group not found",
          key: "market.group_not_found",
          context: {:group => ex.log_context[:group_code]? || "?"},
          kind: LowLevelError::Kind::Domain,
          log_context: log_context,
          cause: ex
        )
      when "invalid_group_code"
        LowLevelError.new(
          "invalid market group code",
          key: "market.invalid_group",
          context: {:group => ex.log_context[:group_code]? || "?"},
          kind: LowLevelError::Kind::UserInput,
          log_context: log_context,
          cause: ex
        )
      else
        operation = I18n.t(
          "market.operations.#{subcommand_key(@current_operation)}"
        )

        LowLevelError.new(
          "market command failed",
          key: "market.operation_failed",
          context: {
            :operation => operation,
            :database  => database,
          },
          kind: LowLevelError::Kind::Technical,
          log_context: log_context,
          cause: ex
        )
      end
    end

    private def subcommand_key(value : String) : String
      value.gsub('-', '_')
    end

    #
    # --------------------- options ---------------------
    #
    private def option_market_universe(parser : OptionParser) : Nil
      parser.on(
        "--universe=NAME",
        I18n.t("market.options.universe", universe: App.default_market_universe),
      ) do |value|
        @option_universe = value
      end
    end

    private def option_market_date_order(parser : OptionParser) : Nil
      parser.on("--date-order=ORDER", I18n.t("market.options.date_order")) do |value|
        @option_date_order = value
      end
    end

    private def option_market_year_pivot(parser : OptionParser) : Nil
      parser.on("--year-pivot=NN", I18n.t("market.options.year_pivot")) do |value|
        pivot = value.to_i?

        unless pivot && (0..99).includes?(pivot)
          raise LowLevelError.new(
            "invalid two-digit year pivot '#{value}'",
            key: "market.invalid_year_pivot",
            context: {:value => value},
            kind: LowLevelError::Kind::UserInput,
            log_context: {
              :option => "--year-pivot",
              :value  => value,
              :source => Core::Utils.source(__FILE__, __LINE__),
            }
          )
        end

        @option_year_pivot = pivot
      end
    end

    private def option_market_from(parser : OptionParser) : Nil
      parser.on("--from=DATE", I18n.t("market.options.from")) do |value|
        @option_from = value
      end
    end

    private def option_market_allow_gap(parser : OptionParser) : Nil
      parser.on("--allow-gap", I18n.t("market.options.allow_gap")) do
        @option_allow_gap = true
      end
    end

    private def option_market_as_of(parser : OptionParser) : Nil
      parser.on("--as-of=DATE", I18n.t("market.options.as_of")) do |value|
        @option_as_of = value
      end
    end

    private def option_market_reference_source(parser : OptionParser) : Nil
      parser.on(
        "--reference-source=NAME",
        I18n.t("market.options.reference_source")
      ) do |value|
        @option_reference_source = value
      end
    end

    private def option_market_group_add(parser : OptionParser) : Nil
      parser.on("--add", I18n.t("market.options.group_add")) do
        @option_group_add = true
      end
    end

    private def option_market_group_remove(parser : OptionParser) : Nil
      parser.on("--remove", I18n.t("market.options.group_remove")) do
        @option_group_remove = true
      end
    end

    private def option_market_dataset(parser : OptionParser) : Nil
      parser.on("--dataset=CODE", I18n.t("market.options.dataset")) do |value|
        @option_dataset = value
      end
    end

    private def option_market_last_quote(parser : OptionParser) : Nil
      parser.on("--last-quote", I18n.t("market.options.last_quote")) do
        @option_last_quote = true
      end
    end
  end
end
