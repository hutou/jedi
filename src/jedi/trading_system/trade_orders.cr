module Jedi
  module TradingSystem
    class TradeOrders
      record DisplayData,
        trade_name : String?,
        scale_name : String?,
        security_name : String?,
        security_held : String?,
        type : String,
        mode : String,
        quantity : String,
        price : Float64?,
        amount : Float64,
        position : String,
        rate : String,
        mark : String

      private record TradeRows,
        rows : Array(DisplayData),
        separators : Array(Bool)

      private getter conn_db
      property trades = [] of TradingSystem::Trade

      def initialize(@conn_db : DB::Connection)
      end

      def list(*,
               regex : String? = nil,
               option_net_stop : Bool,
               option_update_now : Bool,
               option_tick_buy : Float64? = nil,
               option_tick_sell : Float64? = nil)
        self.trades = [] of TradingSystem::Trade
        filter = Core::FilterExpression.compile(regex, ["name", "security"])

        running_trades = 0
        select_running_trades(filter) do |trade|
          running_trades += 1
          trades << trade
        end
        if trades.empty?
          App.warn(key: "infra.no_match")
          return ""
        end

        update_selected_trade_ticks!(option_tick_buy, option_tick_sell)

        rows = build_table_rows(option_net_stop, option_update_now)
        if rows.rows.empty?
          App.warn(key: "infra.no_match")
          return ""
        end

        display_rows(rows.rows, rows.separators, running_trades)
      end

      private def select_running_trades(filter : Core::FilterExpression::FilterTree?, &)
        TradingSystem::Trades.new(conn_db).fetch.each do |trade|
          next unless running_trade?(trade)
          next unless selected_trade?(trade, filter)
          yield trade
        end
      end

      private def running_trade?(trade) : Bool
        last_operation = trade.last_operation
        return false if last_operation.nil?
        !last_operation.stock.zero?
      end

      private def selected_trade?(trade : TradingSystem::Trade,
                                  filter : Core::FilterExpression::FilterTree?) : Bool
        named_fields = {
          "name"     => [trade.name],
          "security" => [trade.security.name],
        }
        all_fields_text = named_fields.values.flatten.join(" ")
        Core::FilterExpression.matches?(filter, all_fields_text, named_fields)
      end

      private def update_selected_trade_ticks!(option_tick_buy : Float64?, option_tick_sell : Float64?)
        return if option_tick_buy.nil? && option_tick_sell.nil?

        if trades.size != 1
          raise LowLevelError.new(
            key: "trade.orders.error_tick_update",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        security_id = trades.first.security.id

        unless option_tick_buy.nil?
          conn_db.exec("UPDATE security SET tick_buy = ? WHERE id = ?", option_tick_buy, security_id)
        end

        unless option_tick_sell.nil?
          conn_db.exec("UPDATE security SET tick_sell = ? WHERE id = ?", option_tick_sell, security_id)
        end
      end

      private def old_build_table_rows(option_net_stop : Bool, option_update_now : Bool) : TradeRows
        rows = [] of DisplayData
        separators = [] of Bool

        trades.sort_by(&.security.name).each do |trade|
          built_rows = build_trade_rows(trade, option_net_stop, option_update_now)
          next if built_rows.empty?

          rows.concat(built_rows)
          built_rows.size.times do |index|
            separators << (index == built_rows.size - 1)
          end
        end

        separators[-1] = false unless separators.empty?
        TradeRows.new(rows, separators)
      end

      private def build_table_rows(option_net_stop : Bool, option_update_now : Bool) : TradeRows
        rows = [] of DisplayData
        separators = [] of Bool
        warn = false
        trades.sort_by(&.security.name).each do |trade|
          begin
            built_rows = build_trade_rows(trade, option_net_stop, option_update_now)
            next if built_rows.empty?

            rows.concat(built_rows)
            built_rows.size.times do |index|
              separators << (index == built_rows.size - 1)
            end
          rescue ex : LowLevelError
            App.capture_exception(
              ex,
              log_context: {
                :trade_id => trade.id.to_s,
                :trade    => trade.name,
              }
            )
            ref = Core::Utils.ref(trade.name)
            App.warn(key: "trade.orders.calculation_failed",
              params: {:ref => ref})
            warn = true
            next
          end
        end
        App.info(key: "trade.orders.see_logfile",
          params: {:logfile => "#{App.log_file}"}) if warn

        separators[-1] = false unless separators.empty?
        TradeRows.new(rows, separators)
      end

      private def build_trade_rows(trade,
                                   option_net_stop : Bool,
                                   option_update_now : Bool) : Array(DisplayData)
        last_settings = trade.last_settings
        return [] of DisplayData if last_settings.nil?

        engine = TradingSystem::OrderEngine.new(trade)
        orders = engine.orders(option_net_stop, option_update_now)
        add_operating_warnings(trade, engine)
        return [] of DisplayData if orders.empty?

        current_price = Exchange::QuoteResolver.new(trade.security).price(
          option_update_now: option_update_now)

        order_keys = ordered_visible_order_keys(orders)
        return [] of DisplayData if order_keys.empty?

        headers = build_headers(trade, last_settings, current_price, orders, order_keys)

        order_keys.compact_map do |dir|
          order = orders[dir]?
          next nil if order.nil?
          build_display_row(trade, last_settings, dir, order, headers[dir])
        end
      end

      private def ordered_visible_order_keys(orders : Hash(Symbol, TradingSystem::OrderEngine::Order))
        [:down, :loss, :up]
          .select { |key| orders.has_key?(key) }
          .sort_by { |key| order_display_rank(key) }
      end

      private def order_display_rank(key) : Int32
        case key
        when :down
          10
        when :loss
          20
        when :up
          30
        else
          99
        end
      end

      private def build_headers(trade, last_settings, current_price, orders, order_keys : Array(Symbol))
        headers = {} of Symbol => Array(String)
        # stock_eval = "(#{display_stock_eval_order(orders).last_stock} @ #{trade.security.quotation_price})"
        price = current_price.nil? ? "???" : current_price
        stock_eval = "(#{display_stock_eval_order(orders).last_stock} @ #{price})"

        first_key = order_keys.first
        headers[first_key] = [
          trade.name,
          last_settings.scale.name,
          orders.size == 1 ? "#{trade.security.name}\n#{stock_eval}" : trade.security.name,
          orders[first_key].last_stock.to_s,
        ]

        order_keys[1..].each_with_index do |key, index|
          headers[key] =
            if index.zero?
              ["", "", stock_eval, ""]
            else
              ["", "", "", ""]
            end
        end
        headers
      end

      private def display_stock_eval_order(orders)
        orders[:loss]? || orders[:up]? || orders[:down]
      end

      private def build_display_row(trade, last_settings, dir : Symbol,
                                    order : TradingSystem::OrderEngine::Order,
                                    header : Array(String)) : DisplayData
        rate, mark = rate_and_mark_for(trade.security, order)
        amount = order.price * order.quantity
        position = display_position_for(trade, dir, order)

        DisplayData.new(
          header[0],
          header[1],
          header[2],
          header[3],
          order.type.to_s,
          order.mode.to_s,
          quantity_label(order, dir),
          order.price,
          amount,
          position,
          rate,
          mark,
        )
      end

      private def quantity_label(order : TradingSystem::OrderEngine::Order, dir : Symbol) : String
        if dir == :loss && (original_quantity = order.original_quantity) && order.quantity != original_quantity
          "#{original_quantity} → #{order.quantity}"
        else
          order.quantity.to_s
        end
      end

      private def add_operating_warnings(
        trade,
        engine : TradingSystem::OrderEngine,
      ) : Nil
        return if engine.operating_warnings.empty?

        engine.operating_warnings.each do |warning|
          # App.messages << "#{trade.name}: #{warning}"
          ref = Core::Utils.ref(trade.name)
          App.warn(key: "trade.orders.operating_warning",
            params: {:ref => ref, :warning => "#{warning}"})
        end
      end

      private def display_position_for(trade, dir : Symbol,
                                       order : TradingSystem::OrderEngine::Order) : String
        case dir
        when :down, :up
          "#{trade.settings_chain.size} #{order.position}"
        else
          if stop = trade.stop
            "#{order.kind}: #{stop.guaranteed_gain}"
          else
            ""
          end
        end
      end

      private def rate_and_mark_for(security, order : TradingSystem::OrderEngine::Order)
        quotation_price = security.quotation_price
        if quotation_price.nil?
          nil_value = I18n.t("trade.orders.list.table.nil_value")
          return {nil_value, nil_value}
        end

        rate = (order.price / quotation_price.as(Float64) - 1) * 100
        {
          "%.2f%%" % rate,
          get_mark(order.type, order.mode, rate, App.watchrate),
        }
      end

      private def display_rows(table_data : Array(DisplayData),
                               separators : Array(Bool),
                               running_trades : Int32)
        table = format_table(running_trades, table_data)
        String.build do |io|
          table.pack.each_with_index do |line, index|
            io << line << "\n"
            io << table.horizontal_rule(Tablo::RuleType::BodyBody) << "\n" if separators[index]
          end
        end
      end

      private def get_mark(type, mode, rate, watchrate)
        mark = case {type, mode}
               when {TradingLife::Operation::Type::Buy, TradingLife::Operation::Mode::Stop},
                    {TradingLife::Operation::Type::Sell, TradingLife::Operation::Mode::Limit}
                 rate < 0.0 ? I18n.t("trade.orders.mark.ready") : ""
               when {TradingLife::Operation::Type::Sell, TradingLife::Operation::Mode::Stop},
                    {TradingLife::Operation::Type::Buy, TradingLife::Operation::Mode::Limit}
                 rate > 0.0 ? I18n.t("trade.orders.mark.ready") : ""
               else
                 ""
               end

        if mark.empty?
          mark = I18n.t("trade.orders.mark.watch") if rate.abs < watchrate.as(Float64)
        end

        mark
      end

      private def format_table(running_trades : Int32, table_data : Array(DisplayData))
        title =
          if trades.size == running_trades
            I18n.t("trade.orders.list.table.title.all")
          elsif trades.size == 1
            I18n.t("trade.orders.list.table.title.one")
          else
            I18n.t("trade.orders.list.table.title.many")
          end

        price_precision = Tablo::Functions.fp_reduce_precision((table_data.map &.price).compact, 4)
        Tablo::Table.new(
          table_data,
          title: Tablo::Heading.new(title, framed: true)
        ) do |t|
          t.add_column(:table_name, header: I18n.t("trade.orders.list.table.name"), &.trade_name)
          t.add_column(:scale_name, header: I18n.t("trade.orders.list.table.scale"), &.scale_name)
          t.add_column(:security_name, header: I18n.t("trade.orders.list.table.security"), &.security_name)
          t.add_group(I18n.t("trade.orders.list.table.name_group"),
            formatter: ->(value : Tablo::CellType, width : Int32) {
              Tablo::Functions.stretch(value.as(String), target_width: width,
                fill_char: ' ', max_fill: 3, prefix: "<<< ",
                suffix: " >>>").upcase
            })
          t.add_column(:order_type, header: I18n.t("trade.orders.list.table.type"), &.type)
          t.add_column(:order_mode, header: I18n.t("trade.orders.list.table.mode"), &.mode)
          t.add_column(:order_qty, header: I18n.t("trade.orders.list.table.qty"),
            header_alignment: Tablo::Justify::Right,
            body_alignment: Tablo::Justify::Right, &.quantity)
          t.add_column(:order_price, header: I18n.t("trade.orders.list.table.price"),
            body_formatter: ->(value : Tablo::CellType) {
              Tablo::Functions.fp_align(value.as(Float), price_precision, :dot_zero)
            }, &.price)
          t.add_column(:order_amount, header: I18n.t("trade.orders.list.table.amount"),
            body_formatter: ->(value : Tablo::CellType) {
              "%.2f" % value.as(Float64)
            }, &.amount)
          t.add_group(I18n.t("trade.orders.list.table.order_group"),
            formatter: ->(value : Tablo::CellType, width : Int32) {
              Tablo::Functions.stretch(value.as(String), target_width: width,
                fill_char: ' ', max_fill: 3, prefix: "<<< ",
                suffix: " >>>").upcase
            })
          t.add_column(:target_position, header: I18n.t("trade.orders.list.table.position"), &.position)
          t.add_column(:target_rate, header: I18n.t("trade.orders.list.table.rate"),
            header_alignment: Tablo::Justify::Right,
            body_alignment: Tablo::Justify::Right, &.rate)
          t.add_column(:target_mark, header: I18n.t("trade.orders.list.table.mark"),
            header_alignment: Tablo::Justify::Center,
            body_alignment: Tablo::Justify::Center, &.mark)
          t.add_group(I18n.t("trade.orders.list.table.target_group"),
            formatter: ->(value : Tablo::CellType, width : Int32) {
              Tablo::Functions.stretch(value.as(String), target_width: width,
                fill_char: ' ', max_fill: 4, prefix: "<<< ",
                suffix: " >>>").upcase
            })
        end
      end
    end
  end
end
