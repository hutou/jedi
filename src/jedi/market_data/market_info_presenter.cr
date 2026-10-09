module Jedi
  module MarketData
    class MarketInfoPresenter
      getter report : MarketInfoReport

      def initialize(@report : MarketInfoReport)
      end

      def to_s : String
        title = I18n.t("market.info.title")

        String.build do |io|
          io << title << '\n'
          io << "-" * title.size << '\n'
          append_fields(io, global_fields)
          append_groups(io)
          append_datasets(io)
          append_integrity(io)
        end.rstrip
      end

      private def global_fields : Array(Tuple(String, String))
        fields = [] of Tuple(String, String)

        fields << field("source", report.source)
        fields << field("universe", report.universe)
        fields << field("database", report.database_filename)
        fields << field("schema_version", report.schema_version.to_s)
        fields << field("file_size", format_size(report.file_size))
        append_optional(fields, "created_at", report.created_at)
        append_optional(fields, "updated_at", report.updated_at)
        fields << count_field("dataset_count", report.dataset_count)
        fields << count_field("security_count", report.security_count)
        fields << count_field("quote_count", report.quote_count)
        append_period(fields, "period", report.date_first, report.date_last)
        fields << count_field("group_count", report.group_count)

        fields
      end

      private def append_groups(io : IO) : Nil
        title = I18n.t("market.info.groups")
        io << '\n' << title << '\n'
        io << "-" * title.size << '\n'

        if report.groups.empty?
          io << I18n.t("market.info.no_group") << '\n'
          return
        end

        report.groups.each_with_index do |group, index|
          io << '\n' if index > 0
          io << group.code << '\n'

          fields = [] of Tuple(String, String)
          fields << count_field("group_member_count", group.member_count)
          append_optional(fields, "group_reference_source", group.reference_source)
          append_optional(
            fields,
            "group_reference_date",
            group.reference_date.try(&.to_s("%F"))
          )
          append_optional(fields, "group_synchronized_at", group.synchronized_at)
          append_fields(io, fields, 2)
        end
      end

      private def append_datasets(io : IO) : Nil
        title = I18n.t("market.info.datasets")
        io << '\n' << title << '\n'
        io << "-" * title.size << '\n'
        io << I18n.t("market.info.dataset_totals_note") << '\n'

        if report.datasets.empty?
          io << I18n.t("market.info.no_dataset") << '\n'
          return
        end

        report.datasets.each_with_index do |dataset, index|
          io << '\n' if index > 0
          io << dataset_title(dataset) << '\n'

          fields = [] of Tuple(String, String)
          fields << count_field("dataset_security_count", dataset.security_count)
          fields << count_field("dataset_quote_count", dataset.quote_count)
          append_period_or_unavailable(
            fields,
            "dataset_import_period",
            dataset.import_date_first,
            dataset.import_date_last
          )
          append_period(
            fields,
            "dataset_current_period",
            dataset.current_date_first,
            dataset.current_date_last
          )
          fields << field(
            "dataset_freshness_date_last",
            dataset.freshness_date_last.try(&.to_s("%F")) ||
            I18n.t("market.info.freshness_unavailable")
          )
          unless dataset.group_counts.empty?
            fields << field(
              "dataset_groups",
              dataset.group_counts.map { |code, count| "#{code}: #{count}" }.join(", ")
            )
          end
          append_optional(
            fields,
            "dataset_history_from",
            dataset.history_from.try(&.to_s("%F"))
          )
          fields << field("dataset_quotes_file", dataset.quotes_filename)
          fields << field("dataset_labels_file", dataset.labels_filename)
          fields << field("dataset_imported_at", dataset.imported_at)
          append_fields(io, fields, 2)
        end
      end

      private def append_integrity(io : IO) : Nil
        title = I18n.t("market.info.integrity.title")
        io << '\n' << title << '\n'
        io << "-" * title.size << '\n'

        integrity = report.integrity
        fields = [] of Tuple(String, String)
        fields << count_field(
          "securities_without_dataset",
          integrity.securities_without_dataset,
          "market.info.integrity"
        )
        fields << count_field(
          "datasets_without_security",
          integrity.datasets_without_security,
          "market.info.integrity"
        )
        fields << count_field(
          "securities_without_quote",
          integrity.securities_without_quote,
          "market.info.integrity"
        )
        fields << count_field(
          "quotes_without_dataset",
          integrity.quotes_without_dataset,
          "market.info.integrity"
        )
        fields << count_field(
          "dataset_stats_mismatches",
          integrity.dataset_stats_mismatches,
          "market.info.integrity"
        )
        fields << count_field(
          "foreign_key_violations",
          integrity.foreign_key_violations,
          "market.info.integrity"
        )
        status_key = if integrity.valid?
                       "market.info.integrity.ok"
                     else
                       "market.info.integrity.failed"
                     end
        fields << {
          I18n.t("market.info.integrity.result"),
          I18n.t(status_key),
        }

        append_fields(io, fields)
      end

      private def append_fields(
        io : IO,
        fields : Array(Tuple(String, String)),
        indent : Int32 = 0,
      ) : Nil
        return if fields.empty?

        width = fields.max_of { |field| field[0].size }
        padding = " " * indent

        fields.each do |field|
          io << padding
          io << field[0].ljust(width)
          io << " : " << field[1] << '\n'
        end
      end

      private def append_period(
        fields : Array(Tuple(String, String)),
        key : String,
        first : Time?,
        last : Time?,
      ) : Nil
        return unless first && last

        fields << {
          I18n.t("market.info.#{key}"),
          "#{first.to_s("%F")} → #{last.to_s("%F")}",
        }
      end

      private def append_period_or_unavailable(
        fields : Array(Tuple(String, String)),
        key : String,
        first : Time?,
        last : Time?,
      ) : Nil
        value = if first && last
                  "#{first.to_s("%F")} → #{last.to_s("%F")}"
                else
                  I18n.t("market.info.not_available")
                end

        fields << {I18n.t("market.info.#{key}"), value}
      end

      private def append_optional(
        fields : Array(Tuple(String, String)),
        key : String,
        value : String?,
      ) : Nil
        if text = value
          fields << field(key, text)
        end
      end

      private def field(
        key : String,
        value : String,
        prefix : String = "market.info",
      ) : Tuple(String, String)
        {I18n.t("#{prefix}.#{key}"), value}
      end

      private def count_field(
        key : String,
        value : Int64,
        prefix : String = "market.info",
      ) : Tuple(String, String)
        field(key, value.to_s, prefix)
      end

      private def dataset_title(dataset : DatasetSummary) : String
        return dataset.code if dataset.name == dataset.code
        "#{dataset.code} — #{dataset.name}"
      end

      private def format_size(bytes : Int64) : String
        units = {"B", "KiB", "MiB", "GiB"}
        value = bytes.to_f
        index = 0

        while value >= 1024.0 && index < units.size - 1
          value /= 1024.0
          index += 1
        end

        if index == 0
          "#{bytes} #{units[index]}"
        else
          "%.1f %s" % [value, units[index]]
        end
      end
    end
  end
end
