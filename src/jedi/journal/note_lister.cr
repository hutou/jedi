module Jedi
  module Journal
    class NoteLister
      def initialize(@conn_db : DB::Connection)
      end

      def call(regex = nil,
               *,
               option_records = nil,
               option_columns = nil)
        notes = [] of Journal::Note

        all_note = load_all_note

        selected_note = select_note(
          all_note,
          regex: regex,
          option_records: option_records,
        )

        render_note(selected_note,
          total_count: all_note.size,
          option_columns: option_columns)
      end

      private def select_note(notes : Array(Note),
                              *,
                              regex,
                              option_records) : Array(Note)
        selected = filter_by_regex(notes, regex)
        selected = select_by_records(selected, option_records)
        selected
      end

      private def filter_by_regex(notes : Array(Note),
                                  regex : String?) : Array(Note)
        return notes if regex.nil?
        allowed_fields = ["id", "date", "summary", "contents"]
        tree = Jedi::Core::FilterExpression.compile(regex, allowed_fields)

        notes.select do |note|
          named_fields = {
            "id"       => [note.id.to_s],
            "date"     => [note.date.to_s],
            "summary"  => [note.summary],
            "contents" => [note.contents],
          }

          all_fields_text = named_fields.values.flatten.compact.join(" ")
          ok = Jedi::Core::FilterExpression.matches?(tree, all_fields_text, named_fields)
        end
      end

      private def select_by_records(notes : Array(Note),
                                    option_records) : Array(Note)
        return notes if option_records.nil?

        Jedi::Core::Collection.select_records(notes, option_records)
      end

      private def render_note(notes, *,
                              total_count,
                              option_columns : String?) : String
        if notes.empty?
          App.info(key: "infra.no_match")
          return ""
        end

        title = if notes.size == total_count
                  I18n.t("note.list.table.title.all")
                elsif notes.size == 1
                  I18n.t("note.list.table.title.one")
                else
                  I18n.t("note.list.table.title.some")
                end
        table = Tablo::Table.new(notes,
          title: Tablo::Heading.new(title,
            framed: true),
          row_divider_frequency: 1) do |t|
          t.add_column(I18n.t("note.list.table.id"), &.id)
          t.add_column(I18n.t("note.list.table.date"), &.date.to_s("%Y-%m-%d"))
          t.add_column(I18n.t("note.list.table.summary"), &.summary)
          t.add_column(I18n.t("note.list.table.contents"), &.contents)
        end.pack
        if option_columns
          max_index = 3
          indexes, reordered = Core::Input.parse_column_indexes(
            option_columns, max_index)
          table.using_column_indexes(indexes, reordered: reordered).to_s
        else
          table.to_s
        end
      end

      private def load_all_note : Array(Note)
        Notes.new(@conn_db).fetch.to_a
      end
    end
  end
end
