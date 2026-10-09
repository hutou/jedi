module Jedi
  module Tools
    module Helpers
      class_property scale_counter = 0

      def self.scale(
        conn_main : DB::Connection,
        conn_memory : DB::Connection,
        defscale : String,
        *,
        announce : Bool = true,
      )
        # First, check if defscale matches a scale from the memory database
        mem_scale = TradingRules::Scales.new(conn_memory)
          .fetch("SELECT id FROM scale WHERE name = '#{defscale}'").first?
        if mem_scale.nil?
          # Not there, then check if defscale matches a scale from the production database
          main_scale = TradingRules::Scales.new(conn_main)
            .fetch("SELECT id FROM scale WHERE name = '#{defscale}'").first?
          if main_scale.nil?
            # No, so perhaps a literal scale then, store in memory database
            # Scales.create raises if builder invalid
            scale_id = TradingRules::ScaleCreator.new(conn_memory)
              .call name: "LIT-#{Helpers.scale_counter += 1}",
                comment: "Literal", builder: defscale, announce: announce
          else
            # Yes, defscale is known in production database, add it to memory
            scale_id = TradingRules::ScaleCreator.new(conn_memory).call name: main_scale.name,
              comment: main_scale.comment, builder: main_scale.operational.builder,
              announce: announce
          end
        else
          # Yes, already in memory database
          scale_id = mem_scale.id
        end
        # return scale from memory database
        TradingRules::Scale.new(conn_memory, scale_id)
      end

      def self.parse_params(params_string)
        h = {} of String => String
        Core::Input.kv_decode(params_string, ESEP).each do |entity|
          k, v = entity.split(ESEP)
          if k.nil? || v.nil?
            raise LowLevelError.new("Error in decoding the parameters string '#{params_string}'",
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
          h[k.strip] = v.strip
        end
        h
      end

      def self.parse_int(value : String?, name : String) : Int32
        if value.nil?
          raise LowLevelError.new(
            "missing play parameter '#{name}'",
            key: "tools.play.decode.param_missing",
            kind: LowLevelError::Kind::UserInput,
            context: {:name => name},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end

        parsed = value.to_i?
        if parsed.nil?
          raise LowLevelError.new(
            "invalid integer play parameter '#{name}=#{value}'",
            key: "tools.play.decode.int_value_invalid",
            kind: LowLevelError::Kind::UserInput,
            context: {:name => name, :value => value},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        parsed
      end

      def self.parse_float(value : String?, name : String) : Float64
        if value.nil?
          raise LowLevelError.new(
            "missing play parameter '#{name}'",
            key: "tools.play.decode.param_missing",
            kind: LowLevelError::Kind::UserInput,
            context: {:name => name},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end

        parsed = value.to_f64?
        if parsed.nil?
          raise LowLevelError.new(
            "invalid decimal play parameter '#{name}=#{value}'",
            key: "tools.play.decode.float_value_invalid",
            kind: LowLevelError::Kind::UserInput,
            context: {:name => name, :value => value},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        parsed
      end
    end
  end
end
