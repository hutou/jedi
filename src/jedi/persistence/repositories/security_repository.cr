module Jedi
  module Exchange
    class SecurityRepository
      def initialize(@conn_db : DB::Connection)
      end

      def insert!(state : SecurityState) : PkId
        exec_result = @conn_db.exec("INSERT INTO security (isin, name, ticker, tick_buy, " \
                                    "tick_sell, tax, quotation_date, quotation_website, " \
                                    "quotation_mode, quotation_price, quotation_variation) " \
                                    "values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          state.isin,
          state.name,
          state.ticker,

          state.tick_buy.value,
          state.tick_sell.value,
          state.tax,

          state.quotation_date,
          state.quotation_website,
          state.quotation_mode,
          state.quotation_price,
          state.quotation_variation
        )

        exec_result.last_insert_id
      end
    end
  end
end
