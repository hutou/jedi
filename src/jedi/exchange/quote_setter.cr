module Jedi
  module Exchange
    class QuoteSetter
      private getter ref = ""
      getter conn_db
      getter security

      def initialize(@security : Security)
        @ref = Core::Utils.ref(security.id)
      end

      def set(price : Float64)
        unless price.finite? && price > 0.0
          raise LowLevelError.new(
            key: "quote.set.price_must_be_positive",
            context: {:price => price.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        sql = "UPDATE security SET quotation_price=?, quotation_date=?, quotation_website=?, " +
              "quotation_mode=?, quotation_variation=? WHERE id=?"
        exec_result = security.conn_db.exec sql, price, Time.local, "manual", "live", nil, security.id
        # Force record update on next access
        security.reload!(security.id)
        App.info(key: "quote.set.success", params: {:ref => ref, :price => "#{price}"})
        exec_result.rows_affected
      end
    end
  end
end
