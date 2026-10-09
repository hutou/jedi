module Jedi
  module MarketData
    enum ImportOperation
      Init
      Import
      Replace
      Update
      SyncGroup

      def code : String
        case self
        in Init      then "init"
        in Import    then "import"
        in Replace   then "replace"
        in Update    then "update"
        in SyncGroup then "sync_group"
        end
      end
    end

    class ImportReport
      QUOTE_ANOMALY_DETAIL_LIMIT = 100

      getter operation : ImportOperation
      getter database_filename : String
      getter dataset_code : String?
      getter warnings : Array(String)
      getter unknown_isins : Array(String)
      getter added_group_isins : Array(String)
      getter removed_group_isins : Array(String)
      getter quote_anomalies : Array(QuoteAnomaly)
      getter quote_conflicts : Array(QuoteConflict)
      getter invalid_quote_isins : Array(String)
      getter dataset_codes : Array(String)

      property market_source : String?
      property market_universe : String?
      property source_filename : String?
      property security : SecurityInfo?
      property group_code : String?

      property labels_read : Int64
      property securities_read : Int64
      property securities_inserted : Int64
      property securities_linked : Int64
      property securities_removed : Int64
      property quotes_read : Int64
      property quotes_inserted : Int64
      property quotes_linked : Int64
      property quotes_removed : Int64
      property quotes_skipped_before_start : Int64
      property quotes_skipped_without_label : Int64
      property quotes_skipped_invalid : Int64
      property quotes_skipped_conflicting : Int64
      property identical_duplicates : Int64
      property group_rows_read : Int64
      property group_references_read : Int64
      property group_matched : Int64
      property date_first : Time?
      property date_last : Time?

      # Dataset-update continuity diagnostics.
      property dataset_date_last_before : Time?
      property extension_date_first : Time?
      property gap_days : Int32?
      property gap_allowed : Bool

      def initialize(
        @operation : ImportOperation,
        @database_filename : String,
        @dataset_code : String? = nil,
      )
        @warnings = [] of String
        @unknown_isins = [] of String
        @added_group_isins = [] of String
        @removed_group_isins = [] of String
        @quote_anomalies = [] of QuoteAnomaly
        @quote_conflicts = [] of QuoteConflict
        @invalid_quote_isins = [] of String
        @dataset_codes = [] of String

        @market_source = nil
        @market_universe = nil
        @source_filename = nil
        @security = nil
        @group_code = nil

        @labels_read = 0_i64
        @securities_read = 0_i64
        @securities_inserted = 0_i64
        @securities_linked = 0_i64
        @securities_removed = 0_i64
        @quotes_read = 0_i64
        @quotes_inserted = 0_i64
        @quotes_linked = 0_i64
        @quotes_removed = 0_i64
        @quotes_skipped_before_start = 0_i64
        @quotes_skipped_without_label = 0_i64
        @quotes_skipped_invalid = 0_i64
        @quotes_skipped_conflicting = 0_i64
        @identical_duplicates = 0_i64
        @group_rows_read = 0_i64
        @group_references_read = 0_i64
        @group_matched = 0_i64
        @date_first = nil
        @date_last = nil

        @dataset_date_last_before = nil
        @extension_date_first = nil
        @gap_days = nil
        @gap_allowed = false
      end

      def observe_quote(date : Time) : Nil
        if first = @date_first
          @date_first = date if date < first
        else
          @date_first = date
        end

        if last = @date_last
          @date_last = date if date > last
        else
          @date_last = date
        end
      end

      def add_warning(message : String) : Nil
        @warnings << message
      end

      def add_quote_conflict(conflict : QuoteConflict) : Nil
        @quotes_skipped_conflicting += 1

        if @quote_conflicts.size < QUOTE_ANOMALY_DETAIL_LIMIT
          @quote_conflicts << conflict
        end
      end

      def add_quote_anomaly(anomaly : QuoteAnomaly) : Nil
        @quotes_skipped_invalid += 1

        unless @invalid_quote_isins.includes?(anomaly.isin)
          @invalid_quote_isins << anomaly.isin
        end

        if @quote_anomalies.size < QUOTE_ANOMALY_DETAIL_LIMIT
          @quote_anomalies << anomaly
        end
      end
    end
  end
end
