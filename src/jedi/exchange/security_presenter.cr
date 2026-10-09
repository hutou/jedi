module Jedi
  module Exchange
    class SecurityPresenter
      private getter ref

      def initialize(@security : Security)
        @ref = Core::Utils.ref(@security.id)
      end

      def show
        title = I18n.t("security.show.table.title", ref: ref)
        table = Tablo::Table.new([@security],
          header_alignment: Tablo::Justify::Left,
          body_alignment: Tablo::Justify::Left,
          title: Tablo::Heading.new(title, framed: true)) do |t|
          t.add_column(:id, header: I18n.t("security.show.table.id"), &.id)
          t.add_column(:isin, header: I18n.t("security.show.table.isin"), &.isin)
          t.add_column(:name, header: I18n.t("security.show.table.name"), &.name)
          t.add_column(:ticker, header: I18n.t("security.show.table.ticker"),
            &.ticker)
          t.add_column(:tick_buy, header: I18n.t("security.show.table.tick_buy"),
            &.tick_buy.value)
          t.add_column(:tick_sell, header: I18n.t("security.show.table.tick_sell"),
            &.tick_sell.value)
          t.add_column(:tax, header: I18n.t("security.show.table.tax"), &.tax)
          t.add_column(:quotation_date, header: I18n.t("security.show.table.quotation_date")) { |n|
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
          t.add_column(:quotation_website, header: I18n.t("security.show.table.quotation_website"),
            &.quotation_website)
          t.add_column(:quotation_mode, header: I18n.t("security.show.table.quotation_mode"),
            &.quotation_mode)
          t.add_column(:quotation_price, header: I18n.t("security.show.table.quotation_price"),
            &.quotation_price)
          t.add_column(:quotation_variation, header: I18n.t("security.show.table.quotation_variation"),
            &.quotation_variation)
        end
        table.transpose(
          field_names_header_alignment: Tablo::Justify::Right,
          field_names_body_alignment: Tablo::Justify::Right,
          field_names_header: I18n.t("security.show.table.transpose.fields"),
          field_names_width: nil,
          body_headers: I18n.t("security.show.table.transpose.contents"),
          row_divider_frequency: 1,
          wrap_mode: Tablo::WrapMode::Word).pack.to_s
      end
    end
  end
end
