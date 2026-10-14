module Jedi
  module TradingLife
    class OperationFeesUpdater
      def initialize(@conn_db : DB::Connection)
      end

      def call(*, operation_id : PkId, amount : Float64) : Int64
        unless operation_id > 0
          raise LowLevelError.new(
            key: "operation.fees.invalid_id",
            context: {:id => operation_id.to_s},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        # Match operation creation: amounts are stored as rounded integer cents.
        # Check the storage range before converting, including non-finite values.
        cents = (amount * 100).round
        unless amount.finite? && amount >= 0 &&
               cents.finite? && 0 <= cents <= Int32::MAX
          raise LowLevelError.new(
            key: "operation.fees.invalid_amount",
            context: {:amount => amount.to_s},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        fees = cents.to_i
        rows_affected = OperationsRepository.new(@conn_db).update_fees!(operation_id, fees)
        ref = Core::Utils.ref(operation_id)
        if rows_affected == 0
          raise LowLevelError.new(
            key: "operation.query_failed",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        App.info(key: "operation.fees.success", params: {
          :ref    => ref,
          :amount => "%.2f" % (fees / 100.0),
        })
        rows_affected
      end
    end
  end
end
