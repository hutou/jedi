module Jedi
  module TradingRules
    struct ScaleState
      getter name : String
      getter comment : String
      getter opscale : Scale::Operational

      def initialize(*,
                     @name : String,
                     @comment : String,
                     @opscale : Scale::Operational)
      end
    end
  end
end
