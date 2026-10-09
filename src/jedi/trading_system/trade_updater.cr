module Jedi
  module TradingSystem
    class TradeUpdater
      private getter trade
      private getter ref = ""

      def initialize(@trade : Trade)
      end

      def call(*, name : String? = nil,
               money : String? = nil,
               reset_stop : Bool? = nil) : Int64
        @ref = Core::Utils.ref(trade.ident.is_a?(PkId) ? trade.id : trade.name)
        new_name =
          if name.nil?
            trade.name
          else
            Core::Input.ensure_string_valid!(name, field: "name",
              regex: ALPHANUM, key: "infra.field_required").capitalize
          end
        # CAUTION: money is not required, but existing money field must be valid,
        # which should be, unless broken by an external hack,
        # otherwise no trade command would work !
        begin
          new_money = if money.nil?
                        trade.money # no change required for money
                      elsif money.strip.empty?
                        nil # reset to nil required for money
                      else
                        TradingSystem::Money.parse(money) || trade.money
                      end
        rescue ex : LowLevelError
          raise LowLevelError.new(
            key: "trade.update.invalid_money",
            context: {:value => money.to_s},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        # if reset_stop is true, stop can be reset to nil
        new_stop = reset_stop ? nil : trade.stop

        unless name || money || reset_stop
          App.info(key: "trade.update.nothing_to_update")
          return 0_i64
        end

        if new_money == trade.money && new_name == trade.name && new_stop == trade.stop
          App.info(key: "trade.update.unchanged")
          return 0_i64
        end

        # money and stop are already set, and a money change is requested
        if trade.money && trade.stop && new_money != trade.money
          # money change valid only if a stop reset is also requested
          if App.simulation == SimulationMode::None
            if reset_stop
              if confirm_reset_stop?(trade.stop)
                new_stop = nil
              else
                App.info(key: "infra.cancelled")
                return 0_i64
              end
            else
              raise LowLevelError.new(
                # "Field 'money' can be updated only if field 'stop' is nil",
                key: "trade.update.reset_stop_required",
                # Help page expected
                kind: LowLevelError::Kind::UserInput,
                context: {:money => trade.money.to_s, :stop => trade.stop.to_s},
                log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
            end
          else
            # In simulation mode, a money change automatically reset stop
            new_stop = nil
          end
        end

        if new_name != trade.name && key_exists(new_name)
          @ref = Core::Utils.ref(new_name)
          # name is a key, so we must ensure it is not used elsewhere
          raise LowLevelError.new(
            # "Name '#{new_name}' already use as key in trade table",
            key: "trade.update.name_already_used",
            # Help page not expected
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        @ref = Core::Utils.ref(@trade.id)
        sql = "UPDATE trade SET name=?, money=?, stop=? WHERE id=?"
        exec_result = trade.conn_db.exec sql, new_name, new_money ? new_money.to_s : nil,
          new_stop ? new_stop.to_s : nil, trade.id
        trade.reload!(trade.id)
        App.info(key: "trade.update.success", params: {:ref => ref})
        exec_result.rows_affected
      end

      private def key_exists(name)
        count = trade.conn_db.scalar(
          "SELECT count(*) FROM trade WHERE name = ?",
          name).as(PkId)
        !count.zero?
      end

      private def required(value : String, key : String) : String
        Core::Input.ensure_present!(
          value,
          key: key)
      end

      def confirm_reset_stop?(stop)
        if App.noconfirm? ||
           App.confirm I18n.t("trade.update.reset_stop_confirm",
             stop: "#{stop}"), I18n.t("infra.no_chars")[0].upcase
          true
        else
          false
        end
      end
    end
  end
end
