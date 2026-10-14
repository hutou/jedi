module Jedi
  module TradingRules
    class ScaleRepository
      def initialize(@conn_db : DB::Connection)
      end

      def find_equivalent(operational : Scale::Operational, excluding_id : PkId? = nil) : Scale?
        Scales.new(@conn_db).fetch.find do |scale|
          scale.id != excluding_id && operational.same_definition?(scale.operational)
        end
      end

      def ensure_definition_available!(operational : Scale::Operational, excluding_id : PkId? = nil) : Nil
        if existing = find_equivalent(operational, excluding_id)
          raise LowLevelError.new(
            key: "scale.definition_exists",
            context: {:ref => Core::Utils.ref(existing.name), :id => existing.id.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end

      def insert!(state : ScaleState) : PkId
        exec_result = @conn_db.exec "INSERT INTO scale (name, comment, " +
                                    "operational) VALUES(?, ?, ?)",
          state.name.downcase.capitalize,
          state.comment,
          state.opscale.to_json
        exec_result.last_insert_id
      end
    end
  end
end
