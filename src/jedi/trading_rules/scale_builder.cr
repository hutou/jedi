module Jedi
  module TradingRules
    class Scale
      # Converts typed builder input into a canonical scale draft.
      # Parsing is delegated to BuilderInput and validation to Validator.
      class Builder
        alias BuilderValue = BuilderInput::Value

        record BuiltScale,
          check : NamedTuple(valid: Bool, key: String, context: Hash(Symbol, String)),
          type : Scale::Operational::Type,
          definition : String,
          builder : String,
          kc_vr : Float64 | Hash(Int32, Float64),
          ks_values : Hash(Int32, Float64),
          emax : Int32,
          emin : Int32,
          ki : Float64,
          kb : Int32

        record Draft,
          type : Scale::Operational::Type,
          kc : Array(Float64),
          ks : Array(Float64),
          kc_values : Hash(Int32, Float64),
          ks_values : Hash(Int32, Float64),
          emax : Int32,
          emin : Int32,
          ki : Float64,
          kb : Int32,
          vr : Float64,
          kd : Float64,
          np : Int32,
          nn : Int32,
          sr : Float64,
          mi : Float64

        getter input : BuilderInput

        def initialize(params : String) : Nil
          @input = BuilderInput.new(params)
        end

        def vars : Hash(String, BuilderValue)
          input.values
        end

        def formatted_builder : String
          input.formatted
        end

        def canonical_scale : BuiltScale
          draft = case input.signature
                  when "kc,ks,ki,kb"
                    build_type_one_canonical
                  when "kc,ki,kb,kd"
                    build_type_one_optimized
                  when "vr,ks,ki,kb"
                    build_type_two_canonical
                  when "vr,np,nn,ki,kb,kd"
                    build_type_two_optimized
                  when "vr,np,sr,nn,mi,ki,kb"
                    build_type_two_legacy
                  else
                    invalid_signature!
                  end

          to_built_scale(draft)
        end

        # Compatibility helpers retained for existing callers.
        def get_kc(_vars = vars) : Array(Float64)
          input.float_array("kc")
        end

        def get_ks(_vars = vars) : Array(Float64)
          input.float_array("ks")
        end

        def get_ki(_vars = vars) : Float64
          input.float("ki", KI_MIN)
        end

        def get_kb(_vars = vars) : Int32
          input.int("kb", KB_MAX)
        end

        def get_vr(_vars = vars) : Float64
          input.float("vr", VR_MIN)
        end

        def get_kd(_vars = vars) : Float64
          input.float("kd", KD_MIN + KD_MAX)
        end

        def get_np(_vars = vars) : Int32
          input.int("np", (NP_MIN + NP_MAX) // 2)
        end

        def get_nn(_vars = vars) : Int32
          input.int("nn", (NN_MIN + NN_MAX) // 2)
        end

        def get_sr(_vars = vars) : Float64
          input.float("sr", SR_MIN)
        end

        def get_mi(_vars = vars) : Float64
          input.float("mi", MI_MIN)
        end

        private def build_type_one_canonical : Draft
          kc = get_kc
          ks = get_ks
          kc_values = index_kc(kc)
          ks_values = index_ks(ks)

          draft(
            type: Operational::Type::One,
            kc: kc,
            ks: ks,
            kc_values: kc_values,
            ks_values: ks_values,
            emax: kc_values.keys.max,
            emin: kc_values.keys.min)
        end

        private def build_type_one_optimized : Draft
          kc = get_kc
          kc_values = index_kc(kc)
          emax = kc_values.keys.max
          emin = kc_values.keys.min
          ki = get_ki
          kd = get_kd

          ks_values = distribute_ks(
            emax: emax,
            emin: emin,
            spe_up: (1 + ki) / kc_values[emax],
            spe_down: (1 - ki) / kc_values[emin],
            kd: kd)
          ks = ks_values.values.sort

          draft(
            type: Operational::Type::One,
            kc: kc,
            ks: ks,
            kc_values: kc_values,
            ks_values: ks_values,
            emax: emax,
            emin: emin,
            ki: ki,
            kd: kd)
        end

        private def build_type_two_canonical : Draft
          ks = get_ks
          ks_values = index_ks(ks)

          draft(
            type: Operational::Type::Two,
            ks: ks,
            ks_values: ks_values,
            emax: ks_values.keys.max + 1,
            emin: ks_values.keys.min - 1,
            vr: get_vr)
        end

        private def build_type_two_optimized : Draft
          vr = get_vr
          np = get_np
          nn = get_nn
          ki = get_ki
          kd = get_kd
          emax = np
          emin = -nn

          ks_values = distribute_ks(
            emax: emax,
            emin: emin,
            spe_up: (1 + ki) / ((1 + vr) ** np),
            spe_down: (1 - ki) / ((1 - vr) ** nn),
            kd: kd)
          ks = ks_values.values.sort

          draft(
            type: Operational::Type::Two,
            ks: ks,
            ks_values: ks_values,
            emax: emax,
            emin: emin,
            vr: vr,
            ki: ki,
            kd: kd,
            np: np,
            nn: nn)
        end

        private def build_type_two_legacy : Draft
          vr = get_vr
          np = get_np
          nn = get_nn
          sr = get_sr
          mi = get_mi
          emax = np
          emin = -nn

          # The legacy formula uses the number of internal steps, excluding
          # the two terminal levels represented by emax and emin.
          internal_np = np - 1
          internal_nn = nn - 1
          ks_values = {} of Int32 => Float64

          kq_up = (1 - sr) / internal_np
          1.upto(internal_np) do |step|
            ks_values[step] = (1 - kq_up * step).round(2)
          end

          kq_down = compute_kq(vr, mi, internal_nn)
          1.upto(internal_nn) do |step|
            ks_values[-step] = (1 + kq_down * step).round(2)
          end

          draft(
            type: Operational::Type::Two,
            ks: ks_values.values.sort,
            ks_values: ks_values,
            emax: emax,
            emin: emin,
            vr: vr,
            np: internal_np,
            nn: internal_nn,
            sr: sr,
            mi: mi)
        end

        private def draft(*,
                          type : Operational::Type,
                          kc : Array(Float64) = [] of Float64,
                          ks : Array(Float64),
                          kc_values : Hash(Int32, Float64) = {} of Int32 => Float64,
                          ks_values : Hash(Int32, Float64),
                          emax : Int32,
                          emin : Int32,
                          ki : Float64 = get_ki,
                          kb : Int32 = get_kb,
                          vr : Float64 = VR_MIN,
                          kd : Float64 = 0.0,
                          np : Int32 = NP_MAX,
                          nn : Int32 = NN_MAX,
                          sr : Float64 = SR_MIN,
                          mi : Float64 = MI_MIN) : Draft
          Draft.new(
            type: type,
            kc: kc,
            ks: ks,
            kc_values: kc_values,
            ks_values: ks_values,
            emax: emax,
            emin: emin,
            ki: ki,
            kb: kb,
            vr: vr,
            kd: kd,
            np: np,
            nn: nn,
            sr: sr,
            mi: mi)
        end

        private def to_built_scale(draft : Draft) : BuiltScale
          BuiltScale.new(
            check: Validator.validate(draft),
            type: draft.type,
            definition: canonical_definition(draft),
            builder: formatted_builder,
            kc_vr: draft.type.one? ? draft.kc_values : draft.vr,
            ks_values: draft.ks_values,
            emax: draft.emax,
            emin: draft.emin,
            ki: draft.ki,
            kb: draft.kb)
        end

        private def canonical_definition(draft : Draft) : String
          String.build do |io|
            if draft.type.one?
              io << "kc:" << draft.kc_values.values.sort.reverse.join(",")
            else
              io << "vr:" << Core::Utils.to_pct(draft.vr)
            end

            io << ", ks:" << draft.ks_values.values.sort.join(",")
            io << ", ki:" << Core::Utils.to_pct(draft.ki)
            io << ", kb:" << draft.kb
          end
        end

        private def index_kc(values : Array(Float64)) : Hash(Int32, Float64)
          indexed = {} of Int32 => Float64

          values.select { |value| value > 1 }.sort.each_with_index(1) do |value, step|
            indexed[step] = value.round(2)
          end
          values.select { |value| value < 1 }.each_with_index(1) do |value, step|
            indexed[-step] = value.round(2)
          end

          indexed
        end

        private def index_ks(values : Array(Float64)) : Hash(Int32, Float64)
          indexed = {} of Int32 => Float64

          values.select { |value| value < 1 }.sort.reverse.each_with_index(1) do |value, step|
            indexed[step] = value.round(2)
          end
          values.select { |value| value > 1 }.each_with_index(1) do |value, step|
            indexed[-step] = value.round(2)
          end

          indexed
        end

        private def distribute_ks(*,
                                  emax : Int32,
                                  emin : Int32,
                                  spe_up : Float64,
                                  spe_down : Float64,
                                  kd : Float64) : Hash(Int32, Float64)
          values = {} of Int32 => Float64
          up = Core::Collection.distribute(1 - spe_up, emax, 1 + kd)
          down = Core::Collection.distribute(spe_down - 1, -emin, 1 + kd)

          up.pop
          down.pop

          up.accumulate.each_with_index(1) do |quantity, step|
            values[step] = (1 - quantity).round(2)
          end
          down.accumulate.each_with_index(1) do |quantity, step|
            values[-step] = (1 + quantity).round(2)
          end

          values
        end

        private def compute_kq(vr : Float64, mi : Float64, nn : Int32) : Float64
          geometric_sum = 0.0
          1.upto(nn) do |step|
            geometric_sum += (1 - vr) ** step
          end
          mi / geometric_sum
        end

        private def invalid_signature! : NoReturn
          raise LowLevelError.new(
            "Scale builder: invalid key set #{input.signature}",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end
    end
  end
end
