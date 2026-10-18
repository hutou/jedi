module Jedi
  module TradingRules
    class ScaleUpdater
      private getter scale
      private getter ref = ""

      def initialize(@scale : Scale)
      end

      def call(*,
               name : String? = nil,
               comment : String? = nil,
               builder : String? = nil,
               option_force : Bool = false) : Int64
        @ref = Core::Utils.ref(scale.ident.is_a?(PkId) ? scale.id : scale.name)
        new_comment =
          if comment.nil?
            scale.comment
          else
            Core::Input.ensure_present!(comment, field: "comment")
          end
        new_builder =
          if builder.nil?
            scale.operational.builder
          else
            Core::Input.ensure_present!(builder, field: "builder")
          end

        new_operational = decode_builder!(new_builder, builder)
        new_name = name.nil? ? scale.name : ScaleNaming.validate!(name, new_operational)
        rename_for_type = name.nil? && !builder.nil? &&
                          new_operational.type != scale.operational.type &&
                          ScaleNaming.automatic?(scale.name)

        if unchanged?(new_name, new_comment, new_operational)
          App.info(key: "scale.update.unchanged", params: {:ref => ref})
          return 0_i64
        end

        persist!(new_name, new_comment, new_operational, rename_for_type, option_force)
      end

      private def decode_builder!(
        definition : String,
        supplied_builder : String?,
      ) : Scale::Operational
        # Scale::Decoder.new(definition).decode
        builder = supplied_builder || definition
        begin
          scale = Scale::Decoder.new(builder).decode
        rescue ex : LowLevelError
          if supplied_builder
            raise LowLevelError.new(
              key: "scale.update.builder_syntax_error",
              context: {:builder => builder},
              kind: LowLevelError::Kind::UserInput,
              log_context: {
                :source => Core::Utils.source(__FILE__, __LINE__),
              },
              cause: ex
            )
          end

          raise LowLevelError.new(
            key: "scale.update.invalid_stored_builder",
            context: {:builder => builder},
            kind: LowLevelError::Kind::InvalidData,
            log_context: {
              :source => Core::Utils.source(__FILE__, __LINE__),
            },
            cause: ex
          )
        end
      end

      private def unchanged?(name : String, comment : String, operational : Scale::Operational) : Bool
        name == scale.name &&
          comment == scale.comment &&
          operational == scale.operational
      end

      private def ensure_operational_change_allowed!(operational : Scale::Operational, force : Bool) : Nil
        return if operational == scale.operational
        return unless ScaleUsage.new(scale).used?
        return if force
        raise LowLevelError.new(
          key: "scale.update.in_use",
          context: {:ref => ref},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def persist!(name : String, comment : String, operational : Scale::Operational,
                           rename_for_type : Bool, force : Bool) : Int64
        scale_id = scale.id
        result = scale.conn_db.transaction do |transaction|
          connection = transaction.connection
          unless operational.same_definition?(scale.operational)
            ScaleRepository.new(connection).ensure_definition_available!(operational, scale_id)
          end
          name = ScaleNaming.next_name(connection, operational) if rename_for_type
          if name != scale.name && ScaleNaming.name_in_use?(connection, name, scale_id)
            raise LowLevelError.new(
              key: "scale.update.name_already_used",
              context: {:ref => Core::Utils.ref(name)},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
          ensure_operational_change_allowed!(operational, force)
          connection.exec(
            "UPDATE scale SET name = ?, comment = ?, operational = ? WHERE id = ?",
            name, comment, operational.to_json, scale_id).rows_affected
        end
        unless result
          raise LowLevelError.new(
            "Scale update transaction was rolled back",
            kind: LowLevelError::Kind::Technical,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        scale.reload!(scale_id)
        App.info(key: "scale.update.success", params: {:ref => Core::Utils.ref(name)})
        result
      end
    end
  end
end
