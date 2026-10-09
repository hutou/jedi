module Jedi
  module TradingRules
    class Scale
      # Parses the textual builder syntax and provides typed access to values.
      # It does not calculate or validate a scale.
      class BuilderInput
        alias Value = Float64 | Int32 | Array(Float64) | Array(Int32)

        PERCENT_KEYS = {"ki", "vr", "sr", "mi"}
        FLOAT_KEYS   = {"kc", "ks", "kd"}
        INTEGER_KEYS = {"kb", "np", "nn", "mg"}

        getter values : Hash(String, Value)

        def initialize(source : String)
          @values = parse(source)
        end

        def signature : String
          KEYWORDS.select { |key| values.has_key?(key) }.join(",")
        end

        def formatted : String
          String.build do |io|
            values.each_with_index do |(key, value), index|
              io << ", " unless index.zero?
              io << key << ':' << formatted_value(key, value)
            end
          end
        end

        def float(key : String, default : Float64) : Float64
          case value = values[key]?
          when Float64
            value
          when Nil
            default
          else
            invalid_type!(key, value, "float")
          end
        end

        def int(key : String, default : Int32) : Int32
          case value = values[key]?
          when Int32
            value
          when Nil
            default
          else
            invalid_type!(key, value, "integer")
          end
        end

        def float_array(key : String) : Array(Float64)
          case value = values[key]?
          when Array(Float64)
            value
          when Float64
            [value]
          when Nil
            [] of Float64
          else
            invalid_type!(key, value, "float list")
          end
        end

        private def parse(source : String) : Hash(String, Value)
          result = {} of String => Value

          Core::Input.kv_decode(source, CSEP).each do |element|
            parts = element.split(CSEP, 2)
            unless parts.size == 2
              raise LowLevelError.new(
                "Scale builder: invalid key:value element #{element}",
                log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
            end

            key = parts[0]
            raw_value = parts[1]
            result[key] = decode_value(key, raw_value)
          end

          result
        end

        private def decode_value(key : String, value : String) : Value
          if FLOAT_KEYS.includes?(key)
            decode_float_or_list(key, value)
          elsif PERCENT_KEYS.includes?(key)
            decode_percentage_or_list(key, value)
          elsif INTEGER_KEYS.includes?(key)
            decode_integer_or_list(key, value)
          else
            raise LowLevelError.new(
              "Scale builder: invalid key #{key}",
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
        end

        private def decode_float_or_list(key : String, value : String) : Float64 | Array(Float64)
          decode_scalar_or_list(value) do |item|
            # Core::ZZZConversion.read_decimal(item, key).round(2)
            Core::Input.ensure_decimal_valid!(item, field: key).round(2)
          end
        end

        private def decode_percentage_or_list(key : String, value : String) : Float64 | Array(Float64)
          decode_scalar_or_list(value) do |item|
            # Core::ZZZConversion.read_decimal_pct(item, key).round(2)
            Core::Input.ensure_decimal_pct_valid!(item, field: key).round(2)
          end
        end

        private def decode_integer_or_list(key : String, value : String) : Int32 | Array(Int32)
          if value.index(',')
            value.split(',').map { |item|
              Core::Input.ensure_integer_valid!(item, field: key)
            }
            # Core::Input.ensure_string_valid!(item, field: key,
            #   regex: POSITIVE_INTEGER, key: "infra.field_required").to_i
          else
            Core::Input.ensure_integer_valid!(value, field: key)
            # Core::Input.ensure_string_valid!(value, field: key,
            #   regex: POSITIVE_INTEGER, key: "infra.field_required").to_i
          end
        end

        private def decode_scalar_or_list(value : String, &block : String -> Float64) : Float64 | Array(Float64)
          if value.index(',')
            value.split(',').map { |item| yield item }
          else
            yield value
          end
        end

        private def formatted_value(key : String, value : Value) : String
          case value
          in Array(Float64)
            value.map { |item| formatted_float(key, item) }.join(",")
          in Array(Int32)
            value.join(",")
          in Float64
            formatted_float(key, value)
          in Int32
            value.to_s
          end
        end

        private def formatted_float(key : String, value : Float64) : String
          PERCENT_KEYS.includes?(key) ? Core::Utils.to_pct(value) : value.to_s
        end

        private def invalid_type!(key : String, value : Value, expected : String) : NoReturn
          raise LowLevelError.new(
            "Scale builder: expected #{expected} for #{key}, got #{value}",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end
    end
  end
end
