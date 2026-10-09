module Jedi
  module App
    enum LogSeverity
      Debug
      Info
      Warn
      Error
    end

    alias LogContext = Hash(Symbol, String)
    alias LogCode = String | Symbol

    struct LogEntry
      getter timestamp : Time
      getter severity : LogSeverity
      getter code : String
      getter message : String
      getter context : Hash(Symbol, String)

      def initialize(
        @severity : LogSeverity,
        code : LogCode,
        @message : String,
        @context : LogContext = LogContext.new,
        @timestamp : Time = Time.local,
      )
        @code = code.to_s
      end

      def format : String
        ts = timestamp.to_s("%Y-%m-%d %H:%M:%S %:z")
        flevel = "%-7s" % severity.to_s.upcase

        header =
          if message.empty? || message == code
            "#{ts} [#{flevel}] #{code}"
          else
            "#{ts} [#{flevel}] #{code} #{message}"
          end
        return header if context.empty?

        inline_context = context.map { |k, v| "#{k}=#{v.inspect}" }.join(" ")

        if message.empty? && "#{header} : #{inline_context}".size <= 140
          "#{header} : #{inline_context}"
        elsif context.size <= 1 && "#{header} #{inline_context}".size <= 140
          "#{header} #{inline_context}"
        else
          indent = " " * (ts.size + 1 + 2 + flevel.size + 2 + 1)
          details = context.map { |k, v| "#{indent}#{k}=#{v.inspect}" }.join("\n")
          "#{header}\n#{details}"
        end
      end
    end
  end
end
