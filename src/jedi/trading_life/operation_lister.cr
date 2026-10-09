module Jedi
  module TradingLife
    class OperationLister
      alias OperationGroups = Hash(PkId, Array(Operation))

      getter conn_db

      def initialize(@conn_db : DB::Connection)
      end

      def call(regex = nil,
               *,
               option_records = nil,
               option_columns = nil,
               option_group = false,
               option_running = false,
               option_csv = false,
               option_extended = false,
               option_headers = false,
               from_play = nil)
        validate_list_options!(
          option_records,
          option_group,
          option_running,
          option_csv,
          option_extended,
          option_headers,
          option_columns
        )

        all_operations = load_all_operations
        all_operations_size = all_operations.size
        selected_operations =
          if option_group
            list_grouped_flow(
              all_operations,
              regex: regex,
              option_records: option_records,
              option_running: option_running,
              option_csv: option_csv,
              option_extended: option_extended
            )
          else
            list_flat_flow(
              all_operations,
              regex: regex,
              option_records: option_records,
              option_csv: option_csv,
              option_extended: option_extended
            )
          end
        render_operations(
          selected_operations,
          all_operations_size: all_operations_size,
          option_columns: option_columns,
          option_csv: option_csv,
          option_extended: option_extended,
          option_headers: option_headers,
          from_play: from_play
        )
      end

      private def validate_list_options!(option_records,
                                         option_group,
                                         option_running,
                                         option_csv,
                                         option_extended,
                                         option_headers,
                                         option_columns,) : Nil
        if option_records && option_group
          unless option_records =~ /^[lf]\d+$/i
            raise LowLevelError.new(
              key: "operation.list.option_group_records",
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
        end
        if option_running && !option_group
          raise LowLevelError.new(
            key: "operation.list.option_group_missing",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        if (option_extended || option_headers) && !option_csv
          raise LowLevelError.new(
            key: "operation.list.option_csv_missing",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        if option_columns && option_csv
          raise LowLevelError.new(
            key: "infra.incompatible_options",
            context: {:opt1 => "--csv", :opt2 => "--column-indexes"},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end

      private def load_all_operations : Array(Operation)
        Operations.new(conn_db).fetch.to_a
      end

      # ============================================================
      # Selection flows
      # ============================================================

      private def list_flat_flow(operations : Array(Operation),
                                 *,
                                 regex,
                                 option_records,
                                 option_csv,
                                 option_extended) : Array(Operation)
        filtered = filter_by_regex(operations, regex, option_csv, option_extended)
        select_by_records(filtered, option_records)
      end

      private def list_grouped_flow(operations : Array(Operation),
                                    *,
                                    regex,
                                    option_records,
                                    option_running,
                                    option_csv,
                                    option_extended) : Array(Operation)
        groups = group_operations_by_trade(operations)
        groups = filter_groups_by_running(groups, option_running)
        groups = select_records_in_groups(groups, option_records)
        groups = filter_groups_by_regex(groups, regex, option_csv, option_extended)
        flatten_groups(groups)
      end

      # ============================================================
      # Group helpers
      # ============================================================

      private def group_operations_by_trade(
        operations : Array(Operation),
      ) : OperationGroups
        groups = {} of PkId => Array(Operation)

        operations.each do |op|
          trade_id = op.settings.trade.id
          groups[trade_id] ||= [] of Operation
          groups[trade_id] << op
        end

        groups.each_value do |ops|
          ops.sort_by! { |op| {op.timestamp, op.id} }
        end

        groups
      end

      private def filter_groups_by_running(
        groups : OperationGroups,
        option_running : Bool,
      ) : OperationGroups
        return groups unless option_running

        groups.select do |_, ops|
          lastop = ops.last?
          !lastop.nil? && lastop.stock != 0
        end.to_h
      end

      private def select_records_in_groups(
        groups : OperationGroups,
        option_records,
      ) : OperationGroups
        return groups if option_records.nil?

        selected = {} of PkId => Array(Operation)

        groups.each do |trade_id, ops|
          selected[trade_id] =
            Jedi::Core::Collection.select_records(ops, option_records)
        end

        selected
      end

      private def filter_groups_by_regex(groups : OperationGroups,
                                         regex,
                                         option_csv,
                                         option_extended) : OperationGroups
        return groups if regex.nil?
        allowed_fields = ["id", "timestamp", "type", "mode"]
        if option_extended || !option_csv
          allowed_fields += ["trade", "security", "scale"]
        end
        tree = Core::FilterExpression.compile(regex, allowed_fields)
        filtered = {} of PkId => Array(Operation)
        groups.each do |trade_id, ops|
          filtered[trade_id] = ops.select do |op|
            named_fields = {
              "id"        => [op.id.to_s],
              "timestamp" => [op.timestamp.to_s],
              "type"      => [op.type.to_s],
              "mode"      => [op.mode.to_s],
            }
            if option_extended || !option_csv
              named_fields["trade"] = [op.trade.name]
              named_fields["security"] = [op.trade.security.name]
              named_fields["scale"] = [op.scale.name]
            end
            all_fields_text = named_fields.values.flatten.compact.join(" ")
            ok = Jedi::Core::FilterExpression.matches?(tree, all_fields_text, named_fields)
          end
        end
        filtered
      end

      private def flatten_groups(groups : OperationGroups) : Array(Operation)
        operations = [] of Operation

        groups.each_value do |ops|
          operations.concat(ops)
        end

        operations
      end

      # ============================================================
      # Flat helpers
      # ============================================================

      private def filter_by_regex(operations : Array(Operation),
                                  regex : String?,
                                  option_csv,
                                  option_extended) : Array(Operation)
        return operations if regex.nil?
        allowed_fields = ["id", "timestamp", "type", "mode"]
        if option_extended || !option_csv
          allowed_fields += ["trade", "security", "scale"]
        end
        tree = Core::FilterExpression.compile(regex, allowed_fields)

        operations.select do |op|
          named_fields = {
            "id"        => [op.id.to_s],
            "timestamp" => [op.timestamp.to_s],
            "type"      => [op.type.to_s],
            "mode"      => [op.mode.to_s],
          }
          if option_extended || !option_csv
            named_fields["trade"] = [op.trade.name]
            named_fields["security"] = [op.trade.security.name]
            named_fields["scale"] = [op.scale.name]
          end
          all_fields_text = named_fields.values.flatten.compact.join(" ")
          ok = Jedi::Core::FilterExpression.matches?(tree, all_fields_text, named_fields)
        end
      end

      private def select_by_records(
        operations : Array(Operation),
        option_records,
      ) : Array(Operation)
        return operations if option_records.nil?
        Jedi::Core::Collection.select_records(operations, option_records)
      end

      # ============================================================
      # Rendering
      # ============================================================

      private def render_operations(operations : Array(Operation),
                                    *,
                                    all_operations_size : Int32,
                                    option_columns,
                                    option_csv : Bool,
                                    option_extended : Bool,
                                    option_headers : Bool,
                                    from_play) : String
        if operations.empty?
          App.info(key: "infra.no_match")
          return ""
        end

        if option_csv
          render_csv(
            operations,
            option_extended: option_extended,
            option_headers: option_headers
          )
        else
          render_table(
            operations,
            all_operations_size: all_operations_size,
            option_columns: option_columns,
            from_play: from_play
          )
        end
      end

      private def render_csv(operations : Array(Operation),
                             *,
                             option_extended : Bool,
                             option_headers : Bool)
        CSV.build do |csv|
          if option_headers
            if option_extended
              hdr = Operation::Fields.types.keys + {:trade_name, :security_name}
              csv.row *hdr
            else
              hdr = Operation::Fields.types.keys
              csv.row *hdr
            end
          end
          operations.each do |op|
            if option_extended
              csv.row op.id, op.timestamp, op.type, op.mode, op.quantity, op.price,
                op.buy, op.sell, op.trade_invest, op.global_invest, op.fees, op.stock,
                op.position, op.ksp, op.kcp, op.settings_id, op.trade.name, op.trade.security.name
            else
              csv.row op.id, op.timestamp, op.type, op.mode, op.quantity, op.price,
                op.buy, op.sell, op.trade_invest, op.global_invest, op.fees, op.stock,
                op.position, op.ksp, op.kcp, op.settings_id
            end
          end
        end
      end

      private def render_table(operations : Array(Operation),
                               *,
                               all_operations_size : Int32,
                               option_columns,
                               from_play) : String
        price_precision = Tablo::Functions.fp_reduce_precision(operations.map(&.price), 4)
        kcp_precision = Tablo::Functions.fp_reduce_precision(operations.map(&.kcp), 6)
        ksp_precision = Tablo::Functions.fp_reduce_precision(operations.map(&.ksp), 6)

        title = if operations.size == all_operations_size
                  I18n.t("operation.list.table.title.all")
                elsif operations.size == 1
                  I18n.t("operation.list.table.title.one")
                else
                  I18n.t("operation.list.table.title.some")
                end

        omit_last_rule = if from_play.nil? # from prod
                           false
                         elsif from_play.empty? # from simulation seed
                           true
                         else # form simulation operation
                           false
                         end
        table = Tablo::Table.new(
          operations,
          omit_last_rule: omit_last_rule,
          title: Tablo::Heading.new(title, framed: true)
        ) do |t|
          if from_play.nil? || from_play.empty? # from prod or simul from seed
            t.add_column(:c0, header: I18n.t("operation.list.table.id"), &.id)
          else
            t.add_column(:c0, header: I18n.t("operation.list.table.id")) { |n|
              from_play[n.id]
            }
          end
          t.add_column(:c1, header: I18n.t("operation.list.table.trade_name"),
            &.trade.name)
          t.add_column(:c2, header: I18n.t("operation.list.table.security_name"),
            &.trade.security.name)
          t.add_column(:c3, header: I18n.t("operation.list.table.sg"), &.settings.id)
          t.add_column(:c4, header: I18n.t("operation.list.table.scale_name"), &.scale.name)

          # if option_columns == 8 || option_columns == 9
          if from_play.nil? || from_play.empty?
            t.add_column(:c5, header: I18n.t("operation.list.table.dateonly"),
              &.timestamp.to_s("%Y-%m-%d"))
          else
            t.add_column(:c5, header: I18n.t("operation.list.table.timestamp"),
              &.timestamp.to_s("%Y-%m-%d %H:%M:%S %:z"))
          end

          t.add_column(:c6, header: I18n.t("operation.list.table.type"), &.type.to_s)
          t.add_column(:c7, header: I18n.t("operation.list.table.mode"), &.mode.to_s)
          t.add_column(:c8, header: I18n.t("operation.list.table.quantity"), &.quantity)

          t.add_column(:c9,
            header: I18n.t("operation.list.table.price"),
            header_alignment: Tablo::Justify::Center,
            body_formatter: ->(x : Tablo::CellType) {
              Tablo::Functions.fp_align(x.as(Float), price_precision, :no_dot)
            }, &.price)

          t.add_column(:c10, header: I18n.t("operation.list.table.position")) { |n|
            "#{n.settings.rank} #{n.position}"
          }

          t.add_column(:c11,
            header: I18n.t("operation.list.table.buy"),
            body_formatter: ->(x : Tablo::CellType) {
              x == 0.0 ? "" : "%.2f" % x.as(Float64)
            }) { |n| n.buy / 100 }

          t.add_column(:c12,
            header: I18n.t("operation.list.table.sell"),
            body_formatter: ->(x : Tablo::CellType) {
              x == 0.0 ? "" : "%.2f" % x.as(Float64)
            }) { |n| n.sell / 100 }

          t.add_column(:c13,
            header: I18n.t("operation.list.table.gains_losses"),
            body_formatter: ->(x : Tablo::CellType) {
              x == 0.0 ? "" : "%.2f" % x.as(Float64)
            }) { |n| n.price * n.stock - n.trade_invest / 100 }

          t.add_column(:c14,
            header: I18n.t("operation.list.table.trade_invest"),
            body_formatter: ->(x : Tablo::CellType) {
              x == 0.0 ? "" : "%.2f" % x.as(Float64)
            }) { |n| n.trade_invest / 100 }

          t.add_column(:c15,
            header: I18n.t("operation.list.table.global_invest"),
            body_formatter: ->(x : Tablo::CellType) {
              x == 0.0 ? "" : "%.2f" % x.as(Float64)
            }) { |n| n.global_invest / 100 }

          t.add_column(:c16,
            header: I18n.t("operation.list.table.fees"),
            body_formatter: ->(x : Tablo::CellType) {
              x == 0.0 ? "" : "%.2f" % x.as(Float64)
            }) { |n| n.fees / 100 }

          t.add_column(:c17, header: I18n.t("operation.list.table.stock_held"), &.stock)

          t.add_column(:c18,
            header: I18n.t("operation.list.table.ksp"),
            header_alignment: Tablo::Justify::Center,
            body_formatter: ->(x : Tablo::CellType) {
              Tablo::Functions.fp_align(x.as(Float), ksp_precision, :no_dot)
            }, &.ksp)

          t.add_column(:c19,
            header: I18n.t("operation.list.table.kcp"),
            header_alignment: Tablo::Justify::Center,
            body_formatter: ->(x : Tablo::CellType) {
              Tablo::Functions.fp_align(x.as(Float), kcp_precision, :no_dot)
            }, &.kcp)
        end

        packed = table.pack
        if (x = from_play).nil?
          # Call from prod
          render_standard_layout(packed, option_columns)
        elsif x.empty?
          # call from simulation play, bootstrap from seed
          render_layout_from_seed(table, packed, option_columns)
        else
          # call from simulation play, bootstrap from operation
          render_standard_layout(packed, option_columns)
        end
      end

      private def render_layout_from_seed(table, packed, option_columns) : String
        summary_def = [
          Tablo::Summary::UserProc.new(
            proc: ->(tbl : Tablo::Table(Operation)) {
              sum_buys = sum_sells = sum_fees = 0.0
              tbl.sources.each do |source|
                sum_buys += source.buy
                sum_sells += source.sell
                sum_fees += source.fees
              end
              sum_buys /= 100
              sum_sells /= 100
              sum_fees /= 100
              {
                :sum_buys  => sum_buys.as(Tablo::CellType),
                :sum_sells => sum_sells.as(Tablo::CellType),
                :sum_fees  => sum_fees.as(Tablo::CellType),
              }
            }),
          Tablo::Summary::BodyColumn.new(:c10, alignment: Tablo::Justify::Right),
          Tablo::Summary::BodyColumn.new([:c11, :c12, :c16].map(&.as(Tablo::LabelType)),
            alignment: Tablo::Justify::Right,
            formatter: ->(value : Tablo::CellType) { "%.2f" % value.as(Float64) }),
          Tablo::Summary::BodyRow.new(:c10, 10, I18n.t("trade.results.list.table.total")),
          Tablo::Summary::BodyRow.new(:c11, 10, -> { Tablo::Summary.use(:sum_buys) }),
          Tablo::Summary::BodyRow.new(:c12, 10, -> { Tablo::Summary.use(:sum_sells) }),
          Tablo::Summary::BodyRow.new(:c16, 10, -> { Tablo::Summary.use(:sum_fees) }),
        ]

        table.add_summary(summary_def, masked_headers: true)
        summary = table.summary.as(Tablo::Table).pack
        if option_columns
          indexes, reordered = Core::Input.parse_column_indexes(
            option_columns, 19)
          packed.using_column_indexes(indexes, reordered: reordered).to_s + "\n" +
            summary.using_column_indexes(indexes, reordered: reordered).to_s
        else
          packed.to_s + "\n" + summary.to_s
        end
      end

      private def render_standard_layout(packed, option_columns) : String
        if option_columns
          indexes, reordered = Core::Input.parse_column_indexes(
            option_columns, 19)
          packed.using_column_indexes(indexes, reordered: reordered).to_s
        else
          packed.to_s
        end
      end
    end
  end
end
