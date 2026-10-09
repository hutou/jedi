require "./backtest_sizing_policy"
require "./backtest_execution_policy"
require "./backtest_result"
require "./backtest_engine"
require "./backtest_plotter"
require "./backtest_compact_reporter"
require "./backtest_reporter"

module Jedi
  module Tools
    # Public facade for the unified historical simulation command.
    class BackTest
      getter conn_main : DB::Connection
      getter conn_memory : DB::Connection
      getter quote_input : MarketData::QuoteHistoryInput
      getter scaledef : String
      getter money : TradingSystem::Money?
      getter! simulation_result : BacktestResult

      def initialize(
        @conn_main : DB::Connection,
        @conn_memory : DB::Connection,
        filename : String,
        @scaledef : String,
        @money : TradingSystem::Money?,
      )
        @quote_input = MarketData::FileQuoteHistoryInput.new(filename)
      end

      def initialize(
        @conn_main : DB::Connection,
        @conn_memory : DB::Connection,
        @quote_input : MarketData::QuoteHistoryInput,
        @scaledef : String,
        @money : TradingSystem::Money?,
      )
      end

      def filename : String
        quote_input.description
      end

      def run(
        *,
        option_command : Hash(Char, String),
        option_records : String? = nil,
        option_capital : Float64? = nil,
        option_distance : Float64? = nil,
        option_date : String? = nil,
        option_minimum_quantity : Int32? = nil,
        option_operability_steps : Int32? = nil,
        option_execution : String? = nil,
        option_opening_day_orders : String? = nil,
        option_display : String = "compact",
      ) : String
        validate_display!(option_display)
        quote_history = QuoteHistory.new(
          quote_input,
          option_records,
          option_date,
        )
        if quote_history.quotes.empty?
          raise LowLevelError.new(
            "quotation history is empty",
            key: "tools.backtest.quotation_not_available",
            kind: LowLevelError::Kind::Domain,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end

        sizing_policy = build_sizing_policy(
          capital: option_capital,
          distance: option_distance,
          minimum_quantity: option_minimum_quantity,
          operability_steps: option_operability_steps,
        )

        execution_policy = build_execution_policy(
          option_execution,
          option_opening_day_orders,
        )

        @simulation_result = BacktestEngine.new(
          conn_main: conn_main,
          conn_memory: conn_memory,
          quote_history: quote_history,
          scaledef: scaledef,
          money: money,
          sizing_policy: sizing_policy,
          execution_policy: execution_policy,
        ).run

        BacktestReporter.new(conn_memory, simulation_result)
          .render(option_command, technical: option_display == "technical")
      end

      private def validate_display!(value : String) : Nil
        return if value.in?({"compact", "technical"})

        raise LowLevelError.new(
          "invalid backtest display mode '#{value}'",
          key: "tools.backtest.display.invalid_mode",
          kind: LowLevelError::Kind::UserInput,
          context: {:value => value},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
        )
      end

      private def build_execution_policy(
        raw_mode : String?,
        raw_opening_day : String?,
      ) : BacktestExecutionPolicy
        mode = case raw_mode.try(&.downcase)
               when nil, "", "conservative"
                 BacktestExecutionMode::Conservative
               when "legacy"
                 BacktestExecutionMode::Legacy
               else
                 raise_invalid_execution_option("execution", raw_mode.not_nil!)
               end

        opening_day = case raw_opening_day.try(&.downcase)
                      when nil, "", "next"
                        BacktestOpeningDayPolicy::NextSession
                      when "same"
                        BacktestOpeningDayPolicy::SameSession
                      else
                        raise_invalid_execution_option(
                          "opening-day-orders",
                          raw_opening_day.not_nil!,
                        )
                      end

        BacktestExecutionPolicy.new(
          mode: mode,
          opening_day: opening_day,
        )
      end

      private def raise_invalid_execution_option(
        name : String,
        value : String,
      ) : NoReturn
        raise LowLevelError.new(
          "invalid backtest execution option '#{name}=#{value}'",
          key: "tools.backtest.invalid_execution_option",
          kind: LowLevelError::Kind::UserInput,
          context: {
            :name  => name,
            :value => value,
          } of Symbol => String,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
        )
      end

      private def build_sizing_policy(
        *,
        capital : Float64?,
        distance : Float64?,
        minimum_quantity : Int32?,
        operability_steps : Int32?,
      ) : BacktestSizingPolicy
        if capital.nil?
          unless minimum_quantity.nil? && operability_steps.nil?
            raise LowLevelError.new(
              "operability options require capital sizing",
              key: "tools.backtest.operability_requires_capital",
              kind: LowLevelError::Kind::UserInput,
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            )
          end

          return FixedAmountSizingPolicy.new(
            configure_fixed_amount!(distance),
          )
        end

        active_capital = capital.not_nil!

        unless distance.nil?
          raise LowLevelError.new(
            "options '--capital' and '--distance' are mutually exclusive",
            key: "infra.exclusive_options",
            kind: LowLevelError::Kind::UserInput,
            context: {
              :opt1 => "--capital",
              :opt2 => "--distance",
            } of Symbol => String,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end

        active_money = money
        if active_money.nil?
          raise LowLevelError.new(
            "capital sizing requires a money definition",
            key: "tools.backtest.capital_requires_money",
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end

        active_money = active_money.not_nil!

        if !active_capital.finite? || active_capital <= 0.0
          raise LowLevelError.new(
            "backtest capital must be strictly positive",
            key: "tools.backtest.invalid_capital",
            kind: LowLevelError::Kind::UserInput,
            context: {:capital => active_capital.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end

        CapitalSizingPolicy.new(
          capital: active_capital,
          risk_rate: active_money.risk_rate,
          stop_steps: active_money.steps_down,
          minimum_quantity: minimum_quantity ||
                            TradingSystem::OrderEngine::WARNING_QUANTITY_THRESHOLD,
          operability_steps: operability_steps || App.diagnostic_steps,
        )
      end

      private def configure_fixed_amount!(distance : Float64?) : Float64
        App.distance = distance unless distance.nil?

        if App.capital <= 0
          raise LowLevelError.new(
            "configured backtest capital must be strictly positive",
            key: "tools.backtest.invalid_capital",
            kind: LowLevelError::Kind::UserInput,
            context: {:capital => App.capital.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        if App.distance <= 0.0
          raise LowLevelError.new(
            "configured backtest distance must be strictly positive",
            key: "tools.backtest.invalid_distance",
            kind: LowLevelError::Kind::UserInput,
            context: {:distance => App.distance.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end

        App.initial_investment = (
          App.capital.to_f * App.risk_rate / App.distance
        ).to_i
        App.initial_investment.to_f
      end
    end
  end
end
