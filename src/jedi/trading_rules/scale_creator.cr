module Jedi
  module TradingRules
    class ScaleCreator
      getter ref = ""

      def initialize(@conn_db : DB::Connection)
        @repo = ScaleRepository.new(@conn_db)
      end

      def call(*, name : String, comment : String, builder : String, announce : Bool = true) : PkId
        @ref = Core::Utils.ref(name)
        ensure_name_available!(name)
        operational = decode_builder!(builder)
        state = ScaleState.new(
          name: name,
          comment: comment,
          opscale: operational)

        scale_id = @repo.insert!(state)
        if announce
          App.info(
            key: "scale.create.success",
            params: {:ref => ref})
        end
        # params: {:name => name, :id => "#{scale_id}"})
        scale_id
      end

      private def ensure_name_available!(name : String) : Nil
        exists = @conn_db.scalar(
          "SELECT EXISTS(SELECT 1 FROM scale WHERE name = ?)",
          name).as(PkId)
        return if exists.zero?
        raise LowLevelError.new(
          key: "scale.create.name_exists",
          context: {:ref => ref},
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
