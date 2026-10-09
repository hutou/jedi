module Jedi
  class ToolsSubCommand < Command
    private property option_minimum_quantity : Int32? = nil
    private property option_operability_steps : Int32? = nil
    private property option_execution : String? = nil
    private property option_opening_day_orders : String? = nil
    private property option_scale : String? = nil
    private property option_amount : Float64? = nil
    private property option_candidate_price : Float64? = nil
    private property option_plot_legend : String? = nil
    private property option_quote_database : String? = nil
    private property option_quote_universe : String? = nil
    private property option_quote_security : String? = nil
    private property option_profile_securities : Array(String) = [] of String
    private property option_profile_dataset : String? = nil
    private property option_profile_group : String? = nil
    private property option_profile_sort : String? = nil
    private property option_profile_rank_criteria : Int32? = nil
    private property option_profile_limit : Int32? = nil
    private property option_profile_include_rejected : Bool = false
    private property option_score_ranking : String = "raw"
    private property option_score_search : String = "adaptive"
    private property option_score_budget : Int32? = nil
    private property option_score_display : String = "compact"
    private property option_backtest_display : String = "compact"

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

    def parser_on_tools
      subcommands = ["calc", "play", "backtest", "candidate", "score", "plot", "stats", "profile"]
      self.command = "tools"
      tools_parser = OptionParser.new do |parser|
        parser.summary_indent = "  "
        parser.banner = I18n.t("#{command}.banner")
        subcommands.each do |subcommand|
          prefix = "#{command}.#{subcommand}"
          parser.on(subcommand, I18n.t("#{prefix}.header")) do
            parser.banner = I18n.t("#{prefix}.banner")
            case subcommand
            when "calc"      then calc(parser, prefix)
            when "play"      then play(parser, prefix)
            when "backtest"  then backtest(parser, prefix)
            when "candidate" then candidate(parser, prefix)
            when "score"     then score(parser, prefix)
            when "plot"      then plot(parser, prefix)
            when "stats"     then stats(parser, prefix)
            when "profile"   then profile(parser, prefix)
            end
            self.subcommand = subcommand
            # self.parser_level_2 = parser.to_s
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

      tools_parser.parse
      tools_run
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    private def tools_run
      case subcommand
      when "calc"      then calc
      when "play"      then play
      when "backtest"  then backtest
      when "candidate" then candidate
      when "score"     then score
      when "plot"      then plot
      when "stats"     then stats
      when "profile"   then profile
      end
    end

    #
    # --------------------- calc ---------------------
    #
    private def calc(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("#{prefix}.params")
      parser.separator ""
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def calc
      apply_simulation_output_mode!
      key = Core::Input.ensure_string_valid!(ARGV.shift?, field: "key",
        regex: /^(kcb|kcp|ksp|spe|cpe|quantity|price)$/,
        key: "#{command}.#{subcommand}.missing_function")
      result = Tools::Calc.new(conn_main, App.conn_memory).run key, ARGV
      output_result(result)
      App.flush_messages
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- play ---------------------
    #
    private def play(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator ""
      option_command(parser, I18n.t("#{prefix}.option_command"))
      parser.separator I18n.t("infra.options")
      option_verbose(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def play
      apply_simulation_output_mode!
      play_ident = ident(Core::Input.ensure_present!(ARGV.shift?,
        field: "Play: Operation id | environment settings"))
      cmd = Core::Input.decode_commands((x = option_command).nil? ? "o" : x)
      result = Tools::Play.new(conn_main, App.conn_memory, play_ident, ARGV)
        .run option_command: cmd
      output_result(result)
      App.flush_messages
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- backtest ---------------------
    #
    private def backtest(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.positional_arguments")
      parser.separator ""
      parser.separator I18n.t("#{prefix}.source_options")
      option_quote_source(parser, subcommand)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.definition_options")
      option_scale(parser)
      option_money(parser, I18n.t("#{prefix}.option_money"))
      parser.separator ""
      parser.separator I18n.t("#{prefix}.history_options")
      option_date(parser)
      option_records(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.sizing_options")
      option_candidate_capital(parser, I18n.t("#{prefix}.option_capital"), error_key: "tools.backtest.invalid_capital")
      option_distance(parser)
      option_minimum_quantity(parser)
      option_operability_steps(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.execution_options")
      option_execution(parser)
      option_opening_day_orders(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.output_options")
      option_backtest_display(parser)
      # option_command(parser, command, subcommand)
      option_command(parser, I18n.t("#{prefix}.option_command"))
      parser.separator ""
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def backtest
      App.simulation = SimulationMode::FromSeed
      apply_simulation_output_mode!
      quote_input, scaledef, money = backtest_arguments
      default_commands = option_backtest_display == "technical" ? "rf" : "r"
      commands = Core::Input.decode_commands(option_command || default_commands)
      # distance = option_distance.nil? ? nil : Core::ZZZConversion.read_decimal_pct(option_distance, "distance")
      distance =
        if option_distance.nil?
          nil
        else
          Core::Input.ensure_decimal_pct_valid!(option_distance, field: "distance")
          # x = Core::Input.ensure_string_valid!(option_distance, field: "distance",
          #   regex: POSITIVE_DECIMAL_PCT, key: "infra.field_required")
          # x.ends_with?('%') ? x.chomp('%').to_f / 100 : x.to_f
        end
      if distance && distance > 0.5
        raise LowLevelError.new(
          "backtest distance '#{distance}' exceeds 0.5",
          key: "tools.backtest.distance_too_large",
          context: {:max => "0.5"},
          kind: LowLevelError::Kind::UserInput,
          log_context: {
            :distance => distance.to_s,
            :source   => Core::Utils.source(__FILE__, __LINE__),
          }
        )
      end

      result = Tools::BackTest.new(
        conn_main,
        App.conn_memory,
        quote_input: quote_input,
        scaledef: scaledef,
        money: money,
      ).run(
        option_command: commands,
        option_records: option_records,
        option_capital: option_capital,
        option_distance: distance,
        option_date: option_date,
        option_minimum_quantity: option_minimum_quantity,
        option_operability_steps: option_operability_steps,
        option_execution: option_execution,
        option_opening_day_orders: option_opening_day_orders,
        option_display: option_backtest_display,
      )
      output_result(result)
      App.flush_messages
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- candidate ---------------------
    #
    private def candidate(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.positional_arguments")
      parser.separator ""
      parser.separator I18n.t("#{prefix}.definition_options")
      option_scale(parser)
      option_candidate_price(parser, I18n.t("#{prefix}.option_price"))
      option_amount(parser, I18n.t("#{prefix}.option_amount"))
      option_money(parser, I18n.t("#{prefix}.option_money"))
      option_candidate_capital(parser, I18n.t("#{prefix}.option_capital"))
      option_minimum_quantity(parser)
      option_operability_steps(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.output_options")
      option_extended(parser, I18n.t("#{prefix}.option_extended"))
      parser.separator ""
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def candidate : Nil
      apply_normal_output_mode!
      argc_check(1, 1)
      isin = ARGV.shift
      scaledef = required_scale
      money = begin
        TradingSystem::Money.parse(option_money)
      rescue ex : LowLevelError
        if ex.kind.in?({LowLevelError::Kind::InvalidData, LowLevelError::Kind::Technical})
          raise ex
        end

        raise LowLevelError.new(
          "invalid capital-management definition '#{option_money}'",
          key: "tools.candidate.invalid_money",
          context: {:money => option_money.to_s},
          kind: LowLevelError::Kind::UserInput,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          cause: ex,
        )
      end

      result = Tools::Candidate.new(conn_main, App.conn_memory).run(
        isin: isin,
        price: option_candidate_price,
        scaledef: scaledef,
        amount: option_amount,
        money: money,
        capital: option_capital,
        minimum_quantity: option_minimum_quantity ||
                          TradingSystem::OrderEngine::WARNING_QUANTITY_THRESHOLD,
        operability_steps: option_operability_steps || App.diagnostic_steps,
        extended: option_extended,
      )
      output_result(result)
      App.flush_messages
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- score ---------------------
    #
    private def score(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      option_date(parser)
      option_records(parser)
      option_quote_source(parser, subcommand)
      # option_sort(parser, command, subcommand)
      option_sort(parser, I18n.t("#{prefix}.option_sort"))
      option_score_ranking(parser)
      option_score_search(parser)
      option_score_budget(parser)
      option_score_display(parser)
      help(parser)
    end

    private def score
      App.simulation = SimulationMode::FromSeed
      apply_simulation_output_mode!
      quote_input, builder = scoring_arguments
      self.option_records ||= "l750"
      self.option_sort ||= "fitness"
      optsort = score_sort(option_sort.not_nil!)
      result = Tools::Scoring.new(
        conn_main,
        App.conn_memory,
        quote_input: quote_input,
        builder: builder,
      ).run(
        option_sort: optsort,
        option_records: option_records,
        option_date: option_date,
        option_ranking: option_score_ranking,
        option_search: option_score_search,
        option_budget: option_score_budget,
        option_display: option_score_display,
      )
      output_result(result)
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    private def score_sort(value : String) : Int32
      case value.downcase
      when "fitness", "1"
        1
      when "activity", "2"
        2
      when "investment", "3"
        3
      else
        raise LowLevelError.new(
          "invalid score sort '#{value}'",
          key: "tools.score.invalid_sort",
          context: {:value => value},
          kind: LowLevelError::Kind::UserInput,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
        )
      end
    end

    #
    # --------------------- plot ---------------------
    #
    private def plot(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.positional_arguments")
      parser.separator ""
      parser.separator I18n.t("#{prefix}.source_options")
      option_quote_source(parser, subcommand)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.history_options")
      option_date(parser)
      option_records(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.display_options")
      option_plot_legend(parser)
      parser.separator ""
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def plot
      quote_input = single_quote_input
      Tools::Plot.new(
        quote_input: quote_input,
        position: option_plot_legend || "",
      ).run(
        option_records: option_records,
        option_date: option_date,
      )
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- stats ---------------------
    #
    private def stats(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.positional_arguments")
      parser.separator ""
      parser.separator I18n.t("#{prefix}.source_options")
      option_quote_source(parser, subcommand)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.history_options")
      option_date(parser)
      option_records(parser)
      parser.separator ""
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def stats
      quote_input = single_quote_input
      result = Tools::Statistics.new(quote_input: quote_input).run(
        option_records: option_records,
        option_date: option_date,
      )
      output_result(result)
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- profile ---------------------
    #
    private def profile(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.positional_arguments")
      parser.separator ""
      parser.separator I18n.t("#{prefix}.source_options")
      parser.on(
        "--database=SOURCE",
        I18n.t("#{prefix}.option_database"),
      ) do |value|
        self.option_quote_database = value
      end
      parser.on(
        "--universe=NAME",
        I18n.t(
          "#{prefix}.option_universe",
          universe: App.default_market_universe,
        ),
      ) do |value|
        self.option_quote_universe = value
      end
      parser.on(
        "--security=IDENT",
        I18n.t("#{prefix}.option_security"),
      ) do |value|
        option_profile_securities << value
      end
      parser.on(
        "--dataset=CODE",
        I18n.t("#{prefix}.option_dataset"),
      ) do |value|
        self.option_profile_dataset = value
      end
      parser.separator ""
      parser.separator I18n.t("#{prefix}.selection_options")
      option_profile_group(parser, I18n.t("#{prefix}.option_group"))
      option_profile_include_rejected(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.history_options")
      option_date(parser)
      option_records(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.output_options")
      option_profile_sort(parser)
      option_profile_rank_criteria(parser)
      option_profile_limit(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator ""
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def profile : Nil
      apply_simulation_output_mode!

      if source = option_quote_database
        argc_check(0, 0)
        run_database_profile(source)
      else
        run_file_profile
      end
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    private def run_file_profile : Nil
      if option = profile_database_only_option
        raise LowLevelError.new(
          "profile option '#{option}' requires a market database",
          key: "tools.profile.collection.option_requires_database",
          context: {:option => option},
          kind: LowLevelError::Kind::UserInput,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
        )
      end

      reject_profile_collection_options!
      argc_check(1, 1)
      output_result(
        Tools::Profile.new(ARGV.shift).run(
          option_records: option_records,
          option_date: option_date,
        )
      )
    end

    private def run_database_profile(source : String) : Nil
      dataset = option_profile_dataset
      securities = option_profile_securities
      ensure_profile_source_compatible!(dataset, securities)

      run_profile_default(
        source,
        dataset: dataset,
        securities: securities,
      )
    end

    private def run_profile_default(
      source : String,
      *,
      dataset : String?,
      securities : Array(String),
    ) : Nil
      if dataset
        run_profile_collection(
          source,
          dataset: dataset,
          securities: [] of String,
        )
      elsif securities.empty? && option_profile_group
        run_profile_collection(
          source,
          dataset: nil,
          securities: [] of String,
        )
      elsif securities.size == 1
        run_profile_single_security(source, securities.first)
      elsif securities.size > 1
        run_profile_collection(
          source,
          dataset: nil,
          securities: securities,
        )
      else
        raise LowLevelError.new(
          "a profile selection is required",
          key: "tools.profile.collection.selection_required",
          kind: LowLevelError::Kind::UserInput,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
        )
      end
    end

    private def run_profile_single_security(source : String, security : String) : Nil
      reject_profile_collection_options!
      input = database_quote_history_input(source, security)
      output_result(
        Tools::Profile.new(quote_input: input).run(
          option_records: option_records,
          option_date: option_date,
        )
      )
    end

    #
    # --------------------- profile collection ---------------------
    #
    private def run_profile_collection(
      source : String,
      *,
      dataset : String?,
      securities : Array(String),
    ) : Nil
      selection = profile_selection(source, dataset, securities)
      output_result(
        Tools::ProfileCollection.new(selection).run(
          option_records: option_records,
          option_date: option_date,
          option_sort: option_profile_sort,
          rank_criteria: option_profile_rank_criteria || 7,
          option_limit: option_profile_limit,
          include_rejected: option_profile_include_rejected,
        )
      )
    end

    #
    # --------------------- profile shared helpers ---------------------
    #
    private def profile_selection(
      source : String,
      dataset : String?,
      securities : Array(String),
    ) : Tools::ProfileCollectionSelection
      Tools::ProfileCollectionSelection.new(
        source: source,
        universe: market_universe,
        dataset: dataset,
        securities: securities,
        group: option_profile_group,
      )
    end

    private def ensure_profile_source_compatible!(
      dataset : String?,
      securities : Array(String),
    ) : Nil
      return unless dataset && !securities.empty?

      raise LowLevelError.new(
        "--dataset and --security cannot be used together",
        key: "tools.profile.collection.dataset_security_conflict",
        kind: LowLevelError::Kind::UserInput,
        log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
      )
    end

    private def database_quote_history_input(
      source : String,
      security : String,
    ) : MarketData::DatabaseQuoteHistoryInput
      MarketData::DatabaseQuoteHistoryInput.new(
        source,
        security,
        market_universe,
      )
    end

    private def market_universe : String
      option_quote_universe || App.default_market_universe
    end

    private def output_result(result : String) : Nil
      output.puts result unless result.empty?
    end

    private def profile_database_only_option : String?
      return "--universe" if option_quote_universe
      return "--security" unless option_profile_securities.empty?
      return "--dataset" if option_profile_dataset
      return "--group" if option_profile_group
      nil
    end

    private def reject_profile_collection_options! : Nil
      option = if option_profile_group
                 "--group"
               elsif option_profile_sort
                 "--sort"
               elsif option_profile_rank_criteria
                 "--rank-criteria"
               elsif option_profile_limit
                 "--limit"
               elsif option_profile_include_rejected
                 "--include-rejected"
               end
      return if option.nil?

      raise LowLevelError.new(
        "profile option '#{option}' requires a collection",
        key: "tools.profile.collection.option_requires_collection",
        context: {:option => option},
        kind: LowLevelError::Kind::UserInput,
        log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
      )
    end

    #
    # --------------------- shared tool helpers ---------------------
    #
    private def backtest_arguments : {MarketData::QuoteHistoryInput, String, TradingSystem::Money?}
      input = single_quote_input
      scaledef = required_scale
      begin
        money = TradingSystem::Money.parse(option_money)
      rescue ex : LowLevelError
        if ex.kind.in?({LowLevelError::Kind::InvalidData, LowLevelError::Kind::Technical})
          raise ex
        end

        raise LowLevelError.new(
          "invalid capital-management definition '#{option_money}'",
          key: "tools.backtest.invalid_money",
          context: {:money => option_money.to_s},
          kind: LowLevelError::Kind::UserInput,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          cause: ex)
      end
      {input, scaledef, money}
    end

    private def single_quote_input : MarketData::QuoteHistoryInput
      if input = database_quote_input
        argc_check(0, 0)
        input
      else
        reject_database_only_options!
        argc_check(1, 1)
        MarketData::FileQuoteHistoryInput.new(ARGV.shift)
      end
    end

    private def required_scale : String
      value = option_scale
      if value.nil? || value.empty?
        raise LowLevelError.new(
          "missing --scale option",
          key: "infra.missing_option",
          context: {:option => "--scale"},
          kind: LowLevelError::Kind::UserInput,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
        )
      end
      value.not_nil!
    end

    private def scoring_arguments : {MarketData::QuoteHistoryInput, String?}
      if input = database_quote_input
        argc_check(0, 1)
        builder = ARGV.empty? ? nil : ARGV.shift
        {input, builder}
      else
        reject_database_only_options!
        argc_check(1, 2)
        input = MarketData::FileQuoteHistoryInput.new(ARGV.shift)
        builder = ARGV.empty? ? nil : ARGV.shift
        {input, builder}
      end
    end

    private def database_quote_input : MarketData::DatabaseQuoteHistoryInput?
      source = option_quote_database
      return nil if source.nil?

      ident = option_quote_security
      if ident.nil? || ident.empty?
        raise LowLevelError.new(
          "--security is required with --database",
          key: "tools.quote_history.database_security_required",
          context: {:option => "--security"},
          kind: LowLevelError::Kind::UserInput,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
        )
      end

      database_quote_history_input(source, ident)
    end

    private def reject_database_only_options! : Nil
      option = if option_quote_security
                 "--security"
               elsif option_quote_universe
                 "--universe"
               end
      return if option.nil?

      raise LowLevelError.new(
        "#{option} requires --database",
        key: "tools.quote_history.option_requires_database",
        context: {:option => option},
        kind: LowLevelError::Kind::UserInput,
        log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
      )
    end

    #
    # --------------------- options ---------------------
    #
    private def option_quote_source(
      parser : OptionParser,
      subcommand : String,
    ) : Nil
      parser.on(
        "--database=SOURCE",
        I18n.t("tools.#{subcommand}.option_database"),
      ) do |value|
        self.option_quote_database = value
      end

      parser.on(
        "--universe=NAME",
        I18n.t(
          "tools.#{subcommand}.option_universe",
          universe: App.default_market_universe,
        ),
      ) do |value|
        self.option_quote_universe = value
      end

      parser.on(
        "--security=IDENT",
        I18n.t("tools.#{subcommand}.option_security"),
      ) do |value|
        self.option_quote_security = value
      end
    end

    private def option_profile_group(parser : OptionParser, key : String) : Nil
      parser.on("--group=CODE", key) do |value|
        self.option_profile_group =
          MarketData::GroupSynchronizer.normalize_group_code!(value)
      end
    end

    private def option_profile_include_rejected(parser : OptionParser) : Nil
      parser.on(
        "--include-rejected",
        I18n.t("tools.profile.option_include_rejected"),
      ) do
        self.option_profile_include_rejected = true
      end
    end

    private def option_profile_sort(parser : OptionParser) : Nil
      parser.on(
        "--sort=KEY",
        I18n.t("tools.profile.option_sort"),
      ) do |value|
        self.option_profile_sort = value
      end
    end

    private def option_profile_rank_criteria(parser : OptionParser) : Nil
      parser.on(
        "--rank-criteria=N",
        I18n.t("tools.profile.option_rank_criteria"),
      ) do |value|
        parsed = value.to_i?
        if parsed.nil? || parsed < 1 || parsed > 7
          raise LowLevelError.new(
            "invalid profile rank criteria count '#{value}'",
            key: "tools.profile.collection.invalid_rank_criteria",
            context: {:value => value},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        self.option_profile_rank_criteria = parsed
      end
    end

    private def option_profile_limit(parser : OptionParser) : Nil
      parser.on(
        "--limit=COUNT",
        I18n.t("tools.profile.option_limit"),
      ) do |value|
        parsed = value.to_i?
        if parsed.nil? || parsed <= 0
          raise LowLevelError.new(
            "invalid profile limit '#{value}'",
            key: "tools.profile.collection.invalid_limit",
            context: {:value => value},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        self.option_profile_limit = parsed
      end
    end

    private def option_score_ranking(parser : OptionParser) : Nil
      parser.on(
        "--ranking=MODE",
        I18n.t("tools.score.option_ranking"),
      ) do |value|
        normalized = value.downcase
        unless normalized.in?({"raw", "jedi", "both"})
          raise LowLevelError.new(
            "invalid score ranking '#{value}'",
            key: "tools.score.preference.invalid_ranking",
            context: {:value => value},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        self.option_score_ranking = normalized
      end
    end

    private def option_score_search(parser : OptionParser) : Nil
      parser.on(
        "--search=MODE",
        I18n.t("tools.score.option_search"),
      ) do |value|
        normalized = value.downcase
        unless normalized.in?({"grid", "adaptive"})
          raise LowLevelError.new(
            "invalid score search strategy '#{value}'",
            key: "tools.score.search.invalid_strategy",
            context: {:value => value},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        self.option_score_search = normalized
      end
    end

    private def option_score_budget(parser : OptionParser) : Nil
      parser.on(
        "--budget=COUNT",
        I18n.t("tools.score.option_budget"),
      ) do |value|
        parsed = value.to_i?
        if parsed.nil? || parsed <= 0
          raise LowLevelError.new(
            "invalid score search budget '#{value}'",
            key: "tools.score.search.invalid_budget",
            context: {:value => value},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        self.option_score_budget = parsed
      end
    end

    private def option_score_display(parser : OptionParser) : Nil
      parser.on(
        "--display=MODE",
        I18n.t("tools.score.option_display"),
      ) do |value|
        normalized = value.downcase
        unless normalized.in?({"compact", "technical", "study"})
          raise LowLevelError.new(
            "invalid score display mode '#{value}'",
            key: "tools.score.display.invalid_mode",
            context: {:value => value},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        self.option_score_display = normalized
      end
    end

    private def option_backtest_display(parser : OptionParser) : Nil
      parser.on(
        "--display=MODE",
        I18n.t("tools.backtest.option_display"),
      ) do |value|
        normalized = value.downcase
        unless normalized.in?({"compact", "technical"})
          raise LowLevelError.new(
            "invalid backtest display mode '#{value}'",
            key: "tools.backtest.display.invalid_mode",
            context: {:value => value},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        self.option_backtest_display = normalized
      end
    end

    private def option_candidate_price(parser : OptionParser, key : String) : Nil
      parser.on("--price=PRICE", key) do |param|
        value = param.to_f?
        if value.nil? || !value.finite? || value <= 0.0
          raise LowLevelError.new(
            "invalid candidate price '#{param}'",
            key: "tools.candidate.invalid_price",
            context: {:price => param},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        self.option_candidate_price = value
      end
    end

    private def option_candidate_capital(
      parser : OptionParser,
      key : String,
      *,
      error_key : String = "tools.candidate.invalid_capital",
    ) : Nil
      parser.on("--capital=AMOUNT", key) do |param|
        value = param.to_f?
        if value.nil? || !value.finite? || value <= 0.0
          raise LowLevelError.new(
            "invalid capital '#{param}'",
            key: error_key,
            context: {:capital => param},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        self.option_capital = value
      end
    end

    private def option_amount(parser : OptionParser, key : String) : Nil
      parser.on("--amount=AMOUNT", key) do |param|
        value = param.to_f?
        if value.nil? || !value.finite? || value <= 0.0
          raise LowLevelError.new(
            "invalid candidate amount '#{param}'",
            key: "tools.candidate.invalid_amount",
            context: {:amount => param},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        self.option_amount = value
      end
    end

    private def option_scale(parser : OptionParser) : Nil
      parser.on(
        "--scale=DEF",
        I18n.t("tools.backtest.option_scale"),
      ) do |value|
        self.option_scale = value
      end
    end

    private def option_plot_legend(parser : OptionParser) : Nil
      parser.on(
        "--legend=POSITION",
        I18n.t("tools.plot.option_legend"),
      ) do |value|
        self.option_plot_legend = value
      end
    end

    private def option_execution(parser : OptionParser) : Nil
      parser.on(
        "--execution=MODE",
        I18n.t("tools.backtest.option_execution"),
      ) do |param|
        self.option_execution = param
      end
    end

    private def option_opening_day_orders(parser : OptionParser) : Nil
      parser.on(
        "--opening-day-orders=WHEN",
        I18n.t("tools.backtest.option_opening_day_orders"),
      ) do |param|
        self.option_opening_day_orders = param
      end
    end

    private def option_minimum_quantity(parser : OptionParser) : Nil
      parser.on(
        "--minimum-quantity=COUNT",
        I18n.t("tools.backtest.option_minimum_quantity"),
      ) do |param|
        self.option_minimum_quantity = positive_integer_option(
          "minimum_quantity",
          param,
        )
      end
    end

    private def option_operability_steps(parser : OptionParser) : Nil
      parser.on(
        "--operability-steps=COUNT",
        I18n.t("tools.backtest.option_operability_steps", steps: App.diagnostic_steps.to_s),
      ) do |param|
        self.option_operability_steps = positive_integer_option(
          "operability_steps",
          param,
        )
      end
    end

    private def positive_integer_option(name : String, raw : String) : Int32
      value = raw.to_i?
      if value.nil? || value <= 0
        raise LowLevelError.new(
          "invalid positive integer '#{raw}' for #{name}",
          key: "tools.backtest.position_sizing.invalid_argument",
          context: {
            :name  => name,
            :value => raw,
          } of Symbol => String,
          kind: LowLevelError::Kind::UserInput,
          log_context: {
            :source => Core::Utils.source(__FILE__, __LINE__),
          },
        )
      end
      value
    end
  end
end
