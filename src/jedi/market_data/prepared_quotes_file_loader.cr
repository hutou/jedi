module Jedi
  module MarketData
    # Loads the prepared single-security files historically consumed by
    # Tools::QuoteHistory.
    #
    # Expected form:
    #   ISIN;TICKER;NAME
    #   ISIN;date;open;high;low;close;volume
    #
    # A legacy file without the descriptive first record is still accepted; in
    # that case ticker and name are set to "N/A".
    class PreparedQuotesFileLoader
      alias SourceRecord = NamedTuple(number: Int32, text: String)

      getter filename : String
      getter date_order : DateOrder?
      getter year_pivot : Int32

      def initialize(
        @filename : String,
        @date_order : DateOrder? = nil,
        @year_pivot : Int32 = 70,
      )
      end

      def load(
        selection : HistorySelection = HistorySelection.new,
      ) : QuoteHistory
        validate_file!

        first = first_record
        if first.nil?
          raise LowLevelError.new(
            "prepared quotation file contains no data: #{filename}",
            log_context: {
              :error_code => "no_data",
              :filename   => filename,
            }
          )
        end

        metadata = parse_metadata(first[:text])
        start_line = metadata.nil? ? first[:number] : first[:number] + 1
        expected_isin = metadata.try(&.isin)
        detected_isin = nil.as(String?)
        quotes = [] of Quote

        reader = QuotesCsvReader.new(
          filename,
          date_order: date_order,
          year_pivot: year_pivot,
          start_line: start_line
        )

        reader.each do |row|
          if expected_isin && row.isin != expected_isin
            raise LowLevelError.new(
              "quotation ISIN '#{row.isin}' does not match metadata " \
              "ISIN '#{expected_isin}'",
              log_context: {
                :filename      => filename,
                :expected_isin => expected_isin,
                :actual_isin   => row.isin,
              }
            )
          end

          if detected_isin && row.isin != detected_isin
            raise LowLevelError.new(
              "prepared quotation file contains several ISINs",
              log_context: {
                :filename   => filename,
                :first_isin => detected_isin,
                :other_isin => row.isin,
              }
            )
          end

          detected_isin ||= row.isin
          quotes << row.quote
        end

        security = metadata || SecurityInfo.new(
          isin: detected_isin || first_field(first[:text]),
          ticker: "N/A",
          name: "N/A"
        )

        selected = selection.apply(
          quotes.sort_by { |quote| quote[:date] }
        )

        QuoteHistory.new(security, selected)
      rescue ex : LowLevelError
        enrich_error!(ex)
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot load prepared quotation file '#{filename}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:filename => filename},
          cause: ex
        )
      end

      private def validate_file! : Nil
        return if File.file?(filename)

        raise LowLevelError.new(
          "prepared quotation file not found: #{filename}",
          log_context: {
            :error_code => "file_not_found",
            :filename   => filename,
          }
        )
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot inspect prepared quotation file '#{filename}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:filename => filename},
          cause: ex
        )
      end

      private def first_record : SourceRecord?
        line_number = 0

        File.each_line(filename) do |raw|
          line_number += 1
          line = raw.strip
          next if line.empty? || line.starts_with?('#')

          return {number: line_number, text: line}
        end

        nil
      rescue ex
        raise LowLevelError.new(
          "cannot read prepared quotation file '#{filename}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:filename => filename},
          cause: ex
        )
      end

      private def parse_metadata(line : String) : SecurityInfo?
        separator = if line.includes?(';')
                      ';'
                    elsif line.includes?(',')
                      ','
                    else
                      return nil
                    end

        fields = line.split(separator).map(&.strip)
        return nil unless fields.size == 3

        isin = clean(fields[0])
        ticker = clean(fields[1])
        name = clean(fields[2])

        return nil if isin.empty? || ticker.empty? || name.empty?

        SecurityInfo.new(
          isin: isin,
          ticker: ticker,
          name: name
        )
      end

      private def first_field(line : String) : String
        separator = line.includes?(';') ? ';' : ','
        line.split(separator).first.strip
      end

      private def clean(value : String) : String
        text = value.strip

        if text.size >= 2 && text.starts_with?('"') && text.ends_with?('"')
          text = text[1, text.size - 2].gsub("\"\"", "\"")
        end

        text.strip
      end

      private def enrich_error!(ex : LowLevelError) : Nil
        ex.log_context[:filename] = filename unless ex.log_context.has_key?(:filename)

        if !ex.log_context.has_key?(:error_code) &&
           ex.message.to_s.includes?("contains no data")
          ex.log_context[:error_code] = "empty_history"
        end
      end
    end
  end
end
