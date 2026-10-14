module Jedi
  module TradingRules
    class ScaleCreator
      getter ref = ""

      def initialize(@transaction_source : DB::Connection | DB::Transaction)
      end

      def call(*, comment : String, builder : String, name : String? = nil, announce : Bool = true) : PkId
        operational = decode_builder!(builder)
        explicit_name = name.try { |value| ScaleNaming.validate!(value, operational) }
        persist!(explicit_name, comment, operational, announce, restoring: false)
      end

      # Backup replay preserves historical names and pre-existing duplicates.
      # This path is deliberately separate from normal creation.
      def restore(*, name : String, comment : String, builder : String, announce : Bool = true) : PkId
        persist!(name, comment, decode_builder!(builder), announce, restoring: true)
      end

      private def persist!(name : String?, comment : String, operational : Scale::Operational,
                           announce : Bool, *, restoring : Bool) : PkId
        chosen_name = ""
        scale_id = @transaction_source.transaction do |transaction|
          connection = transaction.connection
          repository = ScaleRepository.new(connection)
          repository.ensure_definition_available!(operational) unless restoring
          chosen_name = name || ScaleNaming.next_name(connection, operational)
          ensure_name_available!(chosen_name, connection, restoring)
          repository.insert!(ScaleState.new(
            name: chosen_name, comment: comment, opscale: operational))
        end
        unless scale_id
          raise LowLevelError.new(
            "Scale persistence transaction was rolled back",
            kind: LowLevelError::Kind::Technical,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        @ref = Core::Utils.ref(chosen_name)
        if announce
          App.info(
            key: "scale.create.success",
            params: {:ref => ref})
        end
        # params: {:name => name, :id => "#{scale_id}"})
        scale_id
      end

      private def ensure_name_available!(name : String, connection : DB::Connection, restoring : Bool) : Nil
        unless restoring
          return unless ScaleNaming.name_in_use?(connection, name)
          raise LowLevelError.new(
            key: "scale.create.name_exists",
            context: {:ref => Core::Utils.ref(name)},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        exists = connection.scalar(
          "SELECT EXISTS(SELECT 1 FROM scale WHERE name = ?)",
          name).as(PkId)
        return if exists.zero?
        raise LowLevelError.new(
          key: "scale.create.name_exists",
          context: {:ref => Core::Utils.ref(name)},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def decode_builder!(builder : String) : Scale::Operational
        Scale::Decoder.new(builder).decode
      rescue ex : LowLevelError
        raise LowLevelError.new(
          key: "scale.create.invalid_builder",
          kind: LowLevelError::Kind::UserInput,
          context: {:builder => builder},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          cause: ex
        )
      end
    end
  end
end
