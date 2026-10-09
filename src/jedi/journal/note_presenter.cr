module Jedi
  module Journal
    class NotePresenter
      private getter note
      private getter ref = ""

      def initialize(@note : Note)
      end

      def call
        ref = Core::Utils.ref(note.id)
        table = Tablo::Table.new([note],
          header_alignment: Tablo::Justify::Left,
          body_alignment: Tablo::Justify::Left,
          title: Tablo::Heading.new(I18n.t("note.show.title", ref: ref),
            framed: true)) do |t|
          t.add_column(I18n.t("note.show.id"), &.id)
          t.add_column(I18n.t("note.show.date"), &.date.to_s("%d-%m-%Y"))
          t.add_column(I18n.t("note.show.summary"), &.summary)
          t.add_column(I18n.t("note.show.contents"), &.contents)
        end
        table.transpose(
          field_names_header_alignment: Tablo::Justify::Right,
          field_names_body_alignment: Tablo::Justify::Right,
          field_names_header: I18n.t("note.show.transpose.fields"),
          field_names_width: nil,
          body_headers: I18n.t("note.show.transpose.contents"),
          row_divider_frequency: 1,
          wrap_mode: Tablo::WrapMode::Rune).pack
      end
    end
  end
end
