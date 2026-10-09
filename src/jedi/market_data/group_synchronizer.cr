module Jedi
  module MarketData
    # Replaces one named market group's membership from a simple file
    # containing one ISIN or ticker at the beginning of each line. Text after
    # whitespace, ';' or ':' is ignored. Blank lines and comments are ignored.
    class GroupSynchronizer
      GROUP_CODE_REGEX = /\A[A-Za-z][A-Za-z0-9_-]*\z/

      def self.normalize_group_code!(value : String?) : String
        code = value.to_s.upcase
        return code if code.matches?(GROUP_CODE_REGEX)

        raise LowLevelError.new(
          "invalid market group code '#{value}'",
          key: "market.invalid_group",
          context: {:group => value.to_s},
          kind: LowLevelError::Kind::UserInput,
          log_context: {
            :error_code => "invalid_group_code",
            :group_code => value.to_s,
          }
        )
      end

      getter database : Database
      getter group_code : String
      getter filename : String
      getter reference_source : String
      getter as_of : Time?

      def initialize(
        @database : Database,
        group_code : String,
        @filename : String,
        reference_source : String? = nil,
        @as_of : Time? = nil,
      )
        @group_code = self.class.normalize_group_code!(group_code)
        @reference_source = reference_source || database.source
      end

      def run : ImportReport
        references, rows_read = read_references
        report = ImportReport.new(ImportOperation::SyncGroup, database.filename)
        report.market_source = database.source
        report.market_universe = database.universe
        report.source_filename = filename
        report.group_code = group_code
        report.group_rows_read = rows_read
        report.group_references_read = references.size.to_i64

        database.with_connection do |conn|
          synchronize(conn, references, report)
        end

        report
      rescue ex : LowLevelError
        enrich_error!(ex)
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot synchronize market group '#{group_code}' from " \
          "'#{filename}': #{ex.message || ex.class.name}",
          log_context: sync_context,
          cause: ex
        )
      end

      private def read_references : Tuple(Array(String), Int64)
        references = [] of String
        rows_read = 0_i64

        File.each_line(filename) do |line|
          rows_read += 1
          value = line.strip
          next if value.empty? || value.starts_with?('#')

          reference = value.split(/[;:\s]/, 2).first
          references << reference unless references.includes?(reference)
        end

        if references.empty?
          raise LowLevelError.new(
            "market group reference file contains no security: #{filename}",
            log_context: {
              :error_code => "empty_group_file",
              :filename   => filename,
              :group_code => group_code,
            }
          )
        end

        {references, rows_read}
      end

      private def synchronize(
        conn : DB::Connection,
        references : Array(String),
        report : ImportReport,
      ) : Nil
        security_repository = SecurityRepository.new(conn)
        group_repository = GroupRepository.new(conn)
        matched = {} of String => SecurityInfo

        references.each do |reference|
          if security = security_repository.find_by_isin_or_ticker(reference)
            matched[security.isin] = security
          else
            report.unknown_isins << reference
          end
        end

        if matched.empty?
          raise LowLevelError.new(
            "no security from market group '#{group_code}' matches the " \
            "market database",
            log_context: {
              :error_code      => "no_group_match",
              :group_code      => group_code,
              :reference_count => references.size.to_s,
            }
          )
        end

        existing = if group = group_repository.find(group_code)
                     group_repository.members(group.code)
                   else
                     [] of String
                   end
        matched_isins = matched.keys.sort

        report.added_group_isins.concat(matched_isins.reject { |isin| existing.includes?(isin) })
        report.removed_group_isins.concat(existing.reject { |isin| matched.has_key?(isin) })
        report.unknown_isins.sort!
        report.added_group_isins.sort!
        report.removed_group_isins.sort!
        report.group_matched = matched.size.to_i64

        timestamp = Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")
        conn.transaction do |tx|
          tx_conn = tx.connection
          tx_groups = GroupRepository.new(tx_conn)
          canonical = tx_groups.upsert(
            group_code,
            reference_source,
            as_of,
            timestamp,
          )
          tx_groups.replace_members(canonical, matched_isins)
          Schema.set_metadata(tx_conn, "updated_at", timestamp)
          report.group_code = canonical
        end

        unless report.unknown_isins.empty?
          report.add_warning(
            "#{report.unknown_isins.size} references from market group " \
            "'#{report.group_code}' are absent from the database"
          )
        end
      end

      private def sync_context : LogContext
        context = {
          :filename          => filename,
          :database_filename => database.filename,
          :market_source     => database.source,
          :market_universe   => database.universe,
          :group_code        => group_code,
          :reference_source  => reference_source,
        }
        if date = as_of
          context[:reference_date] = date.to_s("%F")
        end
        context
      end

      private def enrich_error!(ex : LowLevelError) : Nil
        sync_context.each do |key, value|
          ex.log_context[key] = value unless ex.log_context.has_key?(key)
        end
      end
    end
  end
end
