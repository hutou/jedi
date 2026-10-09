module Jedi
  module Exchange
    # Identity used to retrieve a quotation.
    #
    # ISIN is always required. Ticker and name are optional complementary data
    # used only when they are already known, typically for a registered Security.
    # This keeps `quote get <isin>` simple while preserving provider-specific
    # strategies that can benefit from ticker or name.
    class QuoteTarget
      getter isin : String
      getter ticker : String?
      getter name : String?

      def initialize(*, isin : String,
                     ticker : String? = nil,
                     name : String? = nil)
        @isin = required_isin(isin)
        @ticker = normalized(ticker)
        @name = normalized(name)
      end

      def self.from(security : Security) : self
        new(
          isin: security.isin,
          ticker: security.ticker,
          name: security.name)
      end

      def value(field : String) : String?
        case field
        when "isin"   then isin
        when "ticker" then ticker
        when "name"   then name
        else               nil
        end
      end

      def primary_symbol : String
        ticker || isin
      end

      def log_context : Hash(Symbol, String)
        {
          :isin   => isin,
          :ticker => ticker || "",
          :name   => name || "",
        } of Symbol => String
      end

      private def required_isin(value : String) : String
        normalized = value.strip.upcase
        return normalized unless normalized.empty?

        raise LowLevelError.new(
          "Quote target requires an ISIN",
          kind: LowLevelError::Kind::Technical,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def normalized(value : String?) : String?
        return nil if value.nil?

        stripped = value.strip
        stripped.empty? ? nil : stripped
      end
    end
  end
end
