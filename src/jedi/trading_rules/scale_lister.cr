module Jedi
  module TradingRules
    class ScaleLister
      def initialize(@conn_db : DB::Connection)
      end

      def call(regex = nil,
               *,
               option_csv = false,
               option_headers = false,
               option_extended = false,
               option_in_use = false,
               option_records = nil,
               option_columns = nil)
        validate_list_options!(option_csv, option_headers, option_columns)

        all_scales = load_all_scales
        all_scales_size = all_scales.size

        selected_scales = select_scales(
          all_scales,
          regex: regex,
          option_in_use: option_in_use,
          option_records: option_records,
          option_extended: option_extended
        )
        render_scales(
          selected_scales,
          all_scales_size: all_scales_size,
          option_extended: option_extended,
          option_csv: option_csv,
          option_headers: option_headers,
          option_columns: option_columns
        )
      end

      private def validate_list_options!(option_csv,
                                         option_headers,
                                         option_columns) : Nil
        if option_headers && !option_csv
          raise LowLevelError.new(
            key: "scale.list.option_csv_missing",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        if option_columns && option_csv
          raise LowLevelError.new(
            key: "infra.incompatible_options",
            context: {:opt1 => "--csv", :opt2 => "--column-indexes"},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end

      private def load_all_scales : Array(Scale)
        Scales.new(@conn_db).fetch.to_a
      end

      private def select_scales(scales : Array(Scale),
                                *,
                                regex,
                                option_in_use : Bool,
                                option_records : String?,
                                option_extended : Bool) : Array(Scale)
        selected = filter_in_use(scales, option_in_use)
        selected = filter_by_regex(selected, regex, option_extended)
        selected = select_by_records(selected, option_records)
        selected
      end

      private def filter_in_use(scales : Array(Scale),
                                option_in_use) : Array(Scale)
        return scales unless option_in_use
        # scales.select { |scale| scale.status == Scale::Status::InUse }
        scales.select { |scale| TradingRules::ScaleUsage.new(scale).status == Scale::Status::InUse }
      end

      private def filter_by_regex(scales : Array(Scale),
                                  regex : String?,
                                  option_extended) : Array(Scale)
        return scales if regex.nil?
        allowed_fields = ["id", "name", "comment", "status", "type", "optimized"]
        allowed_fields << "definition" if option_extended
        tree = Jedi::Core::FilterExpression.compile(regex, allowed_fields)

        scales.select do |scale|
          status = TradingRules::ScaleUsage.new(scale).status
          named_fields = {
            "id"      => [scale.id.to_s],
            "name"    => [scale.name],
            "comment" => [scale.comment.to_s],
            # "status"    => [scale.status.to_s, scale.status.label],
            "status"    => [status.to_s, status.label],
            "type"      => [scale.operational.type.to_s, scale.operational.type.label],
            "optimized" => [scale.operational.optimized?.to_s,
                            App.bool_label_yn(scale.operational.optimized?)],
          }
          named_fields["definition"] = [scale.operational.definition] if option_extended

          all_fields_text = named_fields.values.flatten.compact.join(" ")
          ok = Jedi::Core::FilterExpression.matches?(tree, all_fields_text, named_fields)
        end
      end

      private def select_by_records(scales : Array(Scale),
                                    option_records) : Array(Scale)
        return scales if option_records.nil?

        Jedi::Core::Collection.select_records(scales, option_records)
      end

      private def render_scales(scales,
                                *,
                                all_scales_size : Int32,
                                option_extended : Bool,
                                option_csv : Bool,
                                option_headers : Bool,
                                option_columns : String?)
        if scales.empty?
          App.info(key: "infra.no_match")
          return ""
        end
        if option_csv
          render_csv(
            scales,
            option_extended: option_extended,
            option_headers: option_headers
          )
        else
          render_table(
            scales,
            all_scales_size: all_scales_size,
            option_extended: option_extended,
            option_columns: option_columns
          )
        end
      end

      def render_csv(scales : Array(Scale),
                     *,
                     option_extended,
                     option_headers)
        CSV.build do |csv|
          if option_headers
            hdr = ["id", "name", "comment", "status", "type", "optimized"]
            hdr << "definition" if option_extended
            csv.row hdr
          end
          scales.each do |scale|
            status = TradingRules::ScaleUsage.new(scale).status
            # body = [scale.id, scale.name, scale.comment, scale.status.label,
            body = [scale.id, scale.name, scale.comment, status.label,
                    scale.operational.type.label, scale.operational.optimized?]
            body << scale.operational.definition if option_extended
            csv.row body
          end
        end
      end

      private def render_table(scales : Array(Scale),
                               *,
                               all_scales_size : Int32,
                               option_extended : Bool,
                               option_columns : String?)
        title = if scales.size == all_scales_size
                  I18n.t("scale.list.table.title.all")
                elsif scales.size == 1
                  I18n.t("scale.list.table.title.one")
                else
                  I18n.t("scale.list.table.title.some")
                end
        table = Tablo::Table.new(scales,
          title: Tablo::Heading.new(title, framed: true)) do |t|
          t.add_column(I18n.t("scale.list.table.id"), &.id)
          t.add_column(I18n.t("scale.list.table.name"), &.name)
          t.add_column(I18n.t("scale.list.table.comment"), &.comment)
          # t.add_column(I18n.t("scale.list.table.status"), &.status.label)
          t.add_column(I18n.t("scale.list.table.status")) { |n|
            status = TradingRules::ScaleUsage.new(n).status
            status.label
          }
          t.add_column(I18n.t("scale.list.table.type"), &.operational.type.label)
          t.add_column(I18n.t("scale.list.table.optimized")) { |n| App.bool_label_yn(n.operational.optimized?) }
          t.add_column(I18n.t("scale.list.table.definition")) { |n|
            TradingRules::ScalePresenter.format_definition(n.operational.definition, 50)
          # n.format_definition(50)
          } if option_extended
        end.pack
        if option_columns
          max_index = option_extended ? 6 : 5
          indexes, reordered = Core::Input.parse_column_indexes(
            option_columns, max_index)
          table.using_column_indexes(indexes, reordered: reordered).to_s
        else
          table.to_s
        end
      end
    end
  end
end
