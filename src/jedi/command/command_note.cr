module Jedi
  class NoteSubCommand < Command
    @raw_date : String? = nil
    @raw_summary : String? = nil
    @raw_contents : String? = nil
    @raw_edit : Bool? = nil

    def parser_on_note
      subcommands = ["create", "delete", "list", "show", "update"]
      self.command = "note"
      note_parser = OptionParser.new do |parser|
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

      note_parser.parse
      note_run
    end

    private def note_run
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
      parser.on("--date=DATE",
        I18n.t("#{prefix}.date")) { |v| @raw_date = v }
      parser.on("--summary=SUMMARY",
        I18n.t("#{prefix}.summary")) { |v| @raw_summary = v }
      parser.on("--contents=TEXT",
        I18n.t("#{prefix}.contents")) { |v| @raw_contents = v }
      parser.separator ""
      parser.separator I18n.t("infra.options")
      parser.on("--edit",
        I18n.t("#{prefix}.edit")) { @raw_edit = true }
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def create
      if ARGV.empty?
        using_options = !(@raw_date.nil? && @raw_summary.nil? && @raw_contents.nil?)
        using_editor = !@raw_edit.nil?
        if using_options && using_editor
          raise LowLevelError.new("Arguments mismatch !",
            key: "infra.incompatible_args",
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      else
        argc = Core::Input.ensure_argument_count!(3, 3,
          key: "infra.positional_arguments")
        @raw_date, @raw_summary, @raw_contents = ARGV.shift(argc)
      end
      Journal::NoteCreator.new(conn_main).call date: @raw_date,
        summary: @raw_summary, contents: @raw_contents, edit: @raw_edit
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    #
    # --------------------- delete ---------------------
    #
    private def delete(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("infra.options")
      option_noconfirm(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def delete
      id = Core::Input.ensure_string_valid!(ARGV.shift?,
        field: "id", regex: /\A\d+\z/, key: "infra.field_required").to_i64
      Core::Input.ensure_argv_empty!
      Journal::NoteDeleter.new(conn_main).call id: id
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
      parser.separator I18n.t("infra.options")
      option_columns(parser)
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def list
      regex_as_string = ARGV.shift?
      Core::Input.ensure_argv_empty!
      result = Journal::NoteLister.new(conn_main).call regex: regex_as_string,
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
      id = Core::Input.ensure_string_valid!(ARGV.shift?,
        field: "id", regex: /\A\d+\z/, key: "infra.field_required").to_i64
      Core::Input.ensure_argv_empty!
      note = Journal::Note.new(conn_main, id)
      result = Journal::NotePresenter.new(note).call
      puts result unless result.empty?
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
      parser.separator I18n.t("infra.required_fields")
      parser.on("--date=DATE",
        I18n.t("#{prefix}.date")) { |v| @raw_date = v }
      parser.on("--summary=SUMMARY",
        I18n.t("#{prefix}.summary")) { |v| @raw_summary = v }
      parser.on("--contents=TEXT",
        I18n.t("#{prefix}.contents")) { |v| @raw_contents = v }
      parser.separator ""
      parser.separator I18n.t("infra.options")
      parser.on("--edit",
        I18n.t("#{prefix}.edit")) { @raw_edit = true }
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def update
      id = Core::Input.ensure_string_valid!(ARGV.shift?,
        field: "id", regex: /\A\d+\z/, key: "infra.field_required").to_i64
      Core::Input.ensure_argv_empty!
      using_options = !(@raw_date.nil? && @raw_summary.nil? && @raw_contents.nil?)
      using_editor = !@raw_edit.nil?
      if using_options && using_editor
        raise LowLevelError.new("Arguments mismatch !",
          key: "infra.incompatible_args",
          kind: LowLevelError::Kind::UserInput,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end
      @raw_edit = true unless using_options # default = use editor
      note = Journal::Note.new(conn_main, id)
      Journal::NoteUpdater.new(note).call date: @raw_date,
        summary: @raw_summary, contents: @raw_contents, edit: @raw_edit
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end
  end
end
