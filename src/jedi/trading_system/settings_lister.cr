module Jedi
  module TradingSystem
    class SettingsLister
      getter conn_db

      def initialize(@conn_db : DB::Connection)
      end

      def call(*,
               regex = nil,
               option_records = nil,
               option_group = nil,
               option_columns = nil,
               option_running = false)
        all_settings = load_all_settings(option_group)

        selected_settings =
          select_settings(
            all_settings,
            regex: regex,
            option_records: option_records,
            option_running: option_running
          )

        render_settings(
          selected_settings,
          total_count: all_settings.size,
          option_columns: option_columns
        )
      end

      private def load_all_settings(option_group) : Array(Settings)
        if option_group
          sql = "SELECT id FROM settings ORDER BY trade_id, id"
          fetch_settings(sql)
        else
          fetch_settings
        end
      end

      private def select_settings(
        settings_chain : Array(Settings),
        *,
        regex,
        option_records,
        option_running : Bool,
      ) : Array(Settings)
        selected = filter_running(settings_chain, option_running)
        selected = filter_by_regex(selected, regex)
        selected = select_by_records(selected, option_records)
        selected
      end

      private def filter_running(
        settings_chain : Array(Settings),
        option_running : Bool,
      ) : Array(Settings)
        return settings_chain unless option_running

        settings_chain.select do |sg|
          lastop = sg.trade.operations.last?
          !lastop.nil? && !lastop.stock.zero?
        end
      end

      private def filter_by_regex(settings_chain : Array(Settings),
                                  regex : String?) : Array(Settings)
        return settings_chain if regex.nil?
        allowed_fields = ["id", "timestamp", "trade", "security", "scale"]
        tree = Jedi::Core::FilterExpression.compile(regex, allowed_fields)

        settings_chain.select do |settings|
          named_fields = {
            "id"        => [settings.id.to_s],
            "timestamp" => [settings.timestamp.to_s],
            "trade"     => [settings.trade.name],
            "security"  => [settings.trade.security.name],
            "scale"     => [settings.scale.name],
          }
          all_fields_text = named_fields.values.flatten.compact.join(" ")
          ok = Jedi::Core::FilterExpression.matches?(tree, all_fields_text, named_fields)
        end
      end

      private def select_by_records(settings_chain : Array(Settings),
                                    option_records) : Array(Settings)
        return settings_chain if option_records.nil?
        Jedi::Core::Collection.select_records(settings_chain, option_records)
      end

      private def render_settings(settings_chain : Array(Settings),
                                  *,
                                  total_count : Int32,
                                  option_columns)
        if settings_chain.empty?
          App.info(key: "infra.no_match")
          return ""
        end

        qty_precision = Tablo::Functions.fp_reduce_precision(settings_chain.map(&.q0), 4)
        price_precision = Tablo::Functions.fp_reduce_precision(settings_chain.map(&.c0), 4)
        kcpc_precision = Tablo::Functions.fp_reduce_precision(settings_chain.map(&.kcpc), 6)
        kspc_precision = Tablo::Functions.fp_reduce_precision(settings_chain.map(&.kspc), 6)

        title =
          if settings_chain.size == total_count
            I18n.t("settings.list.table.title.all")
          elsif settings_chain.size == 1
            I18n.t("settings.list.table.title.one")
          else
            I18n.t("settings.list.table.title.many")
          end

        table = Tablo::Table.new(
          settings_chain,
          title: Tablo::Heading.new(title, framed: true)
        ) do |t|
          t.add_column(:id, header: I18n.t("settings.list.table.id"), &.id)

          t.add_column(:trade,
            header: I18n.t("settings.list.table.trade"),
            &.trade.name)

          t.add_column(:security,
            header: I18n.t("settings.list.table.security"),
            &.trade.security.name)

          t.add_column(:scale,
            header: I18n.t("settings.list.table.scale"),
            &.scale.name)

          t.add_column(:timestamp,
            header: I18n.t("settings.list.table.timestamp"),
            &.timestamp.to_s("%Y-%m-%d %H:%M:%S %:z"))

          t.add_column(:qty,
            header: I18n.t("settings.list.table.qty"),
            header_alignment: Tablo::Justify::Center,
            body_formatter: ->(x : Tablo::CellType) {
              Tablo::Functions.fp_align(x.as(Float), qty_precision, :no_dot)
            }, &.q0)

          t.add_column(:price,
            header: I18n.t("settings.list.table.price"),
            header_alignment: Tablo::Justify::Center,
            body_formatter: ->(x : Tablo::CellType) {
              Tablo::Functions.fp_align(x.as(Float), price_precision, :no_dot)
            }, &.c0)

          t.add_column(:position,
            header: I18n.t("settings.list.table.position"),
            body_alignment: Tablo::Justify::Center,
            &.position.to_s)

          t.add_column(:split,
            header: I18n.t("settings.list.table.split"),
            body_alignment: Tablo::Justify::Center,
            &.split.to_s)

          t.add_column(:sync,
            header: I18n.t("settings.list.table.sync"),
            body_alignment: Tablo::Justify::Center,
            &.sync.to_s)

          t.add_column(:reinit,
            header: I18n.t("settings.list.table.reinit"),
            body_alignment: Tablo::Justify::Center, &.reinit.to_s)

          t.add_column(:kspc,
            header: I18n.t("settings.list.table.kspc"),
            header_alignment: Tablo::Justify::Center,
            body_formatter: ->(x : Tablo::CellType) {
              Tablo::Functions.fp_align(x.as(Float), kspc_precision, :no_dot)
            }, &.kspc)

          t.add_column(:kcpc,
            header: I18n.t("settings.list.table.kcpc"),
            header_alignment: Tablo::Justify::Center,
            body_formatter: ->(x : Tablo::CellType) {
              Tablo::Functions.fp_align(x.as(Float), kcpc_precision, :no_dot)
            }, &.kcpc)
          t.add_column(:op_count,
            header: I18n.t("settings.list.table.opcount"), &.operation_count)
        end.pack

        if option_columns
          indexes, reordered = Core::Input.parse_column_indexes(
            option_columns, 13)
          table.using_column_indexes(indexes, reordered: reordered).to_s
        else
          table.to_s
        end
      end

      private def fetch_settings(sql = "SELECT id FROM settings ORDER BY id")
        settings_chain = [] of TradingSystem::Settings

        conn_db.query_all(sql, as: PkId).each do |id|
          settings_chain << TradingSystem::Settings.new(conn_db, id)
        end

        settings_chain
      end
    end
  end
end
