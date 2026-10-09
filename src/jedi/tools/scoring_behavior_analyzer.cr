module Jedi
  module Tools
    struct ScoringCoverage
      getter known : Bool
      getter positive_available : Int32
      getter negative_available : Int32
      getter positive_reached : Int32
      getter negative_reached : Int32
      getter unused_positive : Int32
      getter unused_negative : Int32

      def initialize(
        @positive_available : Int32,
        @negative_available : Int32,
        @positive_reached : Int32,
        @negative_reached : Int32,
        @known : Bool = true,
      )
        @unused_positive = positive_available - positive_reached
        @unused_positive = 0 if @unused_positive < 0
        @unused_negative = negative_available - negative_reached
        @unused_negative = 0 if @unused_negative < 0
      end

      def self.unknown : ScoringCoverage
        new(0, 0, 0, 0, false)
      end

      def total_unused : Int32
        unused_positive + unused_negative
      end

      def maximum_unused : Int32
        unused_positive > unused_negative ? unused_positive : unused_negative
      end

      def significant?(maximum_unused_per_side : Int32) : Bool
        return true unless known

        unused_positive <= maximum_unused_per_side &&
          unused_negative <= maximum_unused_per_side
      end

      def margin_distance(target_margin : Int32) : Int32
        return 0 unless known

        (unused_positive - target_margin).abs +
          (unused_negative - target_margin).abs
      end
    end

    record ScoringBehavior,
      coverage : ScoringCoverage,
      signature : String

    # Extracts the effective coverage and a stable behavioral signature from a
    # completed backtest. Coverage is based on positions actually recorded by
    # operations; merely defining an outer step is not considered evidence that
    # the history exercised it.
    class ScoringBehaviorAnalyzer
      def self.analyze(result : BacktestResult) : ScoringBehavior
        operational = result.scale.operational
        positions = [] of TradingRules::Position

        signature_source = String.build do |io|
          result.operations.each do |operation|
            position = operation.position
            positions << position

            io << operation.timestamp.to_unix << '|'
            io << operation.type.to_s << '|'
            io << operation.mode.to_s << '|'
            io << operation.quantity << '|'
            io << operation.price << '|'
            io << operation.buy << '|'
            io << operation.sell << '|'
            io << operation.global_invest << '|'
            io << operation.fees << '|'
            io << operation.stock << '|'
            io << position.to_s << '|'
            io << operation.ksp << '|'
            io << operation.kcp << '\n'
          end
        end

        ScoringBehavior.new(
          coverage: coverage(
            operational.emax,
            operational.emin,
            positions,
          ),
          signature: Digest::SHA256.hexdigest(signature_source),
        )
      end

      def self.coverage(
        emax : Int32,
        emin : Int32,
        positions : Enumerable(TradingRules::Position),
      ) : ScoringCoverage
        positive_available = emax > 0 ? emax : 0
        negative_available = emin < 0 ? emin.abs : 0
        positive_reached = 0
        negative_reached = 0

        positions.each do |position|
          x, y, e = position.coords

          if x > 0
            positive_reached = positive_available
          elsif e > positive_reached
            positive_reached = e
          end

          if y > 0
            negative_reached = negative_available
          elsif e < 0 && e.abs > negative_reached
            negative_reached = e.abs
          end
        end

        positive_reached = positive_available if positive_reached > positive_available
        negative_reached = negative_available if negative_reached > negative_available

        ScoringCoverage.new(
          positive_available,
          negative_available,
          positive_reached,
          negative_reached,
        )
      end
    end
  end
end
