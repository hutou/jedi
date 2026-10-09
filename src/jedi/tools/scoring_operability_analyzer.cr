module Jedi
  module Tools
    # Terminal operability observed after a completed historical simulation.
    #
    # It deliberately does not change BacktestEngine behavior or its financial
    # result. It only answers whether the final open scale state is still able
    # to generate meaningful directional orders.
    struct ScoringOperability
      getter known : Bool
      getter operable : Bool
      getter status : String
      getter minimum_directional_quantity : Int32?
      getter terminal_inactivity_days : Int32
      getter warnings : Array(String)

      def initialize(
        @known : Bool,
        @operable : Bool,
        @status : String,
        @minimum_directional_quantity : Int32?,
        @terminal_inactivity_days : Int32,
        @warnings : Array(String) = [] of String,
      )
      end

      def self.unknown : ScoringOperability
        new(false, true, "unknown", nil, 0)
      end

      def self.closed(terminal_inactivity_days : Int32) : ScoringOperability
        new(true, true, "closed", nil, terminal_inactivity_days)
      end

      def terminally_inoperable? : Bool
        known && !operable
      end
    end

    # Reuses TradingSystem::OrderEngine's own operating diagnostics on the
    # final state created by BacktestEngine. This keeps one business truth for
    # Play, Backtest and Score instead of inventing another quantity formula.
    class ScoringOperabilityAnalyzer
      def self.analyze(
        result : BacktestResult,
        minimum_quantity : Int32 = 2,
      ) : ScoringOperability
        last_operation = result.operations.last?
        return ScoringOperability.unknown if last_operation.nil?

        inactivity_days = terminal_inactivity_days(result, last_operation.timestamp)
        return ScoringOperability.closed(inactivity_days) if last_operation.stock <= 0

        engine = TradingSystem::OrderEngine.new(last_operation.settings.trade)
        orders = engine.orders(false)
        quantities = directional_quantities(orders)
        minimum = quantities.min?
        status = engine.operating_status
        status_operable = status != TradingSystem::OrderEngine::OperatingStatus::Blocked
        quantity_operable = if value = minimum
                              value >= minimum_quantity
                            else
                              false
                            end

        ScoringOperability.new(
          known: true,
          # Degraded is an informational warning. Only a blocked current
          # state, or a quantity below the caller's threshold, is inoperable.
          operable: status_operable && quantity_operable,
          status: status.to_s,
          minimum_directional_quantity: minimum,
          terminal_inactivity_days: inactivity_days,
          warnings: engine.operating_warnings.map(&.to_s),
        )
      end

      private def self.directional_quantities(
        orders : Hash(Symbol, TradingSystem::OrderEngine::Order),
      ) : Array(Int32)
        quantities = [] of Int32
        [:up, :down].each do |key|
          if order = orders[key]?
            quantities << order.quantity
          end
        end
        quantities
      end

      private def self.terminal_inactivity_days(
        result : BacktestResult,
        last_operation_date : Time,
      ) : Int32
        days = (result.quote_history.date_last - last_operation_date).total_days.to_i
        days < 0 ? 0 : days
      end
    end
  end
end
