module Jedi
  module TradingSystem
    struct TradeState
      getter name : String
      getter money : TradingSystem::Money?
      getter stop : TradeStop?
      getter security_id : PkId

      def initialize(*,
                     @name : String,
                     @money : TradingSystem::Money?,
                     @stop : TradeStop?,
                     @security_id : PkId)
      end
    end
  end
end
