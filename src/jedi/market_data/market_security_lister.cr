module Jedi
  module MarketData
    class MarketSecurityLister
      FILTER_FIELDS = ["isin", "ticker", "name", "group", "dataset"]

      getter database : Database
      getter dataset_code : String?
      getter regex : String?
      getter last_quote : Bool

      def initialize(
        @database : Database,
        @dataset_code : String? = nil,
        @regex : String? = nil,
        @last_quote : Bool = false,
      )
      end

      def run : String
        result = ""

        database.with_connection do |conn|
          if code = dataset_code
            DatasetRepository.new(conn).fetch!(code)
          end

          entries = SecurityRepository.new(conn).list_with_datasets(dataset_code)
          selected = filter(entries)
          latest_closes = last_quote ? QuoteRepository.new(conn).latest_closes : {} of String => Tuple(Time, Float64)
          result = render(selected, entries.size, latest_closes)
        end

        result
      end

      private def filter(
        entries : Array(SecurityListEntry),
      ) : Array(SecurityListEntry)
        tree = Core::FilterExpression.compile(regex, FILTER_FIELDS)
        return entries unless tree

        entries.select do |entry|
          named_fields = {
            "isin"    => [entry.isin],
            "ticker"  => [entry.ticker],
            "name"    => [entry.name],
            "group"   => entry.groups,
            "dataset" => entry.datasets,
          }
          all_fields_text = named_fields.values.flatten.join(" ")

          Core::FilterExpression.matches?(tree, all_fields_text, named_fields)
        end
      end

      private def render(
        entries : Array(SecurityListEntry),
        total_count : Int32,
        latest_closes : Hash(String, Tuple(Time, Float64)),
      ) : String
        if entries.empty?
          App.info(key: "infra.no_match")
          return ""
        end

        title_key = if entries.size == total_count
                      "all"
                    elsif entries.size == 1
                      "one"
                    else
                      "some"
                    end

        title = if code = dataset_code
                  I18n.t(
                    "market.list.table.title.dataset_#{title_key}",
                    {dataset: code}
                  )
                else
                  I18n.t("market.list.table.title.#{title_key}")
                end

        close_precision = if last_quote
                            values = [] of Float64
                            entries.each do |entry|
                              if quote = latest_closes[entry.isin]?
                                values << quote[1]
                              end
                            end
                            values.empty? ? nil : Tablo::Functions.fp_reduce_precision(values, 4)
                          end

        Tablo::Table.new(
          entries,
          title: Tablo::Heading.new(title, framed: true)
        ) do |table|
          table.add_column(
            :isin,
            header: I18n.t("market.list.table.isin"),
            &.isin
          )
          table.add_column(
            :ticker,
            header: I18n.t("market.list.table.ticker"),
            &.ticker
          )
          table.add_column(
            :name,
            header: I18n.t("market.list.table.name"),
            &.name
          )
          table.add_column(
            :groups,
            header: I18n.t("market.list.table.groups")
          ) { |entry| entry.groups.empty? ? "-" : entry.groups.join(", ") }
          if last_quote
            table.add_column(
              :date,
              header: I18n.t("market.list.table.date")
            ) { |entry| latest_closes[entry.isin]?.try { |quote| quote[0].to_s("%F") } || "-" }
            table.add_column(
              :close,
              header: I18n.t("market.list.table.close"),
              header_alignment: Tablo::Justify::Center,
              body_formatter: ->(x : Tablo::CellType) {
                if precision = close_precision
                  x.is_a?(Float) ? Tablo::Functions.fp_align(x, precision, :no_dot) : x.to_s
                else
                  x.to_s
                end
              }
            ) { |entry| latest_closes[entry.isin]?.try { |quote| quote[1] } || "-" }
          end
          unless dataset_code
            table.add_column(
              :datasets,
              header: I18n.t("market.list.table.datasets")
            ) { |entry| entry.datasets.join(", ") }
          end
        end.pack.to_s
      end
    end
  end
end
