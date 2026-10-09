module Jedi
  module TradingRules
    class Scale
      # Compatibility facade converting a textual builder into Operational.
      # The actual parsing, calculation and validation are delegated.
      class Decoder
        getter build_def : String

        def initialize(@build_def : String)
        end

        def decode : Operational
          builder = Builder.new(build_def)
          @build_def = builder.formatted_builder
          built = builder.canonical_scale
          ensure_valid!(built)
          to_operational(built)
        end

        private def ensure_valid!(built : Builder::BuiltScale) : Nil
          status = built.check
          return if status[:valid]
          raise LowLevelError.new(
            key: status[:key],
            context: status[:context],
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        private def to_operational(built : Builder::BuiltScale) : Operational
          kb = built.kb.zero? ? TradingRules::Kb::Pwr : TradingRules::Kb::Mtp
          ks_values = built.ks_values.dup
          ks_values[0] = 1.0

          case built.type
          in Operational::Type::One
            kc_values = built.kc_vr.as(Hash(Int32, Float64)).dup
            kc_values[0] = 1.0

            Operational.new(
              type: built.type,
              definition: built.definition,
              builder: built.builder,
              ks_values: ks_values,
              emax: built.emax,
              emin: built.emin,
              ki: built.ki,
              kb: kb,
              kc_values: kc_values)
          in Operational::Type::Two
            Operational.new(
              type: built.type,
              definition: built.definition,
              builder: built.builder,
              ks_values: ks_values,
              emax: built.emax,
              emin: built.emin,
              ki: built.ki,
              kb: kb,
              vr_value: built.kc_vr.as(Float64))
          end
        end
      end

      # Backward-compatible name used throughout the current codebase.
      alias Type = Decoder
    end
  end
end
