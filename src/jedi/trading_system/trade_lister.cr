module Jedi
  module TradingSystem
    class TradeLister
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
        validate_list_options!(option_csv, option_headers, option_columns)
        all_trades = load_all_trades
        all_trades_size = all_trades.size

        selected_trades = select_trades(all_trades,
          regex: regex,
          option_records: option_records,
          option_running: option_running,
          option_extended: option_extended
        )
        render_trades(
          selected_trades,
          all_trades_size: all_trades_size,
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
            key: "trade.list.option_csv_missing",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        if option_columns && option_csv
          raise LowLevelError.new(
            key: "infra.incompatible_options",
            context: {:opt1 => "--csv", :opt2 => "--column-indexes"},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end

      private def load_all_trades : Array(Trade)
        Trades.new(@conn_db).fetch.to_a
      end

      # ============================================================
      # Selection flows
      # ============================================================

      private def select_trades(trades : Array(Trade),
                                *,
                                regex,
                                option_records : String?,
                                option_running : Bool,
                                option_extended : Bool) : Array(Trade)
        selected = filter_running(trades, option_running)
        selected = filter_by_regex(selected, regex, option_extended)
        selected = select_by_records(selected, option_records)
        selected
      end

      private def filter_running(
        trades : Array(Trade),
        option_running : Bool,
      ) : Array(Trade)
        return trades unless option_running

        trades.select do |trade|
          lastop = trade.operations.last?
          !((x = lastop).nil? || x.stock.zero?)
        end
      end

      private def filter_by_regex(trades : Array(Trade),
                                  regex,
                                  option_extended) : Array(Trade)
        return trades if regex.nil?
        allowed_fields = ["id", "name", "money", "stop"]
        if option_extended
          allowed_fields += ["isin", "security"]
        end
        tree = Jedi::Core::FilterExpression.compile(regex, allowed_fields)

        trades.select do |trade|
          named_fields = {
            "id"    => [trade.id.to_s],
            "name"  => [trade.name],
            "money" => [trade.money.to_s],
            "stop"  => [trade.stop.to_s],
          }
          if option_extended
            named_fields["isin"] = [trade.security.isin]
            named_fields["security"] = [trade.security.name]
          end
          all_fields_text = named_fields.values.flatten.compact.join(" ")
          ok = Jedi::Core::FilterExpression.matches?(tree, all_fields_text, named_fields)
        end
      end

      private def select_by_records(trades : Array(Trade),
                                    option_records) : Array(Trade)
        return trades if option_records.nil?

        Jedi::Core::Collection.select_records(trades, option_records)
      end

      # ============================================================
      # Rendering
      # ============================================================

      private def render_trades(trades,
                                *,
                                all_trades_size : Int32,
                                option_extended : Bool,
                                option_csv : Bool,
                                option_headers : Bool,
                                option_columns : String?)
        if trades.empty?
          App.info(key: "infra.no_match")
          return ""
        end
        if option_csv
          render_csv(
            trades,
            option_extended: option_extended,
            option_headers: option_headers
          )
        else
          render_table(
            trades,
            all_trades_size: all_trades_size,
            option_extended: option_extended,
            option_columns: option_columns
          )
        end
      end

      private def render_csv(trades : Array(Trade),
                             *,
                             option_extended : Bool,
                             option_headers : Bool)
        CSV.build do |csv|
          if option_headers
            if option_extended
              hdr = {:id, :name, :status, :money, :stop, :security_id,
                     :security_isin, :security_name}
              csv.row *hdr
            else
              hdr = {:id, :name, :status, :money, :stop, :security_id}
              csv.row *hdr
            end
          end
          trades.each do |trade|
            if option_extended
              csv.row trade.id, trade.name, trade.lifecycle_status.to_s.underscore,
                trade.money, trade.stop, trade.security_id,
                trade.security.isin, trade.security.name
            else
              csv.row trade.id, trade.name, trade.lifecycle_status.to_s.underscore,
                trade.money, trade.stop, trade.security_id
            end
          end
        end
      end

      private def render_table(trades : Array(Trade),
                               *,
                               all_trades_size : Int32,
                               option_extended : Bool,
                               option_columns : String?)
        title = if trades.size == all_trades_size
                  I18n.t("trade.list.table.title.all")
                elsif trades.size == 1
                  I18n.t("trade.list.table.title.one")
                else
                  I18n.t("trade.list.table.title.some")
                end
        table = Tablo::Table.new(trades,
          title: Tablo::Heading.new(title, framed: true)) do |t|
          t.add_column(:id, header: I18n.t("trade.list.table.id"), &.id)
          t.add_column(:name, header: I18n.t("trade.list.table.name"), &.name)
          t.add_column(:status, header: I18n.t("trade.list.table.status")) do |trade|
            I18n.t("trade.list.status.#{trade.lifecycle_status.to_s.underscore}")
          end
          t.add_column(:money, header: I18n.t("trade.list.table.money"), &.money.to_s)
          t.add_column(:stop, header: I18n.t("trade.list.table.stop")) { |n|
            (x = n.stop).nil? ? "" : x.to_s
          }
          if option_extended
            t.add_column(:security_id, header: I18n.t("trade.list.table.security_id"), &.security.id)
            t.add_column(:security_isin, header: I18n.t("trade.list.table.security_isin"), &.security.isin)
            t.add_column(:security_name, header: I18n.t("trade.list.table.security_name"), &.security.name)
          end
        end.pack
        if option_columns
          max_index = option_extended ? 7 : 4
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
