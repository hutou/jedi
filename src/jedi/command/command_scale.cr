module Jedi
  class ScaleSubCommand < Command
    @raw_name : String? = nil
    @raw_comment : String? = nil
    @raw_builder : String? = nil

    def parser_on_scale
      subcommands = ["create", "delete", "list", "update", "show"]
      self.command = "scale"
      scale_parser = OptionParser.new do |parser|
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

      scale_parser.parse
      scale_run
    end

    private def scale_run
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
      parser.on("--comment=COMMENT",
        I18n.t("#{prefix}.required_comment")) { |v| @raw_comment = v }
      parser.on("--builder=BUILDER",
        I18n.t("#{prefix}.required_builder")) { |v| @raw_builder = v }
      parser.separator ""
      parser.separator I18n.t("infra.optional_fields")
      parser.on("--name=NAME",
        I18n.t("#{prefix}.optional_name")) { |v| @raw_name = v }
      parser.separator ""
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def create
      unless ARGV.empty?
        if @raw_name.nil? && @raw_comment.nil? && @raw_builder.nil?
          argc = Core::Input.ensure_argument_count!(2, 3,
            key: "infra.positional_arguments")
          if argc == 3
            @raw_name, @raw_comment, @raw_builder = ARGV.shift(3)
          else
            @raw_comment, @raw_builder = ARGV.shift(2)
          end
        end
      end
      comment = Core::Input.ensure_present!(@raw_comment, field: "comment")
      builder = Core::Input.ensure_present!(@raw_builder, field: "builder")
      Core::Input.ensure_argv_empty!
      TradingRules::ScaleCreator.new(conn_main).call name: @raw_name,
        comment: comment, builder: builder
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
      scale_ident = ident(Core::Input.ensure_present!(ARGV.shift?,
        field: "scale: id | name"))
      Core::Input.ensure_argv_empty!
      TradingRules::ScaleDeleter.new(conn_main).call scale_ident
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- list ---------------------
    #
    private def list(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("infra.filters")
      option_regex(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.filters.regex")
      parser.separator ""
      option_records(parser)
      parser.separator ""
      option_in_use(parser, I18n.t("#{prefix}.option_in_use"))
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
      result = TradingRules::ScaleLister.new(conn_main).call regex: regex_as_string,
        option_csv: option_csv, option_headers: option_headers,
        option_extended: option_extended, option_in_use: option_in_use,
        option_records: option_records, option_columns: option_columns
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
      arg = Core::Input.ensure_present!(ARGV.shift?,
        field: %(Scale: id | name | ="literal"))
      Core::Input.ensure_argv_empty!

      scale = if arg =~ /^=/ # Sure (probably?), we have a literal builder
                opscale = TradingRules::Scale::Type.new(arg[1..]).decode
                TradingRules::Scale.new("", "", opscale.to_json)
              else
                TradingRules::Scale.new(conn_main, ident: ident(arg))
              end
      TradingRules::ScalePresenter.new(scale).show
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- update ---------------------
    #
    private def update(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("infra.optional_fields")
      parser.on("--name=NAME", I18n.t("#{prefix}.required_name")) { |v| @raw_name = v }
      parser.on("--comment=COMMENT", I18n.t("#{prefix}.required_comment")) { |v| @raw_comment = v }
      parser.on("--builder=BUILDER", I18n.t("#{prefix}.required_builder")) { |v| @raw_builder = v }
      parser.separator ""
      parser.separator I18n.t("infra.options")
      option_force(parser, I18n.t("#{prefix}.option_force"))
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def update
      scale_ident = ident(Core::Input.ensure_present!(ARGV.shift?,
        field: "Scale: id | name"))
      Core::Input.ensure_argv_empty!
      scale = TradingRules::Scale.new(conn_main, ident: scale_ident)
      TradingRules::ScaleUpdater.new(scale).call name: @raw_name,
        comment: @raw_comment, builder: @raw_builder, option_force: option_force
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end
  end
end
