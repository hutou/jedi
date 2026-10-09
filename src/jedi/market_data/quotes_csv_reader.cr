module Jedi
  module MarketData
    enum FieldSeparator
      Semicolon
      Comma

      def char : Char
        case self
        in Semicolon then ';'
        in Comma     then ','
        end
      end
    end

    record QuotesCsvFormat,
      field_separator : FieldSeparator,
      date_layout : DateLayout

    # Reads raw quotation files containing records such as:
    #
    #   ISIN;date;open;high;low;close;volume
    #   ISIN,date,open,high,low,close,volume
    #
    # Blank lines and lines beginning with '#' are ignored. The file is read in
    # streaming mode by #each; only a small sample is retained to detect its
    # format.
    class QuotesCsvReader
      include Enumerable(QuoteRow)

      SAMPLE_SIZE = 100
      FIELD_COUNT =   7

      @filename : String
      @format : QuotesCsvFormat
      @year_pivot : Int32
      @start_line : Int32

      getter filename : String
      getter format : QuotesCsvFormat
      getter year_pivot : Int32
      getter start_line : Int32

      def initialize(
        filename : String,
        date_order : DateOrder? = nil,
        year_pivot : Int32 = 70,
        start_line : Int32 = 1,
      )
        @filename = filename
        @year_pivot = year_pivot
        @start_line = start_line
        @format = detect_format(date_order)
      end

      private def detect_format(date_order : DateOrder?) : QuotesCsvFormat
        validate_file!
        validate_start_line!

        sample = sample_lines
        if sample.empty?
          raise LowLevelError.new(
            "quotation file contains no data: #{filename}",
            log_context: {:filename => filename}
          )
        end

        field_separator = detect_field_separator(sample.first[:text])
        date_values = sample.map do |entry|
          fields = split_identity_fields(
            entry[:text],
            field_separator,
            entry[:number]
          )
          fields[1]
        end

        date_layout = DateFormatDetector.detect(
          date_values,
          order: date_order,
          year_pivot: year_pivot
        )

        QuotesCsvFormat.new(field_separator, date_layout)
      rescue ex : LowLevelError
        enrich_error!(ex, {:filename => filename})
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot initialize quotation reader for '#{filename}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:filename => filename},
          cause: ex
        )
      end

      alias RecordSelector = Proc(String, Time, Bool)
      alias InvalidQuoteHandler = Proc(QuoteAnomaly, Nil)

      # The optional selector is called after decoding only the ISIN and date,
      # but before decoding and validating the OHLCV values. This notably lets
      # importers discard records older than their history boundary without an
      # irrelevant malformed historical quotation aborting the import.
      def each(
        selector : RecordSelector? = nil,
        on_invalid_quote : InvalidQuoteHandler? = nil,
        & : QuoteRow ->
      ) : Nil
        parser = DateParser.new(format.date_layout, year_pivot)
        file = open_file
        line_number = 0
        data_started = false

        begin
          while raw = read_line(file)
            line_number += 1
            next if line_number < start_line

            line = raw.strip
            next if ignored?(line)

            # ABCBourse files downloaded individually contain a first record
            # made only of a date in DDMMYYYY form. It is file metadata, not a
            # quotation. Only leading records are eligible for this treatment;
            # the same malformed line after quotation data has started remains
            # an error.
            if !data_started && standalone_date_header?(line)
              next
            end

            data_started = true
            fields, isin, date = parse_identity(line, line_number, parser)

            # Deliberately outside a generic rescue: an exception raised by the
            # selector or by the Enumerable consumer must not be converted into
            # a quotation parsing error.
            if filter = selector
              next unless filter.call(isin, date)
            end

            quote = parse_quote(fields, date, line, line_number)

            if reason = invalid_quote_reason(quote)
              anomaly = QuoteAnomaly.new(
                isin,
                date,
                quote,
                reason,
                line_number,
                compact_record(line)
              )

              # Deliberately outside parse_quote's rescue: an exception raised
              # by the handler belongs to the consumer, not to CSV parsing.
              if handler = on_invalid_quote
                handler.call(anomaly)
                next
              end

              raise line_error(line_number, reason, line)
            end

            yield QuoteRow.new(isin, quote)
          end
        ensure
          close_file(file)
        end
      end

      private def validate_file! : Nil
        return if File.file?(filename)

        raise LowLevelError.new(
          "quotation file not found: #{filename}",
          log_context: {:filename => filename}
        )
      end

      private def validate_start_line! : Nil
        return if start_line > 0

        raise LowLevelError.new(
          "quotation reader start line must be positive, got #{start_line}",
          log_context: {
            :filename   => filename,
            :start_line => start_line.to_s,
          }
        )
      end

      private def sample_lines : Array(NamedTuple(number: Int32, text: String))
        sample = [] of NamedTuple(number: Int32, text: String)
        file = open_file
        line_number = 0
        data_started = false

        begin
          while raw = read_line(file)
            line_number += 1
            next if line_number < start_line
            line = raw.strip
            next if ignored?(line)

            if !data_started && standalone_date_header?(line)
              next
            end

            data_started = true
            sample << {number: line_number, text: line}
            break if sample.size >= SAMPLE_SIZE
          end
        ensure
          close_file(file)
        end

        sample
      end

      private def open_file : File
        File.open(filename, "r")
      rescue ex
        raise LowLevelError.new(
          "cannot open quotation file '#{filename}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:filename => filename},
          cause: ex
        )
      end

      private def read_line(file : File) : String?
        file.gets
      rescue ex
        raise LowLevelError.new(
          "cannot read quotation file '#{filename}': " \
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

      private def ignored?(line : String) : Bool
        line.empty? || line.starts_with?('#')
      end

      # ABCBourse prepends a standalone source date to files downloaded
      # individually. Historical ZIP files do not contain this record.
      # Validate the value as a real DMY date rather than accepting any eight
      # digits, so a malformed first quotation still fails normally.
      private def standalone_date_header?(line : String) : Bool
        return false unless line.matches?(/\A(?:\d{6}|\d{8})\z/)

        year_width = line.size == 8 ? YearWidth::Four : YearWidth::Two
        layout = DateLayout.new(
          DateOrder::Dmy,
          DateSeparator::None,
          year_width
        )
        DateParser.new(layout, year_pivot).parse(line)
        true
      rescue ex : LowLevelError
        false
      end

      private def detect_field_separator(line : String) : FieldSeparator
        if line.includes?(';')
          FieldSeparator::Semicolon
        elsif line.includes?(',')
          FieldSeparator::Comma
        else
          raise LowLevelError.new(
            "cannot detect the field separator in '#{line}'",
            log_context: {
              :filename => filename,
              :record   => compact_record(line),
            }
          )
        end
      end

      # Parses only the fields needed to decide whether the record is useful.
      # No price or volume conversion occurs here.
      private def parse_identity(
        line : String,
        line_number : Int32,
        parser : DateParser,
      ) : Tuple(Array(String), String, Time)
        fields = split_identity_fields(
          line,
          format.field_separator,
          line_number
        )
        isin = fields[0]

        if isin.empty?
          raise line_error(line_number, "empty ISIN", line)
        end

        date = parser.parse(fields[1])
        {fields, isin, date}
      rescue ex : LowLevelError
        enrich_error!(ex, line_context(line_number, line))
        raise ex
      rescue ex
        raise LowLevelError.new(
          "quotation identity parse error in #{filename}:#{line_number}: " \
          "#{ex.message || ex.class.name}",
          log_context: line_context(line_number, line),
          cause: ex
        )
      end

      private def parse_quote(
        fields : Array(String),
        date : Time,
        line : String,
        line_number : Int32,
      ) : Quote
        validate_quote_field_count!(fields, line_number, line)

        quote = {
          date:   date,
          open:   parse_float(fields[2], line_number, "open", line),
          high:   parse_float(fields[3], line_number, "high", line),
          low:    parse_float(fields[4], line_number, "low", line),
          close:  parse_float(fields[5], line_number, "close", line),
          volume: parse_volume(fields[6], line_number, line),
        }

        quote
      rescue ex : LowLevelError
        enrich_error!(ex, line_context(line_number, line))
        raise ex
      rescue ex
        raise LowLevelError.new(
          "quotation parse error in #{filename}:#{line_number}: " \
          "#{ex.message || ex.class.name}",
          log_context: line_context(line_number, line),
          cause: ex
        )
      end

      private def split_identity_fields(
        line : String,
        separator : FieldSeparator,
        line_number : Int32,
      ) : Array(String)
        fields = line.split(separator.char).map(&.strip)

        if fields.size < 2
          raise line_error(
            line_number,
            "expected at least 2 fields, got #{fields.size}",
            line
          )
        end

        fields
      end

      private def validate_quote_field_count!(
        fields : Array(String),
        line_number : Int32,
        line : String,
      ) : Nil
        return if fields.size == FIELD_COUNT

        raise line_error(
          line_number,
          "expected #{FIELD_COUNT} fields, got #{fields.size}",
          line
        )
      end

      private def parse_float(
        value : String,
        line_number : Int32,
        field_name : String,
        line : String,
      ) : Float64
        normalized =
          if format.field_separator.semicolon?
            value.gsub(',', '.')
          else
            value
          end

        normalized.to_f64
      rescue ex
        raise LowLevelError.new(
          "invalid #{field_name} value '#{value}' in #{filename}:#{line_number}",
          log_context: line_context(line_number, line).merge({
            :field  => field_name,
            :value  => value,
            :source => Core::Utils.source(__FILE__, __LINE__),
          }),
          cause: ex
        )
      end

      private def parse_volume(
        value : String,
        line_number : Int32,
        line : String,
      ) : Int64
        value.to_i64
      rescue ex
        raise LowLevelError.new(
          "invalid volume '#{value}' in #{filename}:#{line_number}",
          log_context: line_context(line_number, line).merge({
            :field  => "volume",
            :value  => value,
            :source => Core::Utils.source(__FILE__, __LINE__),
          }),
          cause: ex
        )
      end

      # Returns a precise reason for a data anomaly, or nil when the OHLCV
      # values are coherent. Numeric conversion and CSV structure errors remain
      # blocking and are raised before this method is called.
      private def invalid_quote_reason(quote : Quote) : String?
        open = quote[:open]
        high = quote[:high]
        low = quote[:low]
        close = quote[:close]
        volume = quote[:volume]

        return "OHLC values must be positive" unless open > 0.0 && high > 0.0 && low > 0.0 && close > 0.0
        return "high is lower than low" if high < low
        return "open is greater than high" if open > high
        return "close is greater than high" if close > high
        return "open is lower than low" if open < low
        return "close is lower than low" if close < low
        return "volume must not be negative" if volume < 0

        nil
      end

      private def line_error(
        line_number : Int32,
        message : String,
        line : String,
      ) : LowLevelError
        LowLevelError.new(
          "quotation parse error in #{filename}:#{line_number}: " \
          "#{message}\n>> #{line}",
          log_context: line_context(line_number, line)
        )
      end

      private def line_context(
        line_number : Int32,
        line : String,
      ) : Hash(Symbol, String)
        {
          :filename => filename,
          :line     => line_number.to_s,
          :record   => compact_record(line),
        }
      end

      private def enrich_error!(
        ex : LowLevelError,
        context : Hash(Symbol, String),
      ) : Nil
        context.each do |key, value|
          ex.log_context[key] = value unless ex.log_context.has_key?(key)
        end
      end

      private def compact_record(line : String, limit : Int32 = 240) : String
        return line if line.size <= limit
        "#{line[0, limit]}..."
      end
    end
  end
end
