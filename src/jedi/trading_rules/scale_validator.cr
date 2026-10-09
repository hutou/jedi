module Jedi
  module TradingRules
    class Scale
      # Validates an already calculated scale draft.
      # No parsing and no construction logic belongs here.
      class Validator
        alias Result = NamedTuple(
          valid: Bool,
          key: String,
          context: Hash(Symbol, String))

        def self.validate(draft : Builder::Draft) : Result
          new(draft).validate
        end

        def initialize(@draft : Builder::Draft)
        end

        def validate : Result
          unless NP_MIN <= draft.np <= NP_MAX
            return invalid("invalid_np_value", {
              :np => draft.np.to_s, :np_min => NP_MIN.to_s, :np_max => NP_MAX.to_s,
            })
          end

          unless NN_MIN <= draft.nn <= NN_MAX
            return invalid("invalid_nn_value", {
              :nn => draft.nn.to_s, :nn_min => NN_MIN.to_s, :nn_max => NN_MAX.to_s,
            })
          end

          unless NP_MIN <= draft.emax <= NP_MAX
            return invalid("invalid_emax", {
              :emax => draft.emax.to_s, :np_min => NP_MIN.to_s, :np_max => NP_MAX.to_s,
            })
          end

          unless -NN_MAX <= draft.emin <= -NN_MIN
            return invalid("invalid_emin", {
              :emin => draft.emin.to_s, :nn_min => (-NN_MIN).to_s, :nn_max => (-NN_MAX).to_s,
            })
          end

          unless KI_MIN <= draft.ki <= KI_MAX
            return invalid("invalid_ki_value", {
              :ki => draft.ki.to_s, :ki_min => KI_MIN.to_s, :ki_max => KI_MAX.to_s,
            })
          end

          unless KB_MIN <= draft.kb <= KB_MAX
            return invalid("invalid_kb_value", {
              :kb => draft.kb.to_s, :kb_min => KB_MIN.to_s, :kb_max => KB_MAX.to_s,
            })
          end

          unless KD_MIN <= draft.kd <= KD_MAX
            return invalid("invalid_kd_value", {
              :kd => draft.kd.to_s, :kd_min => KD_MIN.to_s, :kd_max => KD_MAX.to_s,
            })
          end

          unless SR_MIN <= draft.sr <= SR_MAX
            return invalid("invalid_sr_value", {
              :sr => draft.sr.to_s, :sr_min => SR_MIN.to_s, :sr_max => SR_MAX.to_s,
            })
          end

          unless MI_MIN <= draft.mi <= MI_MAX
            return invalid("invalid_mi_value", {
              :mi => draft.mi.to_s, :mi_min => MI_MIN.to_s, :mi_max => MI_MAX.to_s,
            })
          end

          if draft.type.one?
            return invalid_kc unless valid_kc?
            return invalid_kc_difference unless valid_kc_difference?
            return invalid_kc_ks_sizes unless draft.kc.size - 2 == draft.ks.size
          elsif !(VR_MIN <= draft.vr <= VR_MAX)
            return invalid("invalid_vr_value", {
              :vr => draft.vr.to_s, :vr_min => VR_MIN.to_s, :vr_max => VR_MAX.to_s,
            })
          end

          return invalid_ks unless valid_ks?
          return invalid_ks_difference unless valid_ks_difference?

          {valid: true, key: "", context: {} of Symbol => String}
        end

        private getter draft

        private def invalid(suffix : String, context = {} of Symbol => String) : Result
          {
            valid:   false,
            key:     "scale.builder.validation.#{suffix}",
            context: context,
          }
        end

        private def valid_kc? : Bool
          kc = draft.kc
          !kc.empty? && kc == kc.sort.reverse.uniq && kc.max <= KC_MAX && kc.min >= KC_MIN
        end

        private def invalid_kc : Result
          invalid("invalid_kc_list", {:kc_min => KC_MIN.to_s, :kc_max => KC_MAX.to_s})
        end

        private def valid_kc_difference? : Bool
          positive = draft.kc_values[1]?
          negative = draft.kc_values[-1]?
          return false unless positive && negative

          (positive - 1) >= KC_DIFF_MIN && (1 - negative) >= KC_DIFF_MIN
        end

        private def invalid_kc_difference : Result
          invalid("kc_diff_too_low", {:kc_diff_min => KC_DIFF_MIN.to_s})
        end

        private def invalid_kc_ks_sizes : Result
          invalid("invalid_kc_ks", {
            :ks_size => draft.ks.size.to_s,
            :kc_size => draft.kc.size.to_s,
          })
        end

        private def valid_ks? : Bool
          ks = draft.ks
          !ks.empty? && ks == ks.sort.uniq && ks.max <= KS_MAX && ks.min >= KS_MIN
        end

        private def invalid_ks : Result
          invalid("invalid_ks_list", {:ks_min => KS_MIN.to_s, :ks_max => KS_MAX.to_s})
        end

        private def valid_ks_difference? : Bool
          positive = draft.ks_values[1]?
          negative = draft.ks_values[-1]?
          return false unless positive && negative

          (1 - positive) >= KS_DIFF_MIN && (negative - 1) >= KS_DIFF_MIN
        end

        private def invalid_ks_difference : Result
          invalid("ks_diff_too_low", {:ks_diff_min => KS_DIFF_MIN.to_s})
        end
      end
    end
  end
end
