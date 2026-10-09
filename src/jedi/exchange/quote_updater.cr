module Jedi
  module Exchange
    # Retrieves and persists the quotation of one registered Security.
    class QuoteUpdater
      def initialize(@security : Security)
      end

      # Keep the historical return value for current callers.
      def call(*, option_mode : String? = nil) : String
        target = QuoteTarget.from(@security)
        quote = QuoteFetcher.new(target).call(option_mode: option_mode)
        persist!(quote)
        quote.mode
      end

      private def persist!(quote : QuoteFetcher::QuoteData) : Nil
        sql = <<-SQL
          UPDATE security
          SET quotation_mode = ?,
              quotation_date = ?,
              quotation_website = ?,
              quotation_price = ?,
              quotation_variation = ?
          WHERE id = ?
          SQL

        security_id = @security.id
        security_isin = @security.isin
        security_name = @security.name

        begin
          @security.conn_db.exec(
            sql,
            quote.mode,
            quote.date,
            quote.website,
            quote.price,
            quote.variation,
            security_id)
          @security.reload!
          App.info(key: "quote.update.success", params: {:price => "#{quote.price}"})
        rescue ex
          raise LowLevelError.new(
            "Unable to persist quotation",
            kind: LowLevelError::Kind::Technical,
            log_context: {
              :id     => "#{security_id}",
              :isin   => security_isin,
              :name   => security_name,
              :source => Core::Utils.source(__FILE__, __LINE__),
            },
            cause: ex)
        end
      end
    end
  end
end
