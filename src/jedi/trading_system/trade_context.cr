module Jedi
  module TradingSystem
    struct TradeContext
      getter trade : Trade
      getter settings_chain : SettingsChain
      getter current_settings : Settings?
      getter operations : TradingLife::Operations
      getter last_operation : TradingLife::Operation?

      def initialize(
        @trade : Trade,
        @settings_chain : SettingsChain,
        @current_settings : Settings?,
        @operations : TradingLife::Operations,
        @last_operation : TradingLife::Operation?,
      )
      end

      def has_settings? : Bool
        !@current_settings.nil?
      end

      def has_operations? : Bool
        !@last_operation.nil?
      end
    end
  end
end
