module Jedi
  module TradingRules
    module ScaleNaming
      extend self

      def prefix(operational : Scale::Operational) : String
        operational.type.one? ? "B_kc" : "B_vr"
      end

      def validate!(name : String, operational : Scale::Operational) : String
        normalized = name.strip.capitalize
        family = prefix(operational)
        match = normalized.match(/\A#{family}_(\d{2,})\z/)
        number = match.try { |value| value[1].to_i64? }
        unless number && number > 0
          raise LowLevelError.new(
            key: "scale.name_type_mismatch",
            context: {:name => name, :prefix => family},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        "#{family}_#{number.to_s.rjust(2, '0')}"
      end

      def automatic?(name : String) : Bool
        !!(name =~ /\AB_(kc|vr)_\d+\z/i)
      end

      def name_in_use?(conn : DB::Connection, name : String, excluding_id : PkId? = nil) : Bool
        wanted = normalized_numbered_name(name)
        conn.query_all("SELECT id, name FROM scale", as: {PkId, String}).any? do |(id, stored)|
          id != excluding_id &&
            (stored.downcase == name.downcase ||
              (wanted && normalized_numbered_name(stored) == wanted))
        end
      end

      private def normalized_numbered_name(name : String) : String?
        if match = name.match(/\AB_(kc|vr)_(\d+)\z/i)
          if number = match[2].to_i64?
            return "B_#{match[1].downcase}_#{number.to_s.rjust(2, '0')}" if number > 0
          end
        end
      end

      def next_name(conn : DB::Connection, operational : Scale::Operational) : String
        family = prefix(operational)
        maximum = 0_i64
        conn.query_all("SELECT name FROM scale", as: String).each do |name|
          if match = name.match(/\A#{family}_(\d+)\z/i)
            if number = match[1].to_i64?
              maximum = [maximum, number].max
            end
          end
        end
        if maximum == Int64::MAX
          raise LowLevelError.new(
            key: "scale.name_number_exhausted",
            context: {:prefix => family},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        "#{family}_#{(maximum + 1).to_s.rjust(2, '0')}"
      end
    end
  end
end
