module Jedi
  module Exchange
    # Class allowing rounding management specific to the financial markets
    class Security
      class Tick
        VALID_TICKS = [500.0, 200.0, 100.0, 50.0, 20.0, 10.0, 5.0, 2.0, 1.0,
                       0.5, 0.2, 0.1, 0.05, 0.02, 0.01, 0.005, 0.002, 0.001,
                       0.0005, 0.0002, 0.0001]
        getter value : Float64 = 0.0
        def_equals @value

        def initialize(t : Float64 | String)
          tick = Tick.ensure_valid!(t)
          @value = tick.is_a?(String) ? tick.to_f : tick
        end

        def self.valid?(tick : String | Float64) : Bool
          case tick
          in Float64
            tick.in?(VALID_TICKS)
          in String
            if (t = tick.to_f?)
              t.in?(VALID_TICKS)
            else
              false
            end
          end
        end

        def self.ensure_valid!(tick)
          return tick if valid?(tick)
          raise LowLevelError.new(
            key: "tick.invalid_value",
            context: {:tick => "#{tick}"},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        def to_s(io : IO)
          io << @value
        end

        # Rounds up, when prices increase
        def round_up(price)
          ((price.as(Float64) / @value).ceil * @value).round(-Math.log10(@value).floor)
        end

        # Rounds down, when prices decrease
        def round_down(price)
          ((price / @value).floor * @value).round(-Math.log10(@value).floor)
        end

        def price_valid?(price)
          price == round_up(price) || price == round_down(price)
        end
      end
    end
  end
end
