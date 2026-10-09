module Jedi
  module Exchange
    class SecurityDeleter
      getter ref = ""

      def initialize(@conn_db : DB::Connection)
      end

      def call(ident : String | PkId)
        @ref = Core::Utils.ref(ident).upcase
        security_id = validate_delete(ident)
        if confirm_delete?
          delete(security_id)
          App.info(key: "security.delete.success", params: {:ref => ref})
        else
          App.info(key: "infra.cancelled")
        end
      end

      def validate_delete(ident)
        security_id = Security.new(@conn_db, ident).id # raise if id not found
        sql = "SELECT COUNT(*) FROM trade WHERE security_id = ?"
        unless @conn_db.scalar(sql, security_id).as(PkId).zero?
          raise LowLevelError.new(
            key: "security.delete.in_use",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        security_id
      end

      def confirm_delete?
        if App.noconfirm? ||
           App.confirm I18n.t("security.delete.confirm",
             ref: ref), I18n.t("infra.no_chars")[0].upcase
          true
        else
          false
        end
      end

      def delete(security_id)
        @conn_db.exec "DELETE FROM security WHERE id=?", security_id
      end
    end
  end
end
