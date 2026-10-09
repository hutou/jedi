module Jedi
  module TradingSystem
    class SettingsDeleter
      private getter ref = ""
      getter conn_db

      def initialize(@conn_db : DB::Connection)
      end

      def call
        last_settings = load_last_settings

        if last_settings.nil?
          raise LowLevelError.new(
            key: "settings.delete.nothing_to_delete",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        @ref = Core::Utils.ref(last_settings.id)
        settings_id = validate_settings_unused!(last_settings)

        if confirm_delete?(settings_id)
          delete(settings_id)
          App.info(key: "settings.delete.success", params: {:ref => ref})
        else
          App.info(key: "infra.cancelled")
        end
      end

      private def load_last_settings : Settings?
        sql = "SELECT id FROM settings ORDER BY timestamp DESC LIMIT 1"
        TradingSystem::SettingsChain.new(@conn_db).fetch(sql).last?
      end

      private def validate_settings_unused!(settings : Settings) : PkId
        unless settings.operation_count.zero?
          raise LowLevelError.new(
            key: "settings.delete.in_use",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        settings.id
      end

      def confirm_delete?(settings_id)
        if App.noconfirm? ||
           App.confirm I18n.t("settings.delete.confirm",
             ref: ref), I18n.t("infra.no_chars")[0].upcase
          true
        else
          false
        end
      end

      def delete(id)
        @conn_db.exec "DELETE FROM settings WHERE id = ?", id
      end
    end
  end
end
