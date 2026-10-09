module Jedi
  module Tools
    # One scale generated from a score search-space definition.
    #
    # search_builder preserves the parameter combination which generated the
    # canonical scale. It is deliberately kept apart from scalebuild, because
    # the latter may contain optimized coefficients rather than the original
    # search parameters.
    struct ScoringCandidate
      getter scaledef : String
      getter scalebuild : String
      getter search_builder : String
      getter features : Hash(String, Float64)
      getter complexity : Float64
      getter family : ScoringSearchFamily
      getter scale_type : Int32

      def initialize(
        @scaledef : String,
        @scalebuild : String,
        @search_builder : String,
        extra_features : Hash(String, Float64) = {} of String => Float64,
        @family : ScoringSearchFamily = ScoringSearchFamily::Custom,
        @scale_type : Int32 = 0,
      )
        @features = self.class.extract_features(search_builder)
        extra_features.each do |key, value|
          @features[key] = value
        end
        @complexity = self.class.structural_complexity(scalebuild)
      end

      def key : String
        scaledef
      end

      def typed_builder : String
        prefix = case scale_type
                 when 1
                   "I"
                 when 2
                   "II"
                 else
                   "?"
                 end
        "#{prefix}: #{scalebuild}"
      end

      def self.extract_features(builder_source : String) : Hash(String, Float64)
        features = {} of String => Float64
        vars = TradingRules::Scale::Builder.new(builder_source).vars

        vars.each do |key, value|
          case value
          in Float64
            features[key] = value
          in Int32
            features[key] = value.to_f
          in Array(Float64)
            append_array_features(features, key, value)
          in Array(Int32)
            append_array_features(features, key, value.map(&.to_f))
          end
        end

        features
      end

      def self.append_array_features(
        features : Hash(String, Float64),
        key : String,
        values : Array(Float64),
      ) : Nil
        return if values.empty?

        minimum = values.first
        maximum = values.first
        sum = 0.0
        values.each do |value|
          minimum = value if value < minimum
          maximum = value if value > maximum
          sum += value
        end

        features["#{key}.count"] = values.size.to_f
        features["#{key}.minimum"] = minimum
        features["#{key}.maximum"] = maximum
        features["#{key}.mean"] = sum / values.size.to_f
        features["#{key}.spread"] = maximum - minimum

        return unless key == "kc"

        up = values.select { |value| value > 1.0 }
        down = values.select { |value| value < 1.0 }
        features["kc.up_count"] = up.size.to_f
        features["kc.down_count"] = down.size.to_f
        features["kc.up_mean"] = mean_or_zero(up)
        features["kc.down_mean"] = mean_or_zero(down)
      end

      def self.mean_or_zero(values : Array(Float64)) : Float64
        return 0.0 if values.empty?

        sum = 0.0
        values.each { |value| sum += value }
        sum / values.size.to_f
      end

      def self.structural_complexity(builder_source : String) : Float64
        vars = TradingRules::Scale::Builder.new(builder_source).vars
        coefficient_count = 0
        irregularity = 0.0

        vars.each do |key, value|
          case value
          in Array(Float64)
            coefficient_count += value.size
            if key == "kc" || key == "ks"
              irregularity += consecutive_irregularity(value)
            end
          in Array(Int32)
            coefficient_count += value.size
          in Float64
            coefficient_count += 1 unless key == "kd"
          in Int32
            coefficient_count += 1 unless key == "kb"
          end
        end

        coefficient_count.to_f + irregularity
      end

      def self.consecutive_irregularity(values : Array(Float64)) : Float64
        return 0.0 if values.size < 3

        differences = [] of Float64
        index = 1
        while index < values.size
          differences << (values[index] - values[index - 1]).abs
          index += 1
        end

        average = mean_or_zero(differences)
        return 0.0 if average <= 0.0

        deviation = 0.0
        differences.each { |value| deviation += (value - average).abs }
        deviation / differences.size.to_f / average
      end
    end
  end
end
