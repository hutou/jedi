module Jedi
  module Journal
    class NoteCreator
      getter ref = ""

      def initialize(@conn_db : DB::Connection)
        @repo = NoteRepository.new(@conn_db)
      end

      def call(*,
               date : String?,
               summary : String?,
               contents : String?,
               edit : Bool?)
        if edit
          initial_text = <<-EOS
            #{Helpers::DATE_MARKER}\n\n
            #{Helpers::SUMMARY_MARKER}\n\n
            #{Helpers::CONTENTS_MARKER}\n\n
            EOS

          # use external editor
          contents = Core::ExternalEditor.edit_text(
            initial_text: initial_text,
            suffix: ".md"
          )
          if contents == initial_text
            # editing has been cancelled
            App.info(key: "infra.cancelled")
            return nil
          end
          date, summary, contents = Helpers.parse_note_editor_text(contents)
        else
          contents = (x = contents).nil? ? nil : Helpers.decode_escaped_newlines(x)
          summary = (x = summary).nil? ? nil : Helpers.decode_escaped_newlines(x)
        end
        date = Core::Input.ensure_date_valid!(date,
          field: "date", key: "infra.field_required")
        summary = Core::Input.ensure_present!(summary, field: "summary")
        contents = Core::Input.ensure_present!(contents, field: "contents")

        state = NoteState.new(
          date: date.as(Time),
          summary: summary.as(String),
          contents: contents.as(String)
        )
        note_id = @repo.insert!(state)
        ref = Core::Utils.ref(note_id)
        App.info(key: "note.create.success", params: {:ref => ref})
        note_id
      end
    end
  end
end
