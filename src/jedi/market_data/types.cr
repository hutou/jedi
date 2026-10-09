module Jedi
  module MarketData
    alias Quote = NamedTuple(
      date: Time,
      open: Float64,
      high: Float64,
      low: Float64,
      close: Float64,
      volume: Int64)

    struct SecurityInfo
      getter isin : String
      getter ticker : String
      getter name : String

      def initialize(
        @isin : String,
        @ticker : String,
        @name : String,
      )
      end
    end

    struct SecurityListEntry
      getter isin : String
      getter ticker : String
      getter name : String
      getter datasets : Array(String)
      getter groups : Array(String)

      def initialize(
        @isin : String,
        @ticker : String,
        @name : String,
        @datasets : Array(String),
        @groups : Array(String),
      )
      end
    end

    struct MarketGroupInfo
      getter code : String
      getter reference_source : String?
      getter reference_date : Time?
      getter synchronized_at : String?

      def initialize(
        @code : String,
        @reference_source : String? = nil,
        @reference_date : Time? = nil,
        @synchronized_at : String? = nil,
      )
      end
    end

    struct DatasetInfo
      getter code : String
      getter name : String
      getter history_from : Time?

      def initialize(
        @code : String,
        @name : String,
        @history_from : Time? = nil,
      )
      end
    end

    struct QuoteRow
      getter isin : String
      getter quote : Quote

      def initialize(@isin : String, @quote : Quote)
      end
    end

    # Describes a quotation whose fields are syntactically valid but whose
    # OHLCV values are inconsistent. Such a record may be skipped by a tolerant
    # importer without hiding structural CSV errors.
    struct QuoteAnomaly
      getter isin : String
      getter date : Time
      getter quote : Quote
      getter reason : String
      getter line_number : Int32
      getter record : String

      def initialize(
        @isin : String,
        @date : Time,
        @quote : Quote,
        @reason : String,
        @line_number : Int32,
        @record : String,
      )
      end
    end

    # Describes an existing quotation that differs materially from the incoming
    # quotation during a non-destructive dataset update. The stored quotation
    # is kept and the incoming one is skipped.
    struct QuoteConflict
      getter isin : String
      getter date : Time
      getter stored : Quote
      getter incoming : Quote

      def initialize(
        @isin : String,
        @date : Time,
        @stored : Quote,
        @incoming : Quote,
      )
      end
    end
  end
end
