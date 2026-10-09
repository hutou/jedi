module Jedi
  module Exchange
    class SecurityUpdater
      private getter security
      private getter ref = ""

      def initialize(@security : Security)
        @ref = Core::Utils.ref(security.id)
      end

      # update some security fields
      def call(*,
               isin : String?,
               name : String?,
               ticker : String?,
               tick_buy : String?,
               tick_sell : String?,
               tax : String?)
        new_isin =
          if isin.nil?
            security.isin
          else
            Core::Input.ensure_isin_valid!(isin, field: "isin",
              key: "infra.field_required")
          end
        new_name =
          if name.nil?
            security.name
          else
            Core::Input.ensure_present!(name, field: "name")
          end
        new_ticker =
          if ticker.nil?
            security.ticker
          else
            Core::Input.ensure_present!(ticker, field: "ticker")
          end
        new_tick_buy =
          if tick_buy.nil?
            security.tick_buy
          else
            Exchange::Security::Tick.new(tick_buy)
          end
        new_tick_sell =
          if tick_sell.nil?
            security.tick_sell
          else
            Exchange::Security::Tick.new(tick_sell)
          end
        new_tax =
          if tax.nil?
            security.tax
          else
            Core::Input.ensure_decimal_pct_valid!(tax, field: "tax",
              regex: NON_NEGATIVE_DECIMAL_PCT)
            # (x = Core::Input.ensure_string_valid!(tax, field: "tax",
            #   regex: POSITIVE_DECIMAL_PCT, key: "infra.field_required"))
            #   .ends_with?('%') ? x.chomp('%').to_f / 100 : x.to_f
          end

        if new_isin == security.isin &&
           new_name == security.name &&
           new_ticker == security.ticker &&
           new_tick_buy == security.tick_buy &&
           new_tick_sell == security.tick_sell &&
           new_tax == security.tax
          App.info(key: "security.update.unchanged", params: {:ref => ref})
          0
        else
          can_update = true
          # Check if isin changed and new_isin not used yet !
          if new_isin != security.isin
            sql = "SELECT EXISTS(SELECT id FROM security WHERE isin=?)"
            unless security.conn_db.scalar(sql, isin).as(PkId).zero?
              can_update = false
            end
          end
          if can_update
            sql = "UPDATE security SET isin=?, name=?, ticker=?, tick_buy=?, tick_sell=?, tax=? WHERE id=?"
            exec_result = security.conn_db.exec sql, new_isin, new_name,
              new_ticker, new_tick_buy.to_s, new_tick_sell.to_s, new_tax, security.id
            security.reload!(security.id)
            App.info(key: "security.update.success", params: {:ref => ref})
            exec_result.rows_affected
          else
            raise LowLevelError.new(
              key: "security.update.isin_used",
              context: {:isin => new_isin},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
        end
      end
    end
  end
end
