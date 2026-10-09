module Jedi
  module TradingSystem
    class TradeStatus
      record DisplayData, sort_key : Float64, trade_name : String, security_name : String,
        q0 : Float64, c0 : Float64, stock : Int32, quot_price : Float64?,
        quot_var : Float64?, unit_cost : Float64, years : Float64,
        oper_count : Int32, timeline : String, settings_count : Int32,
        position : String

      private getter conn_db

      def initialize(@conn_db : DB::Connection)
      end

      def list(*, regex : String? = nil, option_update_now : Bool) : String
        filter = Core::FilterExpression.compile(regex, ["name", "security"])
        display_data = [] of DisplayData
        running_count = 0

        TradingSystem::Trades.new(conn_db).fetch.each do |trade|
          rec = TradingSystem::TradeMetrics.new(trade).calculate
          next if rec.nil? || rec.stock == 0

          running_count += 1
          next unless matches?(trade, filter)

          Exchange::QuoteResolver.new(trade.security).price(
            option_update_now: option_update_now)
          sort_key = if trade.security.quotation_variation.nil?
                       Float64::MIN
                     else
                       trade.security.quotation_variation.as(Float64)
                     end

          display_data << DisplayData.new(
            sort_key: sort_key,
            trade_name: trade.name,
            security_name: trade.security.name,
            q0: rec.q0,
            c0: rec.c0,
            stock: rec.stock,
            quot_price: trade.security.quotation_price,
            quot_var: trade.security.quotation_variation,
            unit_cost: (rec.buys - rec.sells) / (rec.stock * 100),
            years: (rec.duration / 365).round(2),
            oper_count: rec.operation_count,
            timeline: rec.timeline,
            settings_count: trade.settings_chain.size,
            position: rec.position.to_s)
        end

        if display_data.empty?
          App.warn(key: "infra.no_match")
          return ""
        end

        title = if display_data.size == running_count
                  I18n.t("trade.status.list.table.title.all")
                elsif display_data.size > 1
                  I18n.t("trade.status.list.table.title.many")
                else
                  I18n.t("trade.status.list.table.title.one")
                end

        table = Tablo::Table.new(display_data.sort { |a, b| b.sort_key <=> a.sort_key },
          title: Tablo::Heading.new(title, framed: true)) do |t|
          t.add_column(:trade_name, header: I18n.t("trade.status.list.table.trade_name"),
            &.trade_name)
          t.add_column(:security_name, header: I18n.t("trade.status.list.table.security_name"),
            &.security_name)
          t.add_column(:initial_quantity, header: I18n.t("trade.status.list.table.initial_quantity"),
            header_alignment: Tablo::Justify::Center,
            body_formatter: ->(value : Tablo::CellType) {
              Tablo::Functions.fp_align(value.as(Float), 1, :no_dot)
            }, &.q0)
          t.add_column(:initial_price, header: I18n.t("trade.status.list.table.initial_price"),
            header_alignment: Tablo::Justify::Center,
            body_formatter: ->(value : Tablo::CellType) {
              Tablo::Functions.fp_align(value.as(Float), 4, :no_dot)
            }, &.c0)
          t.add_column(:stock_held, header: I18n.t("trade.status.list.table.stock_held"),
            &.stock)
          t.add_column(:quot_price, header: I18n.t("trade.status.list.table.quot_price"),
            header_alignment: Tablo::Justify::Center,
            body_formatter: ->(value : Tablo::CellType) {
              value.nil? ? I18n.t("trade.status.list.table.nil_value") : Tablo::Functions.fp_align(value.as(Float), 4, :no_dot)
            }, &.quot_price)
          t.add_column(:quot_var, header: I18n.t("trade.status.list.table.quot_var"),
            header_alignment: Tablo::Justify::Center,
            body_formatter: ->(value : Tablo::CellType) {
              value.nil? ? I18n.t("trade.status.list.table.nil_value") : Tablo::Functions.fp_align(value.as(Float), 2,
                :dot_zero) + "%"
            }, &.quot_var)
          t.add_column(:unit_cost, header: I18n.t("trade.status.list.table.unit_cost"),
            header_alignment: Tablo::Justify::Center,
            body_formatter: ->(value : Tablo::CellType) {
              Tablo::Functions.fp_align(value.as(Float), 2, :no_dot)
            }, &.unit_cost)
          t.add_column(:year_dur, header: I18n.t("trade.status.list.table.year_dur"),
            header_alignment: Tablo::Justify::Center,
            body_formatter: ->(value : Tablo::CellType) {
              "%.2f" % value.as(Float64)
            }, &.years)
          t.add_column(:op_cnt, header: I18n.t("trade.status.list.table.op_cnt"),
            &.oper_count)
          t.add_column(:oper_freq, header: I18n.t("trade.status.list.table.oper_freq"),
            body_alignment: Tablo::Justify::Right, &.timeline)
          t.add_column(:position, header: I18n.t("trade.status.list.table.position")) { |n|
            n.settings_count.to_s + " " + n.position
          }
        end

        table.pack.to_s
      end

      private def matches?(trade : TradingSystem::Trade,
                           filter : Core::FilterExpression::FilterTree?) : Bool
        named_fields = {
          "name"     => [trade.name],
          "security" => [trade.security.name],
        }
        all_fields_text = named_fields.values.flatten.join(" ")
        Core::FilterExpression.matches?(filter, all_fields_text, named_fields)
      end
    end
  end
end
