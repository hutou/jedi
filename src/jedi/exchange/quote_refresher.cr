module Jedi
  module Exchange
    class QuoteRefresher
      alias UpdateQuote = Proc(Security, String?, String)

      @update_quote : UpdateQuote

      def initialize(
        @conn_db : DB::Connection,
        *,
        @output : IO = STDERR,
        update_quote : UpdateQuote? = nil,
      )
        @update_quote = update_quote || ->(security : Security, mode : String?) {
          QuoteUpdater.new(security).call(option_mode: mode)
        }
      end

      def call(regex : String? = nil,
               *,
               option_mode : String? = nil,
               option_force = false) : Nil
        all_securities = load_all_securities
        selected_securities = select_securities(
          all_securities,
          regex: regex,
          option_force: option_force,
        )

        if selected_securities.empty?
          App.warn(key: "infra.no_match")
          return
        end

        updates = 0
        failures = 0

        @output.print "\033[?25l" # hide cursor

        begin
          selected_securities.each do |security|
            @output.print "\r>>> #{security.isin} - #{security.name}"

            begin
              @update_quote.call(security, option_mode)
              updates += 1
              @output.puts ""
            rescue ex : LowLevelError
              failures += 1
              log_update_failure(security, ex, option_mode)
              @output.print " -> "
              @output.puts I18n.t("infra.failed").colorize(COLOR_ERROR)
            rescue ex
              failures += 1
              low_ex = wrap_update_failure(security, ex, option_mode)
              log_update_failure(security, low_ex, option_mode)
              @output.print " -> "
              @output.puts I18n.t("infra.failed").colorize(COLOR_ERROR)
            ensure
              @output.print "\r\033[K"
            end
          end
        ensure
          @output.print "\033[?25h" # display cursor
        end

        if updates.zero?
          raise LowLevelError.new(
            key: "quote.refresh.failed_updates",
            context: {
              :failures => failures.to_s,
              :selected => selected_securities.size.to_s,
            },
            kind: LowLevelError::Kind::Technical,
            log_context: {
              :failures => failures.to_s,
              :selected => selected_securities.size.to_s,
              :source   => Core::Utils.source(__FILE__, __LINE__),
            }
          )
        elsif failures > 0
          App.warn(key: "quote.refresh.failed_updates_count",
            params: {:failures => "#{failures}"})
          App.info(key: "infra.see_logfile", params: {:logfile => App.log_file})
        else
          App.info(key: "quote.refresh.success")
        end
      end

      private def load_all_securities : Array(Security)
        Securities.new(@conn_db).fetch.to_a
      end

      private def select_securities(securities : Array(Security),
                                    *,
                                    regex,
                                    option_force : Bool) : Array(Security)
        selected = filter_running(securities, option_force)
        selected = filter_by_regex(selected, regex)
        selected
      end

      private def filter_running(securities : Array(Security),
                                 option_force : Bool) : Array(Security)
        return securities if option_force

        security_ids = [] of PkId

        TradingSystem::Trades.new(@conn_db).fetch.each do |trade|
          lastop = trade.last_operation
          next if lastop.nil?

          security_ids << trade.security.id if lastop.stock > 0
        end

        securities.select do |security|
          security.id.in?(security_ids)
        end
      end

      private def filter_by_regex(securities : Array(Security),
                                  regex : String?) : Array(Security)
        return securities if regex.nil?
        allowed_fields = ["id", "isin", "name", "ticker"]
        tree = Jedi::Core::FilterExpression.compile(regex, allowed_fields)

        securities.select do |security|
          named_fields = {
            "id"     => [security.id.to_s],
            "isin"   => [security.isin],
            "name"   => [security.name],
            "ticker" => [security.ticker],
          }
          all_fields_text = named_fields.values.flatten.compact.join(" ")
          Jedi::Core::FilterExpression.matches?(tree, all_fields_text, named_fields)
        end
      end

      private def log_update_failure(security : Security,
                                     ex : LowLevelError,
                                     option_mode : String?) : Nil
        App.capture_exception(
          ex,
          {
            :isin => "#{security.isin}",
            :name => "#{security.name}",
            :mode => option_mode || "auto",
          }
        )
      end

      private def wrap_update_failure(security : Security,
                                      ex : Exception,
                                      option_mode : String?) : LowLevelError
        LowLevelError.new(
          "Unexpected error while refreshing quotation",
          kind: LowLevelError::Kind::Technical,
          log_context: {
            :isin   => "#{security.isin}",
            :name   => "#{security.name}",
            :mode   => option_mode || "auto",
            :source => Core::Utils.source(__FILE__, __LINE__),
          },
          log_backtrace: true,
          cause: ex
        )
      end
    end
  end
end
