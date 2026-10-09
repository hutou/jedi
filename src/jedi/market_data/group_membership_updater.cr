module Jedi
  module MarketData
    struct GroupMembershipUpdate
      getter security : SecurityInfo
      getter group : MarketGroupInfo
      getter member : Bool
      getter changed : Bool

      def initialize(
        @security : SecurityInfo,
        @group : MarketGroupInfo,
        @member : Bool,
        @changed : Bool,
      )
      end
    end

    class GroupMembershipUpdater
      getter database : Database
      getter group_code : String
      getter isin : String
      getter member : Bool

      def initialize(
        @database : Database,
        group_code : String,
        @isin : String,
        @member : Bool,
      )
        @group_code = GroupSynchronizer.normalize_group_code!(group_code)
      end

      def run : GroupMembershipUpdate
        result = nil.as(GroupMembershipUpdate?)

        database.with_connection do |conn|
          security = SecurityRepository.new(conn).fetch!(isin)
          group = GroupRepository.new(conn).fetch!(group_code)
          changed = false

          conn.transaction do |tx|
            tx_conn = tx.connection
            repository = GroupRepository.new(tx_conn)
            changed = if member
                        repository.add_member(group.code, isin)
                      else
                        repository.remove_member(group.code, isin)
                      end
            Schema.set_metadata(
              tx_conn,
              "updated_at",
              Time.utc.to_s("%Y-%m-%dT%H:%M:%SZ")
            )
          end

          result = GroupMembershipUpdate.new(
            security,
            group,
            member,
            changed,
          )
        end

        result || raise LowLevelError.new(
          "cannot update membership of '#{isin}' in market group " \
          "'#{group_code}'"
        )
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot update membership of '#{isin}' in market group " \
          "'#{group_code}': #{ex.message || ex.class.name}",
          log_context: {
            :isin       => isin,
            :group_code => group_code,
            :member     => member.to_s,
          },
          cause: ex
        )
      end
    end
  end
end
