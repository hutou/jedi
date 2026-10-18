module Jedi
  module TradingSystem
    class Trade
      enum LifecycleStatus
        Created
        Configured
        Opened
        Running
        Closed
      end

      #  Name and type of fields read from the trade table
      alias Fields = NamedTuple(id: PkId, name: String,
        money: String?, stop: String?, security_id: PkId)
      @record : Fields? = nil

      protected getter conn_db : DB::Connection
      getter ident
      private getter ref

      def initialize(@conn_db : DB::Connection, @ident : PkId | String)
        @ref = Core::Utils.ref(@ident)
      end

      def id : PkId
        record[:id]
      end

      def name : String
        record[:name]
      end

      # read money, raise if error
      def money : TradingSystem::Money?
        TradingSystem::Money.parse(record[:money])
      rescue ex : LowLevelError
        raise LowLevelError.new(
          key: "trade.invalid_stored_money",
          context: {:trade => "#{id}-#{name}", :money => record[:money].to_s},
          kind: LowLevelError::Kind::InvalidData,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          cause: ex)
      end

      def stop : TradeStop?
        TradeStop.parse(record[:stop])
      rescue ex : LowLevelError
        raise LowLevelError.new(
          key: "trade.invalid_stored_stop",
          context: {:trade => "#{id}-#{name}", :stop => record[:stop].to_s},
          kind: LowLevelError::Kind::InvalidData,
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          cause: ex)
      end

      def security_id : PkId
        record[:security_id]
      end

      def record : Fields
        if cached = @record
          return cached
        end

        key = @ident.is_a?(PkId) ? "id" : "name"

        sql = <<-SQL
          SELECT id, name, money, stop, security_id
          FROM trade
          WHERE #{key} = ?
          SQL

        begin
          @record = @conn_db.query_one(sql, @ident, as: Fields.types)
        rescue ex # no LowLevelError here, just <DB::NoResultsError:no results>
          # no message as first argument to LowLevelError
          # => kind = domain, no help
          # else
          # => kind = unclassified
          # If kind set to UserInput
          # => idem as domain + Help
          raise LowLevelError.new(
            key: "trade.query_failed",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            cause: ex)
        end
      end

      def security
        Exchange::Security.new(@conn_db, security_id)
      end

      def settings_chain
        q = TradingSystem::TradeContextQueries.new(@conn_db)
        TradingSystem::SettingsChain.new(@conn_db).fetch(q.settings_sql, id)
      end

      def last_settings : TradingSystem::Settings?
        q = TradingSystem::TradeContextQueries.new(@conn_db)
        sg_id = q.last_settings_id(id)
        sg_id.nil? ? nil : TradingSystem::Settings.new(@conn_db, sg_id)
      end

      def operations
        q = TradingSystem::TradeContextQueries.new(@conn_db)
        TradingLife::Operations.new(@conn_db).fetch(q.operations_sql, id)
      end

      def last_operation : TradingLife::Operation?
        q = TradingSystem::TradeContextQueries.new(@conn_db)
        op_id = q.last_operation_id(id)
        op_id.nil? ? nil : TradingLife::Operation.new(@conn_db, op_id)
      end

      def lifecycle_status : LifecycleStatus
        if operation = last_operation
          return LifecycleStatus::Closed if operation.stock.zero?

          q = TradingSystem::TradeContextQueries.new(@conn_db)
          q.operations_count(id) > 1 ? LifecycleStatus::Running : LifecycleStatus::Opened
        else
          last_settings.nil? ? LifecycleStatus::Created : LifecycleStatus::Configured
        end
      end

      def reload!(id : PkId) : Nil
        @ident = id
        @record = nil
      end

      def stop_clear
        stop_update(nil)
      end

      def stop_update(stop : TradeStop?)
        stop = stop.nil? ? nil : stop.to_s
        exec_result = @conn_db.exec "UPDATE trade SET stop = ? WHERE id = ?",
          stop, id
        @record = nil # Force reading DB if record or record's field(s) accessed
        exec_result.rows_affected
      end
    end
  end
end
