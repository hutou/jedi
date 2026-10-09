module Jedi
  module Journal
    class NoteDeleter
      getter ref = ""

      def initialize(@conn_db : DB::Connection)
      end

      def call(id : PkId)
        Note.new(@conn_db, id).id # raise if id not found
        if confirm_delete?(id)
          delete(id)
          ref = Core::Utils.ref(id)
          App.info(key: "note.delete.success", params: {:ref => ref})
        else
          App.info(key: "infra.cancelled")
        end
      end

      def confirm_delete?(id)
        if App.noconfirm? ||
           App.confirm I18n.t("note.delete.confirm",
             ref: ref), I18n.t("infra.no_chars")[0].upcase
          true
        else
          false
        end
      end

      def delete(id)
        @conn_db.exec "DELETE FROM note WHERE id=?", id
      end
    end
  end
end
