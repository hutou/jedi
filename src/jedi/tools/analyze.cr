module Jedi
  module Tools
    # Compatibility adapter kept for one transition cycle. The CLI no longer
    # exposes `tools analyze`; all simulations are handled by `tools backtest`.
    class Analyze
      getter conn_main : DB::Connection
      getter conn_memory : DB::Connection
      getter filename : String
      getter scaledef : String
      getter money : TradingSystem::Money?

      def initialize(
        @conn_main : DB::Connection,
        @conn_memory : DB::Connection,
        @filename : String,
        @scaledef : String,
        @money : TradingSystem::Money?,
      )
      end

      def run(
        option_command : Hash(Char, String),
        option_records : String?,
        option_verbose,
        option_capital : Float64?,
        option_distance : Float64?,
        option_date : String?,
      ) : String
        BackTest.new(
          conn_main,
          conn_memory,
          filename,
          scaledef,
          money,
        ).run(
          option_command: option_command,
          option_records: option_records,
          option_capital: option_capital,
          option_distance: option_distance,
          option_date: option_date,
        )
      end
    end
  end
end
