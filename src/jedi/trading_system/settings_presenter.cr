module Jedi
  module TradingSystem
    class SettingsPresenter
      private getter settings

      def initialize(@settings : Settings)
      end

      def show
        ref = Core::Utils.ref(settings.id)
        Tablo::Table.new([settings],
          header_alignment: Tablo::Justify::Left,
          body_alignment: Tablo::Justify::Left,
          title: Tablo::Heading.new(I18n.t("settings.show.title",
            ref: ref), framed: true)) do |t|
          t.add_column(I18n.t("settings.show.id"), &.id)
          t.add_column(I18n.t("settings.show.trade"), &.trade.name)
          t.add_column(I18n.t("settings.show.scale"), &.scale.name)
          t.add_column(I18n.t("settings.show.rank"), &.rank)
          t.add_column(I18n.t("settings.show.timestamp"),
            &.timestamp.to_local)
          t.add_column(I18n.t("settings.show.split"), &.split.to_s)
          t.add_column(I18n.t("settings.show.sync"), &.sync.to_s)
          t.add_column(I18n.t("settings.show.reinit"), &.reinit.to_s)
          t.add_column(I18n.t("settings.show.q0"), &.q0)
          t.add_column(I18n.t("settings.show.c0"), &.c0)
          t.add_column(I18n.t("settings.show.position"), &.position.to_s)
          t.add_column(I18n.t("settings.show.kspc"), &.kspc)
          t.add_column(I18n.t("settings.show.kcpc"), &.kcpc)
        end.transpose(
          field_names_header_alignment: Tablo::Justify::Right,
          field_names_body_alignment: Tablo::Justify::Right,
          field_names_header: I18n.t("settings.show.transpose.fields"),
          field_names_width: nil,
          body_headers: I18n.t("settings.show.transpose.contents"),
          row_divider_frequency: 1,
          wrap_mode: Tablo::WrapMode::Word).pack
      end
    end
  end
end
