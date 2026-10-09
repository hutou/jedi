module Jedi
  module Exchange
    class SecurityCreator
      getter ref = ""

      def initialize(@conn_db : DB::Connection)
        @repo = SecurityRepository.new(@conn_db)
      end

      def call(*,
               isin : String,
               name : String,
               ticker : String,
               tick_buy : Security::Tick,
               tick_sell : Security::Tick,
               tax : Float64,
               quotation_date : Time? = nil,
               quotation_website : String? = nil,
               quotation_mode : String? = nil,
               quotation_price : Float64? = nil,
               quotation_variation : Float64? = nil)
        isin = Core::Input.ensure_isin_valid!(isin,
          field: "isin",
          key: "security.create.invalid_isin",
          kind: LowLevelError::Kind::Domain)
        name = Core::Input.ensure_present!(name,
          field: "name",
          key: "security.create.name_required",
          kind: LowLevelError::Kind::Domain)
        validate_tax!(tax)
        validate_quotation_price!(quotation_price)
        validate_create(isin)

        state = SecurityState.new(
          isin: isin,
          name: name,
          ticker: ticker,
          tick_buy: tick_buy,
          tick_sell: tick_sell,
          tax: tax,
          quotation_date: quotation_date,
          quotation_website: quotation_website,
          quotation_mode: quotation_mode,
          quotation_price: quotation_price,
          quotation_variation: quotation_variation
        )

        security_id = @repo.insert!(state)
        @ref = Core::Utils.ref(security_id)
        App.info(key: "security.create.success", params: {:ref => ref})
        security_id
      end

      private def validate_tax!(tax : Float64) : Nil
        return if tax.finite? && tax >= 0.0

        raise LowLevelError.new(
          key: "security.create.invalid_tax",
          context: {:tax => tax.to_s},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def validate_quotation_price!(price : Float64?) : Nil
        return if price.nil? || (price.finite? && price > 0.0)

        raise LowLevelError.new(
          key: "security.create.invalid_quotation_price",
          context: {:price => price.to_s},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def validate_create(isin)
        sql = "SELECT EXISTS(SELECT id FROM security WHERE isin=?)"
        unless @conn_db.scalar(sql, isin).as(PkId).zero?
          raise LowLevelError.new(
            key: "security.create.isin_exists",
            context: {:isin => isin},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)}
          )
        end
      end
    end
  end
end
