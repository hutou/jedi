module Jedi
  module TradingSystem
    class TradeResults
      private getter conn_db

      def initialize(@conn_db : DB::Connection)
      end

      record DisplayData, trade_name : String, security_name : String, gains : Int32,
        gains_day : Int32, fees : Int32, portfolio : Int32, current_investment : Int32,
        maximum_investment : Int32, annualized_return : Float64

      record CollectionData, display_data : Array(DisplayData), trade_count : Int32,
        sum_gains : Int32, sum_fees : Int32, sum_portfolio : Int32,
        sum_current_investment : Int32, sum_net_current_investment : Int32

      record SummaryData, sum_gains : Int32, sum_fees : Int32, sum_portfolio : Int32,
        sum_current_investment : Int32, sum_net_current_investment : Int32,
        global_maximum_investment : Int32, gross_annualized_return : Float64,
        net_annualized_return : Float64

      def list(*, regex : String? = nil, option_running : Bool = false,
               option_update_now : Bool = true, option_chronological : Bool = false,
               option_global_maximum_investment : Int32? = nil) : String
        filter = Core::FilterExpression.compile(regex, ["name", "security"])
        operations = TradingLife::Operations.new(conn_db).fetch
        return no_match if operations.empty?

        global_maximum_investment = option_global_maximum_investment ||
                                    calculate_global_maximum_investment(operations)
        summary_days = positive_duration(
          (Time.local - operations.first.timestamp).total_days.to_i
        )

        collection = collect_data(
          filter: filter,
          option_running: option_running,
          option_update_now: option_update_now
        )
        display_data = if option_chronological
                         # collect_data loads trades in creation order (id).
                         collection.display_data
                       else
                         collection.display_data.sort do |a, b|
                           b.annualized_return <=> a.annualized_return
                         end
                       end
        return no_match if display_data.empty?

        title, has_summary = table_title(display_data.size, collection.trade_count)
        summary_data = build_summary_data(
          collection,
          global_maximum_investment,
          summary_days
        )

        render(display_data, summary_data, title, has_summary,
          option_chronological: option_chronological)
      end

      private def collect_data(*, filter : Core::FilterExpression::FilterTree?, option_running : Bool,
                               option_update_now : Bool) : CollectionData
        display_data = [] of DisplayData
        sum_gains = sum_fees = sum_portfolio = sum_current_investment = 0
        sum_net_current_investment = 0
        trade_count = 0

        TradingSystem::Trades.new(conn_db).fetch.each do |trade|
          metrics = TradingSystem::TradeMetrics.new(trade).calculate
          next if metrics.nil?

          trade_count += 1
          next if option_running && metrics.stock == 0
          next unless matches?(trade, filter)

          portfolio = portfolio_value(trade, metrics, option_update_now)
          gains = portfolio + metrics.sells - metrics.buys
          duration = positive_duration(metrics.duration)

          sum_gains += gains
          sum_fees += metrics.fees
          sum_portfolio += portfolio
          sum_current_investment += metrics.current_investment if metrics.current_investment > 0
          sum_net_current_investment += metrics.current_investment

          display_data << DisplayData.new(
            trade_name: trade.name,
            security_name: trade.security.name,
            gains: gains,
            gains_day: gains // duration,
            fees: metrics.fees,
            portfolio: portfolio,
            current_investment: metrics.current_investment,
            maximum_investment: metrics.maximum_investment,
            annualized_return: calculate_annualized_return(
              gains,
              metrics.maximum_investment,
              duration
            )
          )
        end

        CollectionData.new(
          display_data: display_data,
          trade_count: trade_count,
          sum_gains: sum_gains,
          sum_fees: sum_fees,
          sum_portfolio: sum_portfolio,
          sum_current_investment: sum_current_investment,
          sum_net_current_investment: sum_net_current_investment
        )
      end

      private def portfolio_value(
        trade : TradingSystem::Trade,
        metrics : TradingSystem::TradeMetrics::Data,
        option_update_now : Bool,
      ) : Int32
        return 0 if metrics.stock == 0

        price = Exchange::QuoteResolver.new(trade.security).price(
          option_update_now: option_update_now)
        price.nil? ? 0 : (metrics.stock * price * 100).to_i
      end

      private def calculate_global_maximum_investment(
        operations : TradingLife::Operations,
      ) : Int32
        maximum = sum_buys = sum_sells = 0

        operations.each do |operation|
          sum_buys += operation.buy
          sum_sells += operation.sell
          maximum = [maximum, sum_buys - sum_sells].max
        end

        maximum
      end

      private def build_summary_data(
        collection : CollectionData,
        global_maximum_investment : Int32,
        summary_days : Int32,
      ) : SummaryData
        SummaryData.new(
          sum_gains: collection.sum_gains,
          sum_fees: collection.sum_fees,
          sum_portfolio: collection.sum_portfolio,
          sum_current_investment: collection.sum_current_investment,
          sum_net_current_investment: collection.sum_net_current_investment,
          global_maximum_investment: global_maximum_investment,
          gross_annualized_return: calculate_annualized_return(
            collection.sum_gains,
            global_maximum_investment,
            summary_days
          ),
          net_annualized_return: calculate_annualized_return(
            collection.sum_gains - collection.sum_fees,
            global_maximum_investment,
            summary_days
          )
        )
      end

      private def table_title(display_count : Int32,
                              trade_count : Int32) : Tuple(String, Bool)
        if display_count == 1
          {I18n.t("trade.results.list.table.title.one"), false}
        elsif display_count == trade_count
          {I18n.t("trade.results.list.table.title.all"), true}
        else
          {I18n.t("trade.results.list.table.title.many"), false}
        end
      end

      private def render(display_data : Array(DisplayData),
                         summary_data : SummaryData,
                         title : String,
                         has_summary : Bool,
                         *, option_chronological : Bool) : String
        table = Tablo::Table.new(
          display_data,
          omit_last_rule: has_summary,
          title: Tablo::Heading.new(title, framed: true)
        ) do |t|
          add_columns(t, summary_data, option_chronological: option_chronological)
        end.pack
        return table.to_s unless has_summary
        table.add_summary(summary_def(table, summary_data), masked_headers: true)
        table.summary.as(Tablo::Table).pack
        table.to_s + "\n" + table.summary.to_s
      end

      private def add_columns(table : Tablo::Table(DisplayData),
                              summary_data : SummaryData,
                              *, option_chronological : Bool) : Nil
        table.add_column(:trade_name, header: I18n.t("trade.results.list.table.trade_name"),
          &.trade_name)
        table.add_column(:security_name, header: I18n.t("trade.results.list.table.security_name"),
          &.security_name)
        table.add_column(:gains_losses, header: I18n.t("trade.results.list.table.gains_losses"),
          body_formatter: ->(value : Tablo::CellType) {
            "%.2f" % (value.as(Int32) / 100)
          }, &.gains)
        table.add_column(:gain_loss_day, header: I18n.t("trade.results.list.table.gain_loss_day"),
          body_formatter: ->(value : Tablo::CellType) {
            value == 0 ? "" : "%.2f" % (value.as(Int32) / 100)
          }) { |n| n.portfolio == 0 ? 0 : n.gains_day }
        table.add_column(:brokers_fees, header: I18n.t("trade.results.list.table.brokers_fees"),
          body_formatter: ->(value : Tablo::CellType) {
            "%.2f" % (value.as(Int32) / 100)
          }, &.fees)
        table.add_column(:eval_portf, header: I18n.t("trade.results.list.table.eval_portf"),
          body_formatter: ->(value : Tablo::CellType) {
            value == 0 ? "" : "%.2f" % (value.as(Int32) / 100)
          }, &.portfolio)
        table.add_column(:pct_portf, header: I18n.t("trade.results.list.table.pct_portf")) { |n|
          if summary_data.sum_portfolio == 0
            ""
          else
            pct = percentage(n.portfolio, summary_data.sum_portfolio)
            pct == 0 ? "" : "%.1f%%" % pct
          end
        }
        investment_header = if option_chronological
                              I18n.t("trade.results.list.table.cash_investment_balance")
                            else
                              I18n.t("trade.results.list.table.current_invest")
                            end
        table.add_column(:current_invest, header: investment_header,
          body_formatter: ->(value : Tablo::CellType) {
            "%.2f" % (value.as(Int32) / 100)
          }, &.current_investment)
        table.add_column(:pct_inv, header: I18n.t("trade.results.list.table.pct_inv"),
          header_alignment: Tablo::Justify::Right,
          body_alignment: Tablo::Justify::Right,
        ) { |n|
          if summary_data.sum_current_investment == 0
            ""
          else
            pct = percentage(n.current_investment, summary_data.sum_current_investment)
            pct <= 0 ? "" : "%.1f%%" % pct
          end
        }
        table.add_column(:maximum_invest, header: I18n.t("trade.results.list.table.maximum_invest"),
          body_formatter: ->(value : Tablo::CellType) {
            "%.2f" % (value.as(Int32) / 100)
          }, &.maximum_investment)
        return_header = if option_chronological
                          I18n.t("trade.results.list.table.return_rate_unsorted")
                        else
                          I18n.t("trade.results.list.table.return_rate")
                        end
        table.add_column(:return_rate, header: return_header,
          body_formatter: ->(value : Tablo::CellType) {
            "%.1f%%" % value.as(Float64)
          }, &.annualized_return)
      end

      private def summary_def(table : Tablo::Table(DisplayData),
                              summary_data : SummaryData)
        summary_def = [
          Tablo::Summary::UserProc.new(
            proc: ->(_tbl : Tablo::Table(DisplayData)) {
              {
                :sum_gains                  => summary_data.sum_gains.as(Tablo::CellType),
                :sum_fees                   => summary_data.sum_fees.as(Tablo::CellType),
                :sum_current_investment     => summary_data.sum_current_investment.as(Tablo::CellType),
                :sum_net_current_investment => summary_data.sum_net_current_investment.as(Tablo::CellType),
                :sum_gains_net              => (summary_data.sum_gains - summary_data.sum_fees).as(Tablo::CellType),
                :sum_portfolio              => summary_data.sum_portfolio.as(Tablo::CellType),
                :global_maximum_investment  => summary_data.global_maximum_investment.as(Tablo::CellType),
                :gross_annualized_return    => summary_data.gross_annualized_return.as(Tablo::CellType),
                :net_annualized_return      => summary_data.net_annualized_return.as(Tablo::CellType),
              }
            }),
          Tablo::Summary::BodyColumn.new(:security_name, alignment: Tablo::Justify::Right),
          Tablo::Summary::BodyColumn.new(:return_rate, formatter: ->(value : Tablo::CellType) {
            value.nil? ? "" : "%.1f%%" % value.as(Float64)
          }),
          Tablo::Summary::BodyColumn.new([:gains_losses, :brokers_fees, :current_invest,
                                          :maximum_invest].map &.as(Tablo::LabelType),
            formatter: ->(value : Tablo::CellType) {
              value.nil? ? "" : "%.2f" % (value.as(Int32) / 100)
            }),
          Tablo::Summary::BodyColumn.new(:eval_portf, formatter: ->(value : Tablo::CellType) {
            value.nil? || value.as(Int32) == 0 ? "" : "%.2f" % (value.as(Int32) / 100)
          }),
          Tablo::Summary::BodyRow.new(:security_name, 10, I18n.t("trade.results.list.table.total")),
          Tablo::Summary::BodyRow.new(:security_name, 20, I18n.t("trade.results.list.table.net")),
          Tablo::Summary::BodyRow.new(:gains_losses, 10, -> { Tablo::Summary.use(:sum_gains) }),
          Tablo::Summary::BodyRow.new(:gains_losses, 20, -> { Tablo::Summary.use(:sum_gains_net) }),
          Tablo::Summary::BodyRow.new(:brokers_fees, 10, -> { Tablo::Summary.use(:sum_fees) }),
          Tablo::Summary::BodyRow.new(:eval_portf, 10, -> { Tablo::Summary.use(:sum_portfolio) }),
          Tablo::Summary::BodyRow.new(:current_invest, 10, -> { Tablo::Summary.use(:sum_current_investment) }),
          Tablo::Summary::BodyRow.new(:current_invest, 20, -> { Tablo::Summary.use(:sum_net_current_investment) }),
          Tablo::Summary::BodyRow.new(:maximum_invest, 10, -> { Tablo::Summary.use(:global_maximum_investment) }),
          Tablo::Summary::BodyRow.new(:return_rate, 10, -> { Tablo::Summary.use(:gross_annualized_return) }),
          Tablo::Summary::BodyRow.new(:return_rate, 20, -> { Tablo::Summary.use(:net_annualized_return) }),
        ]
      end

      private def calculate_annualized_return(gains : Int32, investment : Int32,
                                              duration : Int32) : Float64
        return 0.0 if investment <= 0

        (((gains + investment).to_f / investment) **
          (365.0 / positive_duration(duration)) - 1) * 100
      end

      private def percentage(value : Int32, total : Int32) : Float64
        return 0.0 if total == 0

        value.to_f / total * 100
      end

      private def positive_duration(duration : Int32) : Int32
        duration > 0 ? duration : 1
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

      private def no_match : String
        App.warn(key: "infra.no_match")
        ""
      end
    end
  end
end
