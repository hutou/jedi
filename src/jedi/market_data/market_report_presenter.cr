module Jedi
  module MarketData
    class MarketReportPresenter
      LIST_LIMIT = 20

      getter report : ImportReport

      def initialize(@report : ImportReport)
      end

      def to_s : String
        title = I18n.t("market.report.title")

        String.build do |io|
          io << title << '\n'
          io << "-" * title.size << '\n'

          fields = report_fields
          width = fields.max_of { |field| field[0].size }

          fields.each do |field|
            io << field[0].ljust(width) << " : " << field[1] << '\n'
          end

          append_operation_lists(io)
          append_list(io, I18n.t("market.report.warnings"), report.warnings)
        end.rstrip
      end

      private def report_fields : Array(Tuple(String, String))
        fields = [] of Tuple(String, String)

        fields << {
          I18n.t("market.report.operation"),
          I18n.t("market.operations.#{report.operation.code}"),
        }
        if source = report.market_source
          fields << {I18n.t("market.report.source"), source}
        end

        if universe = report.market_universe
          fields << {I18n.t("market.report.universe"), universe}
        end

        fields << {I18n.t("market.report.database"), report.database_filename}

        if source_filename = report.source_filename
          fields << {
            I18n.t("market.report.source_filename"),
            source_filename,
          }
        end

        if dataset = report.dataset_code
          fields << {I18n.t("market.report.dataset"), dataset}
        end

        if group = report.group_code
          fields << {I18n.t("market.report.group"), group}
        end

        unless report.dataset_codes.empty?
          fields << {
            I18n.t("market.report.datasets"),
            report.dataset_codes.join(", "),
          }
        end

        if security = report.security
          fields << {I18n.t("market.report.isin"), security.isin}
          fields << {I18n.t("market.report.ticker"), security.ticker}
          fields << {I18n.t("market.report.name"), security.name}
        end

        case report.operation
        when ImportOperation::Init
          nil
        when ImportOperation::Import, ImportOperation::Replace
          fields << count_field("labels_read", report.labels_read)
          fields << count_field("securities_read", report.securities_read)
          fields << count_field("securities_inserted", report.securities_inserted)
          fields << count_field("securities_linked", report.securities_linked)
          fields << count_field("quotes_read", report.quotes_read)
          fields << count_field("quotes_inserted", report.quotes_inserted)
          fields << count_field("quotes_linked", report.quotes_linked)
          fields << count_field(
            "quotes_skipped_before_start",
            report.quotes_skipped_before_start
          )
          fields << count_field(
            "quotes_skipped_without_label",
            report.quotes_skipped_without_label
          )
          fields << count_field(
            "quotes_skipped_invalid",
            report.quotes_skipped_invalid
          )
          fields << count_field(
            "invalid_quote_isins_count",
            report.invalid_quote_isins.size.to_i64
          )
          fields << count_field("identical_duplicates", report.identical_duplicates)

          if report.operation == ImportOperation::Replace
            fields << count_field("quotes_removed", report.quotes_removed)
            fields << count_field("securities_removed", report.securities_removed)
          end
          append_period(fields)
        when ImportOperation::Update
          fields << count_field("labels_read", report.labels_read)
          fields << count_field("securities_read", report.securities_read)
          fields << count_field("securities_inserted", report.securities_inserted)
          fields << count_field("securities_linked", report.securities_linked)
          fields << count_field("quotes_read", report.quotes_read)
          fields << count_field("quotes_inserted", report.quotes_inserted)
          fields << count_field("quotes_linked", report.quotes_linked)
          fields << count_field(
            "quotes_skipped_before_start",
            report.quotes_skipped_before_start
          )
          fields << count_field(
            "quotes_skipped_without_label",
            report.quotes_skipped_without_label
          )
          fields << count_field(
            "quotes_skipped_invalid",
            report.quotes_skipped_invalid
          )
          fields << count_field(
            "invalid_quote_isins_count",
            report.invalid_quote_isins.size.to_i64
          )
          fields << count_field(
            "quotes_skipped_conflicting",
            report.quotes_skipped_conflicting
          )
          fields << count_field("identical_duplicates", report.identical_duplicates)
          append_period(fields, "update_period")
          append_update_continuity(fields)
        when ImportOperation::SyncGroup
          fields << count_field("group_rows_read", report.group_rows_read)
          fields << count_field(
            "group_references_read",
            report.group_references_read
          )
          fields << count_field("group_matched", report.group_matched)
          fields << count_field(
            "unknown_isins_count",
            report.unknown_isins.size.to_i64
          )
          fields << count_field(
            "group_added_count",
            report.added_group_isins.size.to_i64
          )
          fields << count_field(
            "group_removed_count",
            report.removed_group_isins.size.to_i64
          )
        end

        fields
      end

      private def append_operation_lists(io : IO) : Nil
        case report.operation
        when ImportOperation::Import, ImportOperation::Replace, ImportOperation::Update
          append_list(
            io,
            I18n.t("market.report.isins_without_label"),
            report.unknown_isins
          )
          append_quote_anomalies(io)
          append_quote_conflicts(io) if report.operation == ImportOperation::Update
        when ImportOperation::SyncGroup
          append_list(
            io,
            I18n.t("market.report.unknown_group_references"),
            report.unknown_isins
          )
          append_list(
            io,
            I18n.t("market.report.group_added"),
            report.added_group_isins
          )
          append_list(
            io,
            I18n.t("market.report.group_removed"),
            report.removed_group_isins
          )
        else
          nil
        end
      end

      private def append_update_continuity(
        fields : Array(Tuple(String, String)),
      ) : Nil
        if date = report.dataset_date_last_before
          fields << {
            I18n.t("market.report.dataset_date_last_before"),
            date.to_s("%F"),
          }
        end

        if date = report.extension_date_first
          fields << {
            I18n.t("market.report.extension_date_first"),
            date.to_s("%F"),
          }
        end

        if report.gap_allowed
          if days = report.gap_days
            fields << {
              I18n.t("market.report.accepted_gap"),
              I18n.t(
                "market.report.accepted_gap_value",
                {days: days.to_s}
              ),
            }
          end
        end
      end

      private def append_quote_anomalies(io : IO) : Nil
        return if report.quotes_skipped_invalid == 0

        title = I18n.t("market.report.invalid_quotes")
        io << '\n' << title << " (" << report.quotes_skipped_invalid << "):" << '\n'

        report.quote_anomalies.first(LIST_LIMIT).each do |anomaly|
          io << "  - " << anomaly_text(anomaly) << '\n'
        end

        remaining = report.quotes_skipped_invalid -
                    report.quote_anomalies.first(LIST_LIMIT).size.to_i64

        if remaining > 0
          io << "  "
          io << I18n.t(
            "market.report.remaining_items",
            {count: remaining.to_s}
          )
          io << '\n'
        end
      end

      private def anomaly_text(anomaly : QuoteAnomaly) : String
        quote = anomaly.quote

        "#{anomaly.isin} #{anomaly.date.to_s("%F")} " \
        "(line #{anomaly.line_number}): #{anomaly.reason}; " \
        "O=#{quote[:open]} H=#{quote[:high]} L=#{quote[:low]} " \
        "C=#{quote[:close]} V=#{quote[:volume]}"
      end

      private def append_quote_conflicts(io : IO) : Nil
        return if report.quotes_skipped_conflicting == 0

        title = I18n.t("market.report.conflicting_quotes")
        io << '\n' << title << " (" << report.quotes_skipped_conflicting << "):" << '\n'

        report.quote_conflicts.first(LIST_LIMIT).each do |conflict|
          io << "  - " << conflict_text(conflict) << '\n'
        end

        remaining = report.quotes_skipped_conflicting -
                    report.quote_conflicts.first(LIST_LIMIT).size.to_i64

        if remaining > 0
          io << "  "
          io << I18n.t(
            "market.report.remaining_items",
            {count: remaining.to_s}
          )
          io << '\n'
        end
      end

      private def conflict_text(conflict : QuoteConflict) : String
        "#{conflict.isin} #{conflict.date.to_s("%F")}: " \
        "stored [#{quote_text(conflict.stored)}], " \
        "incoming [#{quote_text(conflict.incoming)}]"
      end

      private def quote_text(quote : Quote) : String
        "O=#{quote[:open]} H=#{quote[:high]} L=#{quote[:low]} " \
        "C=#{quote[:close]} V=#{quote[:volume]}"
      end

      private def append_period(
        fields : Array(Tuple(String, String)),
        key : String = "period",
      ) : Nil
        first = report.date_first
        last = report.date_last
        return unless first && last

        fields << {
          I18n.t("market.report.#{key}"),
          "#{first.to_s("%F")} → #{last.to_s("%F")}",
        }
      end

      private def count_field(key : String, value : Int64) : Tuple(String, String)
        {I18n.t("market.report.#{key}"), value.to_s}
      end

      private def append_list(
        io : IO,
        title : String,
        values : Array(String),
      ) : Nil
        return if values.empty?

        io << '\n' << title << " (" << values.size << "):" << '\n'

        values.first(LIST_LIMIT).each do |value|
          io << "  - " << value << '\n'
        end

        remaining = values.size - LIST_LIMIT
        if remaining > 0
          io << "  "
          io << I18n.t(
            "market.report.remaining_items",
            {count: remaining.to_s}
          )
          io << '\n'
        end
      end
    end
  end
end
