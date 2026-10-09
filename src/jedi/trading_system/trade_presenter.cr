module Jedi
  module TradingSystem
    class TradePresenter
      private getter trade

      def initialize(@trade : Trade)
      end

      def show
        ref = Core::Utils.ref(trade.id)
        Tablo::Table.new([trade],
          header_alignment: Tablo::Justify::Left,
          body_alignment: Tablo::Justify::Left,
          title: Tablo::Heading.new(I18n.t("trade.show.title",
            ref: ref), framed: true)) do |t|
          t.add_column(I18n.t("trade.show.id"), &.id)
          t.add_column(I18n.t("trade.show.name"), &.name)
          t.add_column(I18n.t("trade.show.money"), &.money.to_s)
          t.add_column(I18n.t("trade.show.stop"), &.stop.to_s)
          t.add_column(I18n.t("trade.show.security_id"), &.security.id)
          t.add_column(I18n.t("trade.show.security_isin"), &.security.isin)
          t.add_column(I18n.t("trade.show.security_name"), &.security.name)
        end.transpose(
          field_names_header_alignment: Tablo::Justify::Right,
          field_names_body_alignment: Tablo::Justify::Right,
          field_names_header: I18n.t("trade.show.transpose.fields"),
          field_names_width: nil,
          body_headers: I18n.t("trade.show.transpose.contents"),
          row_divider_frequency: 1,
          wrap_mode: Tablo::WrapMode::Word).pack
      end
    end
  end
end
