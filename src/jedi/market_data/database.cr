module Jedi
  module MarketData
    class Database
      IDENT_PATTERN = /\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/

      getter source : String
      getter universe : String
      getter filename : String

      def initialize(
        @source : String,
        @universe : String,
      )
        validate_ident!(source, "source")
        validate_ident!(universe, "universe")
        @filename = App.market_db_file(source, universe)
      end

      def exists? : Bool
        File.file?(filename)
      rescue ex
        raise LowLevelError.new(
          "cannot inspect market database '#{filename}': " \
          "#{ex.message || ex.class.name}",
          log_context: database_context,
          cause: ex
        )
      end

      def create! : Nil
        if exists?
          context = database_context
          context[:error_code] = "database_exists"

          raise LowLevelError.new(
            "market database already exists: #{filename}",
            log_context: context
          )
        end

        begin
          Dir.mkdir_p(File.dirname(filename))

          DB.open(uri) do |db|
            db.using_connection do |conn|
              Schema.create(conn)
              timestamp = Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")
              Schema.set_metadata(conn, "source", source)
              Schema.set_metadata(conn, "universe", universe)
              Schema.set_metadata(conn, "created_at", timestamp)
              Schema.set_metadata(conn, "updated_at", timestamp)
            end
          end
        rescue ex : LowLevelError
          cleanup_database_files
          enrich_error!(ex, database_context)
          raise ex
        rescue ex
          cleanup_database_files
          raise LowLevelError.new(
            "cannot create market database '#{filename}': " \
            "#{ex.message || ex.class.name}",
            log_context: database_context,
            cause: ex
          )
        end
      end

      def with_connection(& : DB::Connection ->) : Nil
        unless exists?
          raise LowLevelError.new(
            "market database not found: #{filename}",
            log_context: database_context
          )
        end

        DB.open(uri) do |db|
          db.using_connection do |conn|
            conn.exec("PRAGMA foreign_keys = ON")
            Schema.validate!(conn)
            yield conn
          end
        end
      rescue ex : LowLevelError
        enrich_error!(ex, database_context)
        raise ex
      rescue ex : DB::Error
        raise LowLevelError.new(
          "market database operation failed for '#{filename}': " \
          "#{ex.message || ex.class.name}",
          log_context: database_context,
          cause: ex
        )
      rescue ex : IO::Error
        raise LowLevelError.new(
          "cannot access market database '#{filename}': " \
          "#{ex.message || ex.class.name}",
          log_context: database_context,
          cause: ex
        )
      end

      private def uri : String
        "sqlite3:#{filename}"
      end

      private def validate_ident!(value : String, name : String) : Nil
        return if value.matches?(IDENT_PATTERN)

        raise LowLevelError.new(
          "invalid market #{name} '#{value}'",
          log_context: {
            :field => name,
            :value => value,
          }
        )
      end

      private def database_context : Hash(Symbol, String)
        {
          :filename        => filename,
          :market_source   => source,
          :market_universe => universe,
        }
      end

      private def enrich_error!(
        ex : LowLevelError,
        context : Hash(Symbol, String),
      ) : Nil
        context.each do |key, value|
          ex.log_context[key] = value unless ex.log_context.has_key?(key)
        end
      end

      private def cleanup_database_files : Nil
        {filename, "#{filename}-wal", "#{filename}-shm"}.each do |path|
          begin
            File.delete(path) if File.exists?(path)
          rescue
          end
        end
      end
    end
  end
end
