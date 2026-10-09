module Jedi
  module MarketData
    class MarketQuoteLister
      getter database : Database
      getter isin : String
      getter selection : HistorySelection

      def initialize(
        @database : Database,
        @isin : String,
        @selection : HistorySelection = HistorySelection.new,
      )
      end

      def run : String
        result = ""

        database.with_connection do |conn|
          security = SecurityRepository.new(conn).fetch!(isin)
          quotes = QuoteRepository.new(conn).history(isin, selection)

          if quotes.empty?
            App.info(key: "infra.no_match")
            return ""
          end

          title = I18n.t(
            "market.quote.table.title",
            {ticker: security.ticker, isin: security.isin, name: security.name}
          )

          price_precision = Tablo::Functions.fp_reduce_precision(
            quotes.flat_map { |quote| [quote[:open], quote[:high], quote[:low], quote[:close]] },
            4
          )
          price_formatter = ->(x : Tablo::CellType) {
            Tablo::Functions.fp_align(x.as(Float), price_precision, :no_dot)
          }

          result = Tablo::Table.new(
            quotes,
            title: Tablo::Heading.new(title, framed: true)
          ) do |table|
            table.add_column(:date, header: I18n.t("market.quote.table.date")) { |quote| quote[:date].to_s("%F") }
            table.add_column(
              :open,
              header: I18n.t("market.quote.table.open"),
              header_alignment: Tablo::Justify::Center,
              body_formatter: price_formatter
            ) { |quote| quote[:open] }
            table.add_column(
              :high,
              header: I18n.t("market.quote.table.high"),
              header_alignment: Tablo::Justify::Center,
              body_formatter: price_formatter
            ) { |quote| quote[:high] }
            table.add_column(
              :low,
              header: I18n.t("market.quote.table.low"),
              header_alignment: Tablo::Justify::Center,
              body_formatter: price_formatter
            ) { |quote| quote[:low] }
            table.add_column(
              :close,
              header: I18n.t("market.quote.table.close"),
              header_alignment: Tablo::Justify::Center,
              body_formatter: price_formatter
            ) { |quote| quote[:close] }
            table.add_column(:volume, header: I18n.t("market.quote.table.volume")) { |quote| quote[:volume] }
          end.pack.to_s
        end

        result
      end
    end
  end
end
