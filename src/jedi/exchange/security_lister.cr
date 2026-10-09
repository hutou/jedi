module Jedi
  module Exchange
    class SecurityLister
      def initialize(@conn_db : DB::Connection)
      end

      def call(regex = nil,
               *,
               option_csv = false,
               option_headers = false,
               option_extended = false,
               option_running = false,
               option_records = nil,
               option_columns = nil)
        validate_list_options!(option_csv,
          option_headers,
          option_columns
        )
        all_securities = load_all_securities

        selected_securities =
          select_securities(
            all_securities,
            regex: regex,
            option_records: option_records,
            option_running: option_running,
            option_extended: option_extended
          )

        render_securities(
          selected_securities,
          total_count: all_securities.size,
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
            key: "security.list.option_csv_missing",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        if option_columns && option_csv
          raise LowLevelError.new(
            key: "infra.incompatible_options",
            context: {:opt1 => "--csv", :opt2 => "--column-indexes"},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end

      private def load_all_securities : Array(Security)
        Securities.new(@conn_db).fetch.to_a
      end

      # ============================================================
      # Selection flows
      # ============================================================

      private def select_securities(securities : Array(Security),
                                    *,
                                    regex,
                                    option_records,
                                    option_running : Bool,
                                    option_extended : Bool) : Array(Security)
        selected = filter_running(securities, option_running)
        selected = filter_by_regex(selected, regex, option_extended)
        selected = select_by_records(selected, option_records)
        selected
      end

      private def filter_running(securities : Array(Security),
                                 option_running : Bool) : Array(Security)
        return securities unless option_running

        security_ids = [] of PkId
        TradingSystem::Trades.new(@conn_db).fetch.each do |trade|
          lastop = trade.operations.last?
          next if lastop.nil?
          security_ids << trade.security.id if lastop.stock > 0
        end

        securities.select do |security|
          security.id.in?(security_ids)
        end
      end

      private def filter_by_regex(securities : Array(Security),
                                  regex : String?,
                                  option_extended) : Array(Security)
        return securities if regex.nil?
        allowed_fields = ["id", "isin", "name", "ticker"]
        if option_extended
          allowed_fields += ["date", "website", "mode"]
        end
        tree = Jedi::Core::FilterExpression.compile(regex, allowed_fields)

        securities.select do |security|
          named_fields = {
            "id"     => [security.id.to_s],
            "isin"   => [security.isin],
            "name"   => [security.name],
            "ticker" => [security.ticker],
          }
          if option_extended
            named_fields["date"] = [security.quotation_date.to_s]
            named_fields["website"] = [security.quotation_website.to_s]
            named_fields["mode"] = [security.quotation_mode.to_s]
          end

          all_fields_text = named_fields.values.flatten.compact.join(" ")
          ok = Jedi::Core::FilterExpression.matches?(tree, all_fields_text, named_fields)
        end
      end

      private def select_by_records(securities : Array(Security),
                                    option_records) : Array(Security)
        return securities if option_records.nil?

        Jedi::Core::Collection.select_records(securities, option_records)
      end

      # ============================================================
      # Rendering
      # ============================================================

      private def render_securities(securities : Array(Security),
                                    *,
                                    total_count : Int32,
                                    option_extended : Bool,
                                    option_csv : Bool,
                                    option_headers : Bool,
                                    option_columns : String?) : String
        if securities.empty?
          App.info(key: "infra.no_match")
          return ""
        end
        if option_csv
          render_csv(
            securities,
            option_extended: option_extended,
            option_headers: option_headers
          )
        else
          render_table(
            securities,
            total_count: total_count,
            option_extended: option_extended,
            option_columns: option_columns
          )
        end
      end

      private def render_csv(securities : Array(Security),
                             *,
                             option_extended : Bool,
                             option_headers : Bool)
        CSV.build do |csv|
          if option_headers
            if option_extended
              csv.row *Security::Fields.types.keys
            else
              csv.row *Security::Fields.types.keys[0..-6]
            end
          end
          securities.each do |s|
            if option_extended
              csv.row s.id, s.isin, s.name, s.ticker, s.tick_buy.value,
                s.tick_sell.value, s.tax, s.quotation_date, s.quotation_website,
                s.quotation_mode, s.quotation_price, s.quotation_variation
            else
              csv.row s.id, s.isin, s.name, s.ticker, s.tick_buy.value,
                s.tick_sell.value, s.tax
            end
          end
        end
      end

      private def render_table(securities : Array(Security),
                               *,
                               total_count : Int32,
                               option_extended : Bool,
                               option_columns : String?)
        title = if securities.size == total_count
                  I18n.t("security.list.table.title.all")
                elsif securities.size == 1
                  I18n.t("security.list.table.title.one")
                else
                  I18n.t("security.list.table.title.some")
                end
        table = Tablo::Table.new(securities,
          title: Tablo::Heading.new(title, framed: true)) do |t|
          t.add_column(:id, header: I18n.t("security.list.table.id"), &.id)
          t.add_column(:isin, header: I18n.t("security.list.table.isin"), &.isin)
          t.add_column(:name, header: I18n.t("security.list.table.name"), &.name)
          t.add_column(:ticker, header: I18n.t("security.list.table.ticker"),
            &.ticker)
          t.add_column(:tick_buy, header: I18n.t("security.list.table.tick_buy"),
            body_formatter: ->(x : Tablo::CellType) {
              Tablo::Functions.fp_align(x.as(Float), 4, :no_dot)
            }, &.tick_buy.value)
          t.add_column(:tick_sell, header: I18n.t("security.list.table.tick_sell"),
            body_formatter: ->(x : Tablo::CellType) {
              Tablo::Functions.fp_align(x.as(Float), 4, :no_dot)
            }, &.tick_sell.value)
          t.add_column(:tax, header: I18n.t("security.list.table.tax"),
            body_formatter: ->(x : Tablo::CellType) {
              Tablo::Functions.fp_align(x.as(Float), 4, :blank)
            }, &.tax)
          if option_extended
            t.add_group(I18n.t("security.list.table.descriptive_info"),
              formatter: ->(value : Tablo::CellType, width : Int32) {
                Tablo::Functions.stretch(value.as(String), target_width: width,
                  fill_char: ' ', max_fill: 2, prefix: "<<< ",
                  suffix: " >>>")
              })
            t.add_column(I18n.t("security.list.table.quotation_date")) { |n|
              if (dt = n.quotation_date).nil?
                ""
              else
                if n.quotation_mode == "eod"
                  dt.to_s("%F")
                else
                  dt.to_s("%F %T %:z")
                end
              end
            }
            t.add_column(I18n.t("security.list.table.quotation_website")) { |n|
              n.quotation_website.nil? ? "" : n.quotation_website.as(String)
            }
            t.add_column(I18n.t("security.list.table.quotation_mode")) { |n|
              n.quotation_mode.nil? ? "" : n.quotation_mode.as(String)
            }
            t.add_column(I18n.t("security.list.table.quotation_price"),
              header_alignment: Tablo::Justify::Left,
              body_formatter: ->(x : Tablo::CellType) {
                x.is_a?(String) ? x : Tablo::Functions.fp_align(x.as(Float), 4, :no_dot)
              }) { |n| n.quotation_price.nil? ? I18n.t("infra.na") : n.quotation_price.as(Float64) }
            t.add_column(I18n.t("security.list.table.quotation_variation"),
              body_formatter: ->(x : Tablo::CellType) {
                x.is_a?(String) ? x : Tablo::Functions.fp_align(x.as(Float), 2, :dot_zero) + "%"
              }) { |n| n.quotation_variation.nil? ? I18n.t("infra.na") : n.quotation_variation.as(Float64) }
            t.add_group(I18n.t("security.list.table.last_quotation"),
              formatter: ->(value : Tablo::CellType, width : Int32) {
                Tablo::Functions.stretch(value.as(String), target_width: width,
                  fill_char: ' ', max_fill: 2, prefix: "<<< ",
                  suffix: " >>>")
              })
          end
        end.pack
        if option_columns
          max_index = option_extended ? 11 : 6
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
