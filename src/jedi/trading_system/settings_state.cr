module Jedi
  module TradingSystem
    struct SettingsState
      getter rank : Int32
      getter split : Exchange::Security::Split?
      getter sync : TradingRules::Position?
      getter reinit : TradingSystem::ReInitOption?
      getter q0 : Float64
      getter c0 : Float64
      getter position : TradingRules::Position
      getter kspc : Float64
      getter kcpc : Float64

      def initialize(
        @rank : Int32,
        @split : Exchange::Security::Split?,
        @sync : TradingRules::Position?,
        @reinit : TradingSystem::ReInitOption?,
        @q0 : Float64,
        @c0 : Float64,
        @position : TradingRules::Position,
        @kspc : Float64,
        @kcpc : Float64,
      )
      end
    end
  end
end
