module Jedi
  module TradingRules
    class Scale
      # Immutable operational representation consumed by the trading engine.
      # It is the canonical, JSON-serializable result of a builder definition.
      struct Operational
        include JSON::Serializable

        enum Type
          One
          Two

          def label : String
            case self
            in .one?
              I18n.t("scale.operational.type.one")
            in .two?
              I18n.t("scale.operational.type.two")
            end
          end
        end

        getter type : Type
        getter definition : String
        getter builder : String
        getter ks_values : Hash(Int32, Float64)
        getter emax : Int32
        getter emin : Int32
        getter ki : Float64
        getter kb : TradingRules::Kb
        getter kc_values : Hash(Int32, Float64)?
        getter vr_value : Float64?

        def initialize(
          @type : Type,
          @definition : String,
          @builder : String,
          @ks_values : Hash(Int32, Float64),
          @emax : Int32,
          @emin : Int32,
          @ki : Float64,
          @kb : TradingRules::Kb,
          @kc_values : Hash(Int32, Float64)? = nil,
          @vr_value : Float64? = nil,
        )
        end

        def optimized? : Bool
          kcb = kb.pwr? ? (1 + ki) ** -1 : 1 - ki

          case type
          in Type::One
            jump_up_optimized = (1 + ki) / kc(emax) < ks(emax - 1)
            jump_down_optimized = kcb / kc(emin) > ks(emin + 1)
          in Type::Two
            jump_up_optimized = (1 + ki) / (1 + vr) ** emax < ks(emax - 1)
            jump_down_optimized = kcb / (1 - vr) ** emin.abs > ks(emin + 1)
          end

          jump_up_optimized && jump_down_optimized
        end

        def kclist : Hash(Int32, Float64)
          kc_values || raise LowLevelError.new("scale.operational.missing_kc",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        def kslist : Hash(Int32, Float64)
          ks_values
        end

        def ks(step : Int32) : Float64
          ks_values[step]
        end

        def kc(step : Int32) : Float64
          kclist[step]
        end

        def vr : Float64
          vr_value || raise LowLevelError.new("scale.operational.missing_vr",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end
    end
  end
end
