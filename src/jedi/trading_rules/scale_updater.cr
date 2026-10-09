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
        new_name =
          if name.nil?
            scale.name
          else
            Core::Input.ensure_string_valid!(name, field: "name",
              regex: ALPHANUM, key: "infra.field_required").capitalize
          end
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

        if unchanged?(new_name, new_comment, new_operational)
          App.info(key: "scale.update.unchanged", params: {:ref => ref})
          return 0_i64
        end

        if new_name != scale.name && key_exists(new_name)
          # name is a key, so we must ensure it is not used elsewhere
          @ref = Core::Utils.ref(new_name)
          raise LowLevelError.new(
            key: "scale.update.name_already_used",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        ensure_operational_change_allowed!(new_operational, option_force)
        persist!(new_name, new_comment, new_operational)
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

      private def key_exists(name)
        count = scale.conn_db.scalar(
          "SELECT count(*) FROM scale WHERE name = ?",
          name).as(PkId)
        !count.zero?
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

      private def persist!(name : String, comment : String, operational : Scale::Operational) : Int64
        scale_id = scale.id
        result = scale.conn_db.exec(
          "UPDATE scale SET name = ?, comment = ?, operational = ? WHERE id = ?",
          name,
          comment,
          operational.to_json,
          scale_id)

        scale.reload!(scale_id)
        App.info(key: "scale.update.success", params: {:ref => ref})
        result.rows_affected
      end
    end
  end
end
