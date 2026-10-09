module Jedi
  module App
    # Application file logger.
    #
    # LowLevelError#log_context is automatically included when an exception is
    # logged. The source is derived from the exception backtrace; low-level code
    # therefore does not need to populate a redundant :source entry.
    class Logger
      BACKTRACE_LIMIT = 20

      getter filename : String

      def initialize(filename : String)
        @filename = filename
        @mutex = Mutex.new

        begin
          Dir.mkdir_p(File.dirname(@filename))
        rescue ex
          raise LowLevelError.new(
            "cannot initialize application logger '#{@filename}': " \
            "#{ex.message || ex.class.name}",
            log_context: {:logfile => @filename},
            cause: ex
          )
        end
      end

      def info(
        code : String,
        message : String = "",
        context : LogContext = LogContext.new,
      ) : Nil
        write("INFO", code, message, context)
      end

      def warn(
        code : String,
        message : String = "",
        context : LogContext = LogContext.new,
      ) : Nil
        write("WARN", code, message, context)
      end

      def error(
        code : String,
        message : String = "",
        context : LogContext = LogContext.new,
      ) : Nil
        write("ERROR", code, message, context)
      end

      def exception(
        ex : Exception,
        code : String = "exception",
        context : LogContext = LogContext.new,
        *,
        backtrace : Bool = true,
      ) : Nil
        details = copy_context(context)
        details[:exception_class] = ex.class.name
        details[:exception_message] = ex.message || ""

        if ex.is_a?(LowLevelError)
          ex.as(LowLevelError).log_context.each do |key, value|
            details[key] = value unless details.has_key?(key)
          end
        end

        if source = exception_source(ex)
          details[:source] = source unless details.has_key?(:source)
        end

        if cause = ex.cause
          if cause_source = exception_source(cause)
            details[:cause_source] = cause_source
          end

          if chain = cause_chain(cause)
            details[:cause_chain] = chain
          end
        end

        if backtrace
          if trace = compact_backtrace(ex)
            details[:backtrace] = trace
          end
        end

        error(code, ex.message || ex.class.name, details)
      end

      private def write(
        level : String,
        code : String,
        message : String,
        context : LogContext,
      ) : Nil
        @mutex.synchronize do
          File.open(@filename, "a") do |io|
            formatted_level = level.ljust(5)
            # header = "#{timestamp} [#{formatted_level}] #{code}"
            prefix = "#{timestamp} [#{formatted_level}] "
            header = "#{prefix}#{code}"
            header += " : #{message}" unless message.empty? || message == code

            indent = " " * prefix.size
            keys = ordered_keys(context)

            if keys.empty?
              io.puts header
              next
            end

            first_key = keys.shift
            first_value = context[first_key]

            if multiline?(first_value)
              io.puts header
              write_context_value(io, indent, first_key, first_value)
            else
              io.puts "#{header} : #{format_pair(first_key, first_value)}"
            end

            keys.each do |key|
              write_context_value(io, indent, key, context[key])
            end
          end
        end
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot write application log '#{@filename}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:logfile => @filename},
          cause: ex
        )
      end

      private def ordered_keys(context : LogContext) : Array(Symbol)
        context.keys.sort_by do |key|
          # Keep long diagnostic blocks at the end of the entry.
          case key
          when :backtrace
            {2, key.to_s}
          when :cause_chain
            {1, key.to_s}
          else
            {0, key.to_s}
          end
        end
      end

      private def write_context_value(
        io : IO,
        indent : String,
        key : Symbol,
        value : String,
      ) : Nil
        if multiline?(value)
          io.puts "#{indent}#{key}:"
          value.split('\n').each do |line|
            io.puts "#{indent}  #{escape_line(line)}"
          end
        else
          io.puts "#{indent}#{format_pair(key, value)}"
        end
      end

      private def multiline?(value : String) : Bool
        value.includes?('\n')
      end

      private def timestamp : String
        now = Time.local
        offset = now.to_s("%z")
        formatted_offset =
          if offset.size == 5
            "#{offset[0, 3]}:#{offset[3, 2]}"
          else
            offset
          end

        "#{now.to_s("%Y-%m-%d %H:%M:%S")} #{formatted_offset}"
      end

      private def format_pair(key : Symbol, value : String) : String
        %(#{key}="#{escape_line(value)}")
      end

      private def escape_line(value : String) : String
        value
          .gsub("\\", "\\\\")
          .gsub("\"", "\\\"")
          .gsub("\r", "\\r")
      end

      private def copy_context(
        context : LogContext,
      ) : LogContext
        result = LogContext.new
        context.each do |key, value|
          result[key] = value
        end
        result
      end

      private def exception_source(ex : Exception) : String?
        trace = ex.backtrace?
        return nil if trace.nil? || trace.empty?

        trace.find do |line|
          !line.includes?("/usr/lib/crystal/") &&
            !line.includes?("/crystal/src/")
        end || trace.first?
      end

      private def compact_backtrace(ex : Exception) : String?
        trace = ex.backtrace?
        return nil if trace.nil? || trace.empty?

        trace.first(BACKTRACE_LIMIT).join("\n")
      end

      private def cause_chain(cause : Exception?) : String?
        return nil if cause.nil?

        parts = [] of String
        current = cause

        while current
          parts << "#{current.class.name}: #{current.message || ""}"
          current = current.cause
        end

        parts.join(" <- ")
      end
    end
  end
end
