module Jedi
  module Core
    module ExternalEditor
      def self.edit_text(
        initial_text : String = "",
        suffix : String = ".md",
      ) : String
        editor = ENV["VISUAL"]? || ENV["EDITOR"]?

        if editor.nil? || editor.empty?
          raise LowLevelError.new(
            "no external editor configured",
            key: "core.external_editor.not_configured",
            kind: LowLevelError::Kind::Domain,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)}
          )
        end

        file = File.tempfile("jedi-note-", suffix)
        path = file.path

        begin
          file.print initial_text
          file.close

          status = Process.run(
            command: editor,
            args: [path],
            input: STDIN,
            output: STDOUT,
            error: STDERR
          )

          unless status.success?
            raise LowLevelError.new(
              "external editor '#{editor}' failed",
              key: "core.external_editor.failed",
              context: {:editor => editor},
              kind: LowLevelError::Kind::Domain,
              log_context: {
                :editor => editor,
                :source => Core::Utils.source(__FILE__, __LINE__),
              }
            )
          end

          File.read(path)
        ensure
          File.delete(path) if File.exists?(path)
        end
      end
    end
  end
end
