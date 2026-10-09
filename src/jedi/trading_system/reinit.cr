module Jedi
  module TradingSystem
    enum ReInitMode
      Reset
      Merge
    end

    struct ReInitOption
      getter mode : ReInitMode
      getter c0 : Float64

      def initialize(@mode : ReInitMode, @c0 : Float64)
      end

      def reset? : Bool
        @mode == ReInitMode::Reset
      end

      def merge? : Bool
        @mode == ReInitMode::Merge
      end

      def to_s(io : IO) : Nil
        io << @mode.to_s.downcase << "," << @c0
      end

      def self.parse(raw : String) : self
        parts = raw.split(",", 2)

        if parts.size != 2
          raise LowLevelError.new(
            "reinit option: invalid format '#{raw}'.",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        mode_str = parts[0].strip.downcase
        c0_str = parts[1].strip

        mode =
          case mode_str
          when "reset" then ReInitMode::Reset
          when "merge" then ReInitMode::Merge
          else
            raise LowLevelError.new(
              "reinit option: value '#{mode_str}' invalid for 'mode'.",
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end

        c0 = c0_str.to_f64?

        if c0.nil?
          raise LowLevelError.new(
            "reinit option: value 'nil' invalid for 'c0'",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        new(mode, c0)
      end
    end
  end
end
