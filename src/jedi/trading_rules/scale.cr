module Jedi
  module TradingRules
    # Persistence-backed representation of a scale.
    #
    # Its own responsibility is deliberately limited to loading the stored
    # record and exposing its fields. Application operations and presentation
    # are delegated to dedicated objects.
    class Scale
      enum Status
        NotUsed = 0
        Used    = 1
        InUse   = 2

        def label : String
          case self
          in .not_used?
            I18n.t("scale.status.not_used")
          in .used?
            I18n.t("scale.status.used")
          in .in_use?
            I18n.t("scale.status.in_use")
          end
        end
      end

      alias Fields = NamedTuple(
        id: PkId,
        name: String,
        comment: String,
        operational: String)

      @record : Fields? = nil

      getter conn_db : DB::Connection
      getter ident : PkId | String
      private getter ref = ""

      def initialize(@conn_db : DB::Connection, @ident : PkId | String)
      end

      # Compatibility constructor used to display a literal builder without
      # storing it first.
      def initialize(name : String, comment : String, operational : String)
        @conn_db = App.conn_main
        @ident = 0_i64
        @record = {
          id:          -1_i64,
          name:        name,
          comment:     comment,
          operational: operational,
        }
      end

      def id : PkId
        record[:id]
      end

      def name : String
        record[:name]
      end

      def comment : String
        record[:comment]
      end

      def operational : Operational
        Operational.from_json(record[:operational])
      end

      def record : Fields
        if cached = @record
          return cached
        end

        key = ident.is_a?(PkId) ? "id" : "name"

        sql = <<-SQL
          SELECT id, name, comment, operational
          FROM scale
          WHERE #{key} = ?
          SQL

        begin
          @record = conn_db.query_one(sql, ident, as: Fields.types)
        rescue ex
          @ref = Core::Utils.ref(@ident)
          raise LowLevelError.new(
            key: "scale.query_failed",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            cause: ex)
        end
      end

      # Invalidates the lazy-loaded record after a persistence operation.
      def reload! : Nil
        @record = nil unless literal?
      end

      # Reloads by primary key after an update. This also keeps a Scale that
      # was originally loaded by name usable when that name has changed.
      def reload!(id : PkId) : Nil
        @ident = id
        @record = nil
      end

      def literal? : Bool
        id == -1_i64
      end
    end
  end
end
