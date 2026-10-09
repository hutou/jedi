module Jedi
  module Tools
    enum CandidateSizingMode
      FixedAmount
      Capital
    end

    enum CandidatePriceSource
      Explicit
      Stored
    end

    enum CandidateFailure
      InitialQuantityZero
      InsufficientOperability
      CapitalSizing
    end

    class CandidateEvaluation
      getter isin : String
      getter security : Exchange::Security?
      getter scale : TradingRules::Scale
      getter price : Float64
      getter mode : CandidateSizingMode
      getter target_amount : Float64
      getter quantity : Int32
      getter opening_amount : Float64
      getter minimum_operable_quantity : Int32
      getter operability_steps : Int32
      getter minimum_quantity : Int32
      getter failure : CandidateFailure?
      getter capital : Float64?
      getter money : TradingSystem::Money?
      getter position_sizing : PositionSizing?
      getter funding : CandidateFunding?
      getter price_source : CandidatePriceSource
      getter price_date : Time?

      def initialize(
        @isin : String,
        @security : Exchange::Security?,
        @scale : TradingRules::Scale,
        @price : Float64,
        @mode : CandidateSizingMode,
        @target_amount : Float64,
        @quantity : Int32,
        @opening_amount : Float64,
        @minimum_operable_quantity : Int32,
        @operability_steps : Int32,
        @minimum_quantity : Int32,
        @failure : CandidateFailure? = nil,
        @capital : Float64? = nil,
        @money : TradingSystem::Money? = nil,
        @position_sizing : PositionSizing? = nil,
        @funding : CandidateFunding? = nil,
        @price_source : CandidatePriceSource = CandidatePriceSource::Explicit,
        @price_date : Time? = nil,
      )
      end

      def operable? : Bool
        failure.nil?
      end
    end
  end
end
