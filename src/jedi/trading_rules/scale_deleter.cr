module Jedi
  module TradingRules
    class ScaleDeleter
      private getter ref = ""

      def initialize(@conn_db : DB::Connection)
      end

      def call(ident : String | PkId)
        @ref = Core::Utils.ref(ident)
        scale = validate_delete(ident)
        if confirm_delete?(scale)
          delete(scale)
          App.info(key: "scale.delete.success",
            params: {:ref => ref})
        else
          App.info(key: "infra.cancelled")
        end
      end

      def validate_delete(ident)
        (scale = Scale.new(@conn_db, ident)) # raise if not found
        if TradingRules::ScaleUsage.new(scale).used?
          raise LowLevelError.new(
            key: "scale.delete.in_use",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        scale
      end

      def confirm_delete?(scale)
        if App.noconfirm? ||
           App.confirm I18n.t("scale.delete.confirm",
             ref: ref), I18n.t("infra.no_chars")[0].upcase
          true
        else
          false
        end
      end

      def delete(scale)
        @conn_db.exec "DELETE FROM scale WHERE id=?", scale.id
      end
    end
  end
end
