module Jedi
  module Tools
    enum ScoringSearchFamily
      FreeCoefficients
      RegularGeometric
      FlexibleGeometric
      Custom

      def key : String
        case self
        in ScoringSearchFamily::FreeCoefficients
          "P1"
        in ScoringSearchFamily::RegularGeometric
          "P2"
        in ScoringSearchFamily::FlexibleGeometric
          "P3"
        in ScoringSearchFamily::Custom
          "custom"
        end
      end
    end

    struct ScoringSearchSpec
      getter family : ScoringSearchFamily
      getter builder : String
      getter key : String

      def initialize(
        @family : ScoringSearchFamily,
        @builder : String,
        @key : String,
      )
      end
    end

    # Internal search families used by the normal score workflow.
    #
    # These values intentionally reproduce the former configurable P1/P2/P3
    # definitions. S3 changes their status and orchestration, not their search
    # domains; calibration can therefore be performed independently later.
    module ScoringSearchPresets
      extend self

      VERSION = 1

      P1 = "kc:1.61,1.5,1.38,1.23,1.14,0.88,0.76,0.64,0.52,0.4," +
           "ki:0%,10%,15%,20%,25%,30%,kb:1,kd:0.0,0.1,0.2,0.3,mg:2"

      P2 = "vr:5%,10%,15%,20%,25%,30%,np:2,3,4,5,nn:2,3,4,5," +
           "ki:0%,10%,15%,20%,25%,30%,kb:1,kd:0.0,0.1,0.2,0.3"

      P3 = "vr:5%,10%,15%,20%,25%,30%,np:5,nn:5," +
           "ki:0%,10%,15%,20%,25%,30%,kb:1,kd:0.0,0.1,0.2,0.3,mg:2"

      def all : Array(ScoringSearchSpec)
        [
          ScoringSearchSpec.new(
            ScoringSearchFamily::FreeCoefficients,
            P1,
            "P1",
          ),
          ScoringSearchSpec.new(
            ScoringSearchFamily::RegularGeometric,
            P2,
            "P2",
          ),
          ScoringSearchSpec.new(
            ScoringSearchFamily::FlexibleGeometric,
            P3,
            "P3",
          ),
        ]
      end

      def resolve(key : String) : ScoringSearchSpec?
        case key.upcase
        when "P1"
          all[0]
        when "P2"
          all[1]
        when "P3"
          all[2]
        else
          nil
        end
      end

      def custom(builder : String) : ScoringSearchSpec
        ScoringSearchSpec.new(
          ScoringSearchFamily::Custom,
          builder,
          "custom",
        )
      end
    end
  end
end
