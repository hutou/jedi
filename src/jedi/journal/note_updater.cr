module Jedi
  module Journal
    class NoteUpdater
      private getter note
      private getter ref = ""

      def initialize(@note : Note)
      end

      def call(*,
               date : String?,
               summary : String?,
               contents : String?,
               edit : Bool?)
        @ref = Core::Utils.ref(note.id)
        if edit
          initial_text = <<-EOS
             #{Helpers::DATE_MARKER}
             #{note.date.to_s("%Y-%m-%d")}\n
             #{Helpers::SUMMARY_MARKER}
             #{note.summary}\n
             #{Helpers::CONTENTS_MARKER}
             #{note.contents}\n
             EOS
          contents = Core::ExternalEditor.edit_text(
            initial_text: initial_text,
            suffix: ".md"
          )
          if contents == initial_text
            App.info(key: "infra.cancelled")
            return nil
          end
          new_date, new_summary, new_contents = Helpers.parse_note_editor_text(contents)
        else
          new_date = date.nil? ? note.date.to_s("%Y-%m-%d") : date
          new_contents = if contents.nil?
                           note.contents
                         else
                           Helpers.decode_escaped_newlines(contents)
                         end
          new_summary = if summary.nil?
                          note.summary
                        else
                          Helpers.decode_escaped_newlines(summary)
                        end
        end
        date = Core::Input.ensure_date_valid!(new_date,
          field: "date", key: "infra.field_required")
        summary = Core::Input.ensure_present!(new_summary, field: "summary")
        contents = Core::Input.ensure_present!(new_contents, field: "contents")

        if date == note.date && summary == note.summary && contents == note.contents
          App.info(key: "note.update.unchanged", params: {:ref => ref})
          0
        else
          sql = "UPDATE note SET date = ?, summary = ?, contents = ? WHERE id=?"
          exec_result = note.conn_db.exec sql, date, summary, contents, note.id

          # Force reading of the database to update the record in memory
          note.reload!(note.id)
          App.info(key: "note.update.success", params: {:ref => ref})
          exec_result.rows_affected
        end
      end
    end
  end
end
