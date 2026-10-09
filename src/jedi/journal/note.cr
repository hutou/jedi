module Jedi
  module Journal
    class Note
      private alias Fields = NamedTuple(id: PkId, date: Time,
        summary: String, contents: String)

      @record : Fields? = nil

      protected getter conn_db : DB::Connection
      getter ref = ""

      def initialize(@conn_db : DB::Connection, @ident : PkId)
      end

      def id : PkId
        record[:id]
      end

      def date : Time
        record[:date].to_local
      end

      def summary : String
        record[:summary]
      end

      def contents : String
        record[:contents]
      end

      def record : Fields
        if cached = @record
          return cached
        end
        sql = "SELECT * FROM note WHERE id=?"
        begin
          @record = @conn_db.query_one(sql, @ident, as: Fields.types)
        rescue ex # no LowLevelError here, just <DB::NoResultsError:no results>
          @ref = Core::Utils.ref(@ident)
          raise LowLevelError.new(
            key: "note.query_failed",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end

      def reload!(id : PkId) : Nil
        @record = nil
      end
    end
  end
end
