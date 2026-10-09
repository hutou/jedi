module Jedi
  module Tools
    enum ProfileCollectionSort
      Global
      Ticker
      Trend
      Liquidity
      Volatility
      Oscillation
      Drawdown
      Gap
      Step

      def self.parse(value : String?) : self
        case value.try(&.downcase)
        when nil, "", "global"
          Global
        when "ticker"
          Ticker
        when "trend"
          Trend
        when "liquidity"
          Liquidity
        when "volatility"
          Volatility
        when "oscillation"
          Oscillation
        when "drawdown"
          Drawdown
        when "gap", "gaps"
          Gap
        when "step"
          Step
        else
          raise LowLevelError.new(
            "invalid profile sort key '#{value}'",
            key: "tools.profile.collection.invalid_sort",
            kind: LowLevelError::Kind::UserInput,
            context: {:value => value.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
      end
    end

    struct ProfileCollectionSelection
      getter source : String
      getter universe : String
      getter dataset : String?
      getter securities : Array(String)
      getter group : String?

      def initialize(
        @source : String,
        @universe : String,
        @dataset : String? = nil,
        @securities : Array(String) = [] of String,
        group : String? = nil,
      )
        @group = group.try(&.upcase)
      end

      def database_name : String
        "#{source}_#{universe}"
      end
    end

    struct ProfileCollectionItem
      getter security : MarketData::SecurityInfo
      getter profile : JediProfile

      def initialize(
        @security : MarketData::SecurityInfo,
        @profile : JediProfile,
      )
      end
    end

    struct ProfileCollectionFailure
      getter security : MarketData::SecurityInfo
      getter message : String

      def initialize(
        @security : MarketData::SecurityInfo,
        @message : String,
      )
      end
    end

    class ProfileCollectionResult
      getter selection : ProfileCollectionSelection
      getter selected_count : Int32
      getter items : Array(ProfileCollectionItem)
      getter failures : Array(ProfileCollectionFailure)

      def initialize(
        @selection : ProfileCollectionSelection,
        @selected_count : Int32,
        @items : Array(ProfileCollectionItem),
        @failures : Array(ProfileCollectionFailure),
      )
      end

      def analyzed_count : Int32
        items.size
      end

      def rejected_count : Int32
        items.count { |item| item.profile.rejected? }
      end

      def retained_count : Int32
        analyzed_count - rejected_count
      end
    end
  end
end
