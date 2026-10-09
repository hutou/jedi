module Jedi
  module TradingSystem
    class Money
      getter risk_rate
      getter target_coeff
      getter steps_down

      def initialize(
        @risk_rate : Float64,
        @target_coeff : Float64,
        @steps_down : Int32,
      )
      end

      def_equals @risk_rate, @target_coeff, @steps_down

      def self.parse(value : String?) : self?
        return nil if value.nil?

        value = value.strip
        return nil if value.empty?

        parse_value(value)
      end

      def self.parse_value(raw : String) : self
        value = raw.gsub(/\s+/, "").downcase
        limits = App.money_limits
        fields = value.split(",")
        unless fields.size == 3
          generate_exception("Invalid money definition, 3 comma separated fields expected: '#{raw}'")
        end

        values = Hash(String, String).new
        fields.each do |field|
          key, separator, item = field.partition(':')
          if separator.empty? || item.empty?
            generate_exception("Invalid money definition, empty value for key '#{key}'")
          end
          values[key] = item
        end
        unless values.keys.sort == ["n", "o", "r"]
          generate_exception("Invalid money definition, keys 'r', 'o' and 'n' expected: '#{raw}'")
        end

        # risk_rate
        nraw = hraw = values["r"]
        if hraw.ends_with?("%")
          nraw = hraw.chomp('%')
          divisor = 100
        else
          divisor = 1
        end

        if (nraw =~ /^[+-]?\d+\.?\d*$/).nil?
          generate_exception("Invalid money risk rate: #{hraw}")
        end

        risk_rate = nraw.to_f / divisor
        unless limits.risk_rate_min <= risk_rate <= limits.risk_rate_max
          generate_exception("Invalid money risk rate: #{hraw}")
        end

        # target_coeff
        hraw = values["o"]
        if (hraw =~ /^[+-]?\d+\.?\d*$/).nil?
          generate_exception("Invalid money coefficient: #{hraw}")
        end

        target_coeff = hraw.to_f
        unless limits.target_coeff_min <= target_coeff <= limits.target_coeff_max
          generate_exception("Invalid money coefficient: #{hraw}")
        end

        # steps_down
        hraw = values["n"]
        if (hraw =~ /^[+-]?\d+$/).nil?
          generate_exception("Invalid money steps: #{hraw}")
        end

        steps_down = hraw.to_i
        unless limits.steps_down_min <= steps_down <= limits.steps_down_max
          generate_exception("Invalid money steps: #{hraw}")
        end

        new(
          risk_rate: risk_rate,
          target_coeff: target_coeff,
          steps_down: steps_down,
        )
      end

      def self.generate_exception(reason) : NoReturn
        raise LowLevelError.new(reason,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      def to_s(io : IO)
        io << "r:" << Core::Utils.to_pct(@risk_rate)
        io << ", o:" << @target_coeff
        io << ", n:" << @steps_down
      end

      def risk_amount(capital : Float64) : Float64
        capital * risk_rate
      end

      def target_amount(capital : Float64) : Float64
        risk_amount(capital) * target_coeff
      end
    end
  end
end
