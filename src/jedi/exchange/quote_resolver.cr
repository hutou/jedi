module Jedi
  module Exchange
    # Resolves the current usable quotation for one registered Security.
    #
    # It decides whether the persisted quotation is still fresh enough,
    # triggers a Web update when needed, and falls back to the last recorded
    # quotation if the update fails.
    class QuoteResolver
      @@memoized_price = {} of PkId => Float64?

      def initialize(@security : Security)
      end

      def price(*, option_mode : String? = "live", option_update_now : Bool = false) : Float64?
        security_id = @security.id
        return @@memoized_price[security_id] if @@memoized_price.has_key?(security_id)

        quot_date = @security.quotation_date

        if option_update_now ||
           quot_date.nil? ||
           (Time.local - quot_date).total_minutes > App.quotlife
          STDERR.print "\r\033[K#{I18n.t("quote.current.updating")} '#{@security.name}'\r"
          QuoteUpdater.new(@security).call(option_mode: option_mode)
        end

        @@memoized_price[security_id] = @security.quotation_price
      rescue ex : LowLevelError
        App.capture_exception(
          ex,
          log_context: {
            :security_id => "#{@security.id}",
            :isin        => @security.isin,
            :name        => @security.name,
          })

        if quot_date.nil?
          App.warn(
            key: "quote.current.no_current_price",
            params: {:name => @security.name})
          nil
        else
          if (Time.local - quot_date).total_minutes > App.quotlife
            App.warn(
              key: "quote.current.old_recorded_price_used",
              params: {:name => @security.name})
          else
            App.warn(
              key: "quote.current.last_recorded_price_used",
              params: {:name => @security.name})
          end

          @security.quotation_price
        end
      end
    end
  end
end
