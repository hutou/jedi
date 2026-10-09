module Jedi
  module MarketData
    # Reads the labels file:
    #
    #   ISIN;Name;Ticker
    #
    # An optional header is accepted. Blank lines and lines beginning with '#'
    # are ignored. If a name contains additional semicolons, the first field is
    # treated as the ISIN and the last one as the ticker.
    class LabelsCsvReader
      include Enumerable(SecurityInfo)

      getter filename : String

      @filename : String

      def initialize(filename : String)
        @filename = filename
        validate_file!
      end

      def each(& : SecurityInfo ->) : Nil
        seen = {} of String => Bool
        first_record = true
        file = open_file
        line_number = 0

        begin
          while raw = read_line(file)
            line_number += 1
            line = raw.strip
            next if line.empty? || line.starts_with?('#')

            fields = split_fields(line, line_number)

            if first_record && header?(fields)
              first_record = false
              next
            end
            first_record = false

            security = parse_record(fields, line_number, line)

            if seen.has_key?(security.isin)
              raise line_error(
                line_number,
                "duplicate ISIN '#{security.isin}'",
                line
              )
            end
            seen[security.isin] = true

            # Deliberately outside a generic rescue: an exception raised by the
            # consumer of the Enumerable must not be converted here.
            yield security
          end
        ensure
          close_file(file)
        end
      end

      private def validate_file! : Nil
        return if File.file?(filename)

        raise LowLevelError.new(
          "labels file not found: #{filename}",
          log_context: {:filename => filename}
        )
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot initialize labels reader for '#{filename}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:filename => filename},
          cause: ex
        )
      end

      private def open_file : File
        File.open(filename, "r")
      rescue ex
        raise LowLevelError.new(
          "cannot open labels file '#{filename}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:filename => filename},
          cause: ex
        )
      end

      private def read_line(file : File) : String?
        file.gets
      rescue ex
        raise LowLevelError.new(
          "cannot read labels file '#{filename}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:filename => filename},
          cause: ex
        )
      end

      private def close_file(file : File) : Nil
        file.close
      rescue
        # Never mask the parsing error, nor an exception raised by the caller.
      end

      private def parse_record(
        fields : Array(String),
        line_number : Int32,
        line : String,
      ) : SecurityInfo
        isin = clean(fields.first)
        ticker = clean(fields.last)
        name = clean(fields[1, fields.size - 2].join(";"))

        validate!(isin, ticker, name, line_number, line)

        SecurityInfo.new(
          isin: isin,
          ticker: ticker,
          name: name
        )
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "labels parse error in #{filename}:#{line_number}: " \
          "#{ex.message || ex.class.name}",
          log_context: {
            :filename => filename,
            :line     => line_number.to_s,
            :record   => compact_record(line),
          },
          cause: ex
        )
      end

      private def split_fields(line : String, line_number : Int32) : Array(String)
        fields = line.split(';').map(&.strip)

        if fields.size < 3
          raise line_error(
            line_number,
            "expected at least 3 fields, got #{fields.size}",
            line
          )
        end

        fields
      end

      private def header?(fields : Array(String)) : Bool
        return false if fields.size < 3

        clean(fields.first).downcase == "isin" &&
          clean(fields.last).downcase == "ticker"
      end

      private def clean(value : String) : String
        text = value.strip

        if text.size >= 2 && text.starts_with?('"') && text.ends_with?('"')
          text = text[1, text.size - 2].gsub("\"\"", "\"")
        end

        text.strip
      end

      private def validate!(
        isin : String,
        ticker : String,
        name : String,
        line_number : Int32,
        line : String,
      ) : Nil
        if isin.empty?
          raise line_error(line_number, "empty ISIN", line)
        end

        if ticker.empty?
          raise line_error(line_number, "empty ticker", line)
        end

        if name.empty?
          raise line_error(line_number, "empty security name", line)
        end
      end

      private def line_error(
        line_number : Int32,
        message : String,
        line : String,
      ) : LowLevelError
        LowLevelError.new(
          "labels parse error in #{filename}:#{line_number}: " \
          "#{message}\n>> #{line}",
          log_context: {
            :filename => filename,
            :line     => line_number.to_s,
            :record   => compact_record(line),
          }
        )
      end

      private def compact_record(line : String, limit : Int32 = 240) : String
        return line if line.size <= limit
        "#{line[0, limit]}..."
      end
    end
  end
end
