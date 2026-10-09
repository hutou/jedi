module Jedi
  module Journal
    module Helpers
      DATE_MARKER     = "# Date"
      SUMMARY_MARKER  = "# Summary"
      CONTENTS_MARKER = "# Contents"

      def self.decode_escaped_newlines(text : String) : String
        text
          .gsub("\\r\\n", "\n")
          .gsub("\\n", "\n")
          .gsub("\\r", "\n")
      end

      def self.parse_note_editor_text(text : String) : Tuple(String, String, String)
        date_pos = text.index(DATE_MARKER)
        summary_pos = text.index(SUMMARY_MARKER)
        contents_pos = text.index(CONTENTS_MARKER)

        unless date_pos && summary_pos && contents_pos &&
               date_pos < summary_pos && summary_pos < contents_pos
          raise LowLevelError.new(
            key: "note.helpers.invalid_contents",
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        date_start = date_pos + DATE_MARKER.size
        summary_start = summary_pos + SUMMARY_MARKER.size
        contents_start = contents_pos + CONTENTS_MARKER.size

        date = text[date_start...summary_pos].strip
        summary = text[summary_start...contents_pos].strip
        contents = text[contents_start..].strip

        {date, summary, contents}
      end
    end
  end
end
