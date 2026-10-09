module Jedi
  module Tools
    # Compatibility facade for tools which historically loaded a prepared
    # quotation file directly. It now accepts either a file or a market
    # database input while preserving the same QuoteHistory API.
    class QuoteHistory < MarketData::QuoteHistory
      alias Quote = MarketData::Quote

      getter input : MarketData::QuoteHistoryInput
      getter filename : String

      def initialize(
        filename : String,
        option_records : String? = nil,
        option_date : String? = nil,
      )
        @input = MarketData::FileQuoteHistoryInput.new(filename)
        @filename = filename
        history = resolve(
          @input,
          option_records,
          option_date,
        )
        super(history.security, history.quotes)
      end

      def initialize(
        @input : MarketData::QuoteHistoryInput,
        option_records : String? = nil,
        option_date : String? = nil,
      )
        @filename = input.description
        history = resolve(
          input,
          option_records,
          option_date,
        )
        super(history.security, history.quotes)
      end

      # Internal constructor used by bounded temporal validation. It keeps the
      # same source identity while replacing the quotation window.
      def initialize(
        @input : MarketData::QuoteHistoryInput,
        security : MarketData::SecurityInfo,
        quotes : Array(MarketData::Quote),
      )
        @filename = input.description
        super(security, quotes)
      end

      def source_description : String
        input.description
      end

      private def resolve(
        input : MarketData::QuoteHistoryInput,
        option_records : String?,
        option_date : String?,
      ) : MarketData::QuoteHistory
        selection = MarketData::HistorySelection.from_options(
          option_records,
          option_date,
        )

        begin
          MarketData::QuoteHistoryResolver.new.load(input, selection)
        rescue ex : LowLevelError
          raise self.class.low_level_error(input, ex)
        end
      end

      def self.low_level_error(
        input : MarketData::QuoteHistoryInput,
        ex : LowLevelError,
      ) : LowLevelError
        case input
        in MarketData::FileQuoteHistoryInput
          file_error(input.filename, ex)
        in MarketData::DatabaseQuoteHistoryInput
          database_error(input, ex)
        end
      end

      private def self.file_error(
        filename : String,
        ex : LowLevelError,
      ) : LowLevelError
        log_context = ex.log_context.merge({
          :filename => filename,
          :source   => Core::Utils.source(__FILE__, __LINE__),
        })

        case ex.log_context[:error_code]?
        when "file_not_found"
          LowLevelError.new(
            "quotation file '#{filename}' not found",
            key: "tools.quote_history.file_not_found",
            kind: LowLevelError::Kind::UserInput,
            context: {:filename => filename},
            log_context: log_context,
            cause: ex,
          )
        when "no_data"
          LowLevelError.new(
            "quotation file '#{filename}' contains no data",
            key: "tools.quote_history.error_no_data",
            kind: LowLevelError::Kind::Domain,
            log_context: log_context,
            cause: ex,
          )
        when "empty_history"
          LowLevelError.new(
            "quotation history '#{filename}' is empty",
            key: "tools.quote_history.empty",
            kind: LowLevelError::Kind::Domain,
            log_context: log_context,
            cause: ex,
          )
        else
          LowLevelError.new(
            "cannot parse quotation history '#{filename}': #{ex.message || ex.class.name}",
            key: "tools.quote_history.quotes_parser.parse_error",
            kind: LowLevelError::Kind::InvalidData,
            context: {
              :num     => ex.log_context[:line]? || "?",
              :message => ex.message || ex.class.name,
              :line    => ex.log_context[:record]? || "",
            },
            log_context: log_context,
            log_backtrace: ex.log_backtrace,
            cause: ex,
          )
        end
      end

      private def self.database_error(
        input : MarketData::DatabaseQuoteHistoryInput,
        ex : LowLevelError,
      ) : LowLevelError
        database = input.database_name
        log_context = ex.log_context.merge(database_log_context(input)).merge({
          :source => Core::Utils.source(__FILE__, __LINE__),
        })

        case ex.log_context[:error_code]?
        when "security_not_found"
          LowLevelError.new(
            "security '#{input.security}' not found in market database '#{database}'",
            key: "tools.quote_history.security_not_found",
            kind: LowLevelError::Kind::Domain,
            context: {
              :ident    => input.security,
              :database => database,
            },
            log_context: log_context,
            cause: ex,
          )
        when "empty_history"
          LowLevelError.new(
            "no quotation available for '#{input.security}' in market database '#{database}'",
            key: "tools.quote_history.database_history_empty",
            kind: LowLevelError::Kind::Domain,
            context: {
              :ident    => input.security,
              :database => database,
            },
            log_context: log_context,
            cause: ex,
          )
        else
          LowLevelError.new(
            "cannot load quotations for '#{input.security}' from market database '#{database}': " \
            "#{ex.message || ex.class.name}",
            kind: LowLevelError::Kind::Technical,
            log_context: log_context,
            log_backtrace: ex.log_backtrace,
            cause: ex,
          )
        end
      end

      private def self.database_log_context(
        input : MarketData::DatabaseQuoteHistoryInput,
      ) : Hash(Symbol, String)
        {
          :market_source   => input.source,
          :market_universe => input.universe,
          :security_ident  => input.security,
        }
      end
    end
  end
end
