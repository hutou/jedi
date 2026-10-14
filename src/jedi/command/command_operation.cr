module Jedi
  # class Command
  class OperationSubCommand < Command
    @raw_date : String? = nil
    @raw_time : String? = nil
    @raw_type : String? = nil
    @raw_mode : String? = nil
    @raw_quantity : String? = nil
    @raw_price : String? = nil
    @raw_fees : String? = nil

    def parser_on_operation
      subcommands = ["create", "fees", "delete", "list"]
      self.command = "operation"
      operation_parser = OptionParser.new do |parser|
        parser.summary_indent = "  "
        parser.banner = I18n.t("#{command}.banner")
        subcommands.each do |subcommand|
          prefix = "#{command}.#{subcommand}"
          parser.on(subcommand, I18n.t("#{prefix}.header")) do
            parser.banner = I18n.t("#{prefix}.banner")
            case subcommand
            when "create" then create(parser, prefix)
            when "fees"   then fees(parser, prefix)
            when "delete" then delete(parser, prefix)
            when "list"   then list(parser, prefix)
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

      operation_parser.parse
      operation_run
    end

    private def operation_run
      case subcommand
      when "create" then create
      when "fees"   then fees
      when "delete" then delete
      when "list"   then list
      end
    end

    private def create(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator I18n.t("#{prefix}.required_arguments")
      parser.separator I18n.t("infra.required_fields")
      parser.on("--date=DATE",
        I18n.t("#{prefix}.required_date")) { |v| @raw_date = v }
      parser.on("--time=TIME",
        I18n.t("#{prefix}.required_time")) { |v| @raw_time = v }
      parser.on("--type=TYPE",
        I18n.t("#{prefix}.required_type")) { |v| @raw_type = v }
      parser.on("--mode=MODE",
        I18n.t("#{prefix}.required_mode")) { |v| @raw_mode = v }
      parser.on("--quantity=QTY",
        I18n.t("#{prefix}.required_quantity")) { |v| @raw_quantity = v }
      parser.on("--price=PRICE",
        I18n.t("#{prefix}.required_price")) { |v| @raw_price = v }
      parser.separator ""
      parser.separator I18n.t("infra.optional_fields")
      parser.on("--fees=FEES",
        I18n.t("#{prefix}.optional_fees")) { |v| @raw_fees = v }
      parser.separator ""
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def create
      trade_ident = ident(Core::Input.ensure_present!(ARGV.shift?,
        field: "Trade: id | name", key: "infra.field_required"))
      unless ARGV.size.zero?
        argc = Core::Input.ensure_argument_count!(6, 7,
          key: "infra.positional_arguments")
        @raw_date, @raw_time, @raw_type, @raw_mode, @raw_quantity, @raw_price = ARGV.shift(6)
        @raw_fees = ARGV.shift if argc == 7
      end
      raw_date = Core::Input.ensure_date_valid!(@raw_date,
        field: "date", key: "infra.field_required")
      raw_time = Core::Input.ensure_time_valid!(@raw_time,
        field: "time", key: "infra.field_required")
      type = Core::Input.ensure_operation_type_valid!(@raw_type,
        field: "type", key: "infra.field_required")
      mode = Core::Input.ensure_operation_mode_valid!(@raw_mode,
        field: "mode", key: "infra.field_required")
      quantity = Core::Input.ensure_string_valid!(@raw_quantity,
        field: "quantity", regex: POSITIVE_INTEGER, key: "infra.field_required").to_i
      raw_price = Core::Input.ensure_string_valid!(@raw_price,
        field: "price", regex: NON_NEGATIVE_DECIMAL, key: "infra.field_required")
      tickcheck = raw_price.starts_with?('+') ? false : App.tickcheck
      price = raw_price.to_f
      timestamp = Time.local(raw_date.year, raw_date.month, raw_date.day,
        raw_time.hour, raw_time.minute, raw_time.second)
      fees = if (x = @raw_fees)
               Core::Input.ensure_string_valid!(x, field: "fees",
                 regex: NON_NEGATIVE_DECIMAL, key: "infra.field_required").to_f
             else
               App.fees
             end
      TradingLife::OperationCreator.new(conn_main).call trade_ident: trade_ident,
        timestamp: timestamp, type: type, mode: mode, quantity: quantity,
        price: price, cfees: fees, tickcheck: tickcheck
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

    private def fees(parser, prefix)
      parser.separator I18n.t("#{prefix}.usage")
      parser.separator I18n.t("#{prefix}.notes")
      parser.separator I18n.t("infra.options")
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def fees
      Core::Input.ensure_argument_count!(2, 2, key: "infra.positional_arguments")
      raw_id, raw_amount = ARGV.shift(2)
      operation_id = raw_id.to_i64?
      unless raw_id =~ POSITIVE_INTEGER && operation_id && operation_id > 0
        raise LowLevelError.new(
          key: "operation.fees.invalid_id",
          context: {:id => raw_id},
          kind: LowLevelError::Kind::UserInput,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      amount = raw_amount.to_f?
      unless raw_amount =~ NON_NEGATIVE_DECIMAL && amount
        raise LowLevelError.new(
          key: "operation.fees.invalid_amount",
          context: {:amount => raw_amount},
          kind: LowLevelError::Kind::UserInput,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      TradingLife::OperationFeesUpdater.new(conn_main).call(
        operation_id: operation_id, amount: amount)
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

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
      Core::Input.ensure_argv_empty!
      TradingLife::OperationDeleter.new(conn_main).delete
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end

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
      option_csv(parser)
      option_headers(parser)
      option_extended(parser, I18n.t("#{prefix}.option_extended"))
      help(parser)
      parser.separator ""
      parser.separator I18n.t("#{prefix}.examples")
    end

    private def list
      regex_as_string = ARGV.shift?
      Core::Input.ensure_argv_empty!
      result = TradingLife::OperationLister.new(conn_main).call regex: regex_as_string,
        option_records: option_records, option_columns: option_columns,
        option_group: option_group, option_running: option_running,
        option_csv: option_csv, option_extended: option_extended,
        option_headers: option_headers, from_play: nil
      puts result unless result.empty?
    rescue ex : LowLevelError
      raise_from_low_level(ex)
    end
  end
end
