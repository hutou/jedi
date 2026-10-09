module Jedi
  module App
    @@messages = [] of Message
    @@logger : Logger? = nil
    @@output_mode = OutputMode::Normal

    #
    # <<< output mode >>>
    #
    def self.output_mode : OutputMode
      @@output_mode
    end

    def self.output_mode=(mode : OutputMode) : OutputMode
      @@output_mode = mode
    end

    def self.default_output_mode(simulation : Bool = false) : OutputMode
      simulation ? OutputMode::Simulation : OutputMode::Normal
    end

    def self.resolve_output_mode(
      simulation : Bool = false,
      verbose : Bool = false,
    ) : OutputMode
      if verbose
        OutputMode::Verbose
      else
        default_output_mode(simulation)
      end
    end

    def self.apply_output_mode!(
      simulation : Bool = false,
      verbose : Bool = false,
    ) : Nil
      self.output_mode = resolve_output_mode(
        simulation: simulation,
        verbose: verbose)
    end

    def self.display_message?(msg : Message) : Bool
      output_mode.display?(msg.level)
    end

    #
    # <<< messages >>>
    #
    def self.messages : Array(Message)
      @@messages
    end

    def self.clear_messages : Nil
      @@messages.clear
    end

    def self.add_message(message : Message) : Nil
      @@messages << message unless message.in?(@@messages)
    end

    def self.info(
      key : String,
      params : Hash(Symbol, String) = Hash(Symbol, String).new,
      *,
      force : Bool = false,
    ) : Nil
      add_message Message.i18n(
        Message::Level::Info,
        key,
        params,
        force: force
      )
    end

    def self.warn(key : String, params : LogContext = LogContext.new) : Nil
      add_message Message.i18n(Message::Level::Warn, key, params)
    end

    def self.error(key : String, params : LogContext = LogContext.new) : Nil
      add_message Message.i18n(Message::Level::Error, key, params)
    end

    def self.flush_messages : Nil
      Colorize.enabled = STDERR.tty?
      @@messages.each do |msg|
        next unless display_message?(msg) || msg.force

        case msg.level
        in .info?
          STDERR.puts msg.text.colorize(COLOR_INFO)
        in .warn?
          STDERR.puts msg.text.colorize(COLOR_WARN)
        in .error?
          STDERR.puts msg.text.colorize(COLOR_ERROR) # .mode(:reverse)
        end
      end

      clear_messages
    end

    #
    # <<< logger >>>
    #
    def self.logger : Logger
      logfile = paths.try(&.log_file) ||
                raise LowLevelError.new(
                  "application log path is not initialized",
                  key: "app.paths.log_file",
                  kind: LowLevelError::Kind::Technical,
                  log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      @@logger ||= Logger.new(logfile)
    end

    def self.loggable_command? : Bool
      return false if ARGV.size < 2
      return false if CMDLINE =~ /(^|\s)(-h|--help)(\s|$)/i
      true
    end

    def self.log_info(
      code : LogCode,
      log_message : String = "",
      log_context : LogContext = LogContext.new,
    ) : Nil
      logger.info(code.to_s, log_message, log_context)
    end

    def self.log_warn(
      code : LogCode,
      log_message : String = "",
      log_context : LogContext = LogContext.new,
    ) : Nil
      logger.warn(code.to_s, log_message, log_context)
    end

    def self.log_error(
      code : LogCode,
      log_message : String = "",
      log_context : LogContext = LogContext.new,
    ) : Nil
      logger.error(code.to_s, log_message, log_context)
    end

    #
    # <<< exceptions >>>
    #
    def self.capture_exception(ex : AppException) : Nil
      add_message Message.i18n(
        to_message_level(ex.level),
        ex.key,
        ex.context
      )

      log_text = ex.log_message || ex.key
      log_context = stringify_context(ex.log_context)
      case ex.level
      in .info?
        logger.info(ex.key, log_text, log_context)
      in .warn?
        logger.warn(ex.key, log_text, log_context)
      in .error?
        logger.error(ex.key, log_text, log_context)
      end

      if cause = ex.cause
        log_backtrace = cause.is_a?(LowLevelError) ? cause.log_backtrace : true
        log_exception(
          cause,
          "app_exception_cause",
          backtrace: log_backtrace
        )
      end
    end

    def self.capture_exception(
      ex : LowLevelError,
      log_context : LogContext = LogContext.new,
    ) : Nil
      log_exception(
        ex,
        ex.key || "low_level_error",
        log_context,
        backtrace: ex.log_backtrace
      )
    end

    def self.exception(ex : AppException) : Nil
      capture_exception(ex)
    end

    # Sole conversion point from internal errors to user-facing exceptions.
    def self.raise_from_low_level(
      ex : LowLevelError,
      *,
      context : Context = Context.new,
      help_key : String? = nil,
    ) : NoReturn
      app_context = ex.context.merge(context)
      log_context = LogContext.new
      if source = ex.log_context[:source]? || exception_source(ex)
        log_context[:source] = source
      end
      case ex.kind
      in LowLevelError::Kind::Unclassified
        if key = ex.key
          raise AppException.new(
            level: AppException::Level::Warn,
            key: key,
            context: ex.context.merge(context),
            log_context: log_context,
            cause: ex
          )
        end

        raise AppException.new(
          level: AppException::Level::Error,
          key: "infra.internal_error",
          context: ex.context
            .merge(context)
            .merge({:logfile => App.log_file}),
          help_key: "infra.see_logfile",
          log_context: log_context,
          cause: ex
        )
      in LowLevelError::Kind::UserInput
        if key = ex.key
          raise AppException.new(
            level: AppException::Level::Warn,
            key: key,
            context: app_context,
            help_key: help_key,
            log_context: log_context,
            cause: ex
          )
        end

        # Une erreur déclarée UserInput devrait normalement
        # avoir été qualifiée avec une key.
        raise AppException.new(
          level: AppException::Level::Error,
          key: "infra.internal_error",
          context: app_context.merge({:logfile => App.log_file}),
          help_key: "infra.see_logfile",
          log_context: log_context,
          cause: ex
        )
      in LowLevelError::Kind::Domain
        if key = ex.key
          raise AppException.new(
            level: AppException::Level::Warn,
            key: key,
            context: app_context,
            log_context: log_context,
            cause: ex
          )
        end

        # Même remarque : une erreur Domain devrait normalement
        # être qualifiée.
        raise AppException.new(
          level: AppException::Level::Error,
          key: "infra.internal_error",
          context: app_context.merge({:logfile => App.log_file}),
          help_key: "infra.see_logfile",
          log_context: log_context,
          cause: ex
        )
      in LowLevelError::Kind::InvalidData
        raise AppException.new(
          level: AppException::Level::Error,
          key: ex.key || "infra.internal_error",
          context: app_context.merge({:logfile => App.log_file}),
          help_key: "infra.see_logfile",
          log_context: log_context,
          cause: ex
        )
      in LowLevelError::Kind::Technical
        raise AppException.new(
          level: AppException::Level::Error,
          key: ex.key || "infra.internal_error",
          context: ex.context
            .merge(context)
            .merge({:logfile => App.log_file}),
          help_key: "infra.see_logfile",
          log_context: log_context,
          cause: ex
        )
      end
    end

    private def self.log_exception(
      ex : Exception,
      code : String,
      log_context : LogContext = LogContext.new,
      *,
      backtrace : Bool = true,
    ) : Nil
      context = if ex.is_a?(LowLevelError)
                  ex.as(LowLevelError).log_context.merge(log_context)
                else
                  stringify_context(log_context)
                end

      unless context.has_key?(:source)
        if source = exception_source(ex)
          context[:source] = source
        end
      end

      if cause = ex.cause
        if cause_source = exception_source(cause)
          context[:cause_source] = cause_source
        end
        context[:cause_chain] = exception_cause_chain(cause)
      end

      if backtrace
        if trace = ex.backtrace?
          unless trace.empty?
            context[:backtrace] = trace.first(Logger::BACKTRACE_LIMIT).join("\n")
          end
        end
      end

      logger.error(
        code,
        "#{ex.class.name}: #{ex.message || ""}",
        context
      )
    end

    private def self.exception_source(ex : Exception) : String?
      trace = ex.backtrace?
      return nil if trace.nil? || trace.empty?

      trace.find { |line| line.includes?("/src/jedi/") } ||
        trace.find do |line|
          !line.includes?("/usr/lib/crystal/") &&
            !line.includes?("/crystal/src/") &&
            !line.includes?("/lib/crystal/")
        end ||
        trace.first?
    end

    private def self.exception_cause_chain(cause : Exception) : String
      parts = [] of String
      current : Exception? = cause

      while current
        parts << "#{current.class.name}: #{current.message || ""}"
        current = current.cause
      end

      parts.join(" <- ")
    end

    private def self.to_message_level(level : AppException::Level) : Message::Level
      case level
      in .info?
        Message::Level::Info
      in .warn?
        Message::Level::Warn
      in .error?
        Message::Level::Error
      end
    end

    private def self.stringify_context(context : LogContext) : LogContext
      result = LogContext.new
      context.each do |k, v|
        result[k] = v
      end
      result
    end

    def self.market_dir : String
      paths!.market_dir
    end

    def self.market_db_file(
      source : String,
      universe : String = App.default_market_universe,
    ) : String
      filename = "#{source}_#{universe}.db"
      File.expand_path(File.join(market_dir, filename))
    end

    def self.bool_label_yn(value : Bool) : String
      value ? I18n.t("infra.yes") : I18n.t("infra.no")
    end

    def self.confirm(prompt, defchar)
      char = defchar
      yes = I18n.t("infra.yes_chars")
      no = I18n.t("infra.no_chars")

      loop do
        print "\r#{prompt}#{char}\x08"
        char = STDIN.raw &.read_char.as(Char)

        if (yes + no).includes?(char)
          break
        elsif char == '\r'
          char = defchar
          break
        end
      end
      puts char
      yes.includes?(char) ? true : false
    end
  end
end
