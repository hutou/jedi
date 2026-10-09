module Jedi
  module TradingLife
    class OperationDeleter
      getter conn_db
      getter ref = ""

      def initialize(@conn_db : DB::Connection)
      end

      def delete
        last_operation = load_last_operation

        if last_operation.nil?
          raise LowLevelError.new(
            key: "operation.delete.nothing",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        @ref = Core::Utils.ref(last_operation.id)
        validate_no_more_recent_settings!(last_operation)
        settings = last_operation.settings
        settings_operations = load_settings_operations(settings.id)
        trade_nb_settings = count_trade_settings(settings.trade.id)

        return cancel unless confirmed?(last_operation)

        delete_operation!(
          last_operation,
          settings: settings,
          settings_operations: settings_operations,
          trade_nb_settings: trade_nb_settings
        )
      end

      private def load_last_operation : Operation?
        Operations.new(conn_db)
          .fetch("SELECT id FROM operation ORDER BY timestamp DESC, id DESC LIMIT 1")
          .last?
      end

      private def validate_no_more_recent_settings!(last_operation : Operation) : Nil
        last_settings = TradingSystem::SettingsChain.new(conn_db)
          .fetch("SELECT id FROM settings ORDER BY timestamp DESC LIMIT 1")
          .last?

        return if last_settings.nil?
        return if last_settings.timestamp <= last_operation.timestamp

        raise LowLevelError.new(
          key: "operation.delete.recent_settings",
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def load_settings_operations(settings_id : Int64) : Array(Operation)
        sql = "SELECT id FROM operation WHERE settings_id = #{settings_id} ORDER BY timestamp ASC"
        Operations.new(conn_db).fetch(sql).to_a
      end

      private def count_trade_settings(trade_id : Int64)
        sql = "SELECT COUNT(id) FROM settings WHERE trade_id = #{trade_id}"
        conn_db.scalar(sql)
      end

      private def confirmed?(operation : Operation) : Bool
        op_details = "(Trade '%s' : %s %s -> %d @ %g)" % [
          operation.trade.name,
          operation.type,
          operation.mode,
          operation.quantity,
          operation.price,
        ]

        App.noconfirm? || App.confirm(
          I18n.t("operation.delete.confirm",
            ref: ref,
            detail: "#{op_details}"),
          I18n.t("infra.no_chars")[0].upcase
        )
      end

      private def cancel
        App.info(key: "infra.cancelled")
      end

      private def delete_operation!(
        operation : Operation,
        *,
        settings,
        settings_operations : Array(Operation),
        trade_nb_settings,
      )
        exec_result = DB::ExecResult.new(0_i64, 0_i64)

        conn_db.transaction do |tx|
          cnn = tx.connection

          if settings_operations.size == 1 && (
               trade_nb_settings == 1 || (x = settings.reinit) && x.merge?
             )
            cnn.exec(
              "UPDATE settings SET q0 = ?, c0 = ? WHERE id = ?",
              0.0,
              0.0,
              settings.id
            )
          end

          exec_result = cnn.exec(
            "DELETE FROM operation WHERE id = ?",
            operation.id
          )
        end

        App.info(key: "operation.delete.success", params: {:ref => ref})
        exec_result.rows_affected
      end
    end
  end
end
