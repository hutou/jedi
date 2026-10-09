module Jedi
  module Exchange
    struct SecurityState
      getter isin : String
      getter name : String
      getter ticker : String

      getter tick_buy : Security::Tick
      getter tick_sell : Security::Tick
      getter tax : Float64

      getter quotation_date : Time?
      getter quotation_website : String?
      getter quotation_mode : String?
      getter quotation_price : Float64?
      getter quotation_variation : Float64?

      def initialize(
        @isin : String,
        @name : String,
        @ticker : String,

        # Optional, but defaults set otherwise
        @tick_buy : Security::Tick,
        @tick_sell : Security::Tick,
        @tax : Float64,

        # Not set at creation time
        @quotation_date : Time? = nil,
        @quotation_website : String? = nil,
        @quotation_mode : String? = nil,
        @quotation_price : Float64? = nil,
        @quotation_variation : Float64? = nil,
      )
      end
    end
  end
end
