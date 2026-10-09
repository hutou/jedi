module Jedi
  module MarketData
    # Historical quotations read from one prepared single-security file.
    struct FileQuoteHistoryInput
      getter filename : String

      def initialize(@filename : String)
      end

      def description : String
        filename
      end
    end

    # Historical quotations read from one security in a market database.
    struct DatabaseQuoteHistoryInput
      getter source : String
      getter security : String
      getter universe : String

      def initialize(
        @source : String,
        @security : String,
        @universe : String,
      )
      end

      def database_name : String
        "#{source}_#{universe}"
      end

      def description : String
        "#{database_name}:#{security}"
      end
    end

    alias QuoteHistoryInput = FileQuoteHistoryInput | DatabaseQuoteHistoryInput
  end
end
