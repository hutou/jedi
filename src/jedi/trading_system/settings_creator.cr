module Jedi
  module TradingSystem
    class SettingsCreator
      private getter ref = ""
      private getter ref_settings = ""

      def initialize(@conn_db : DB::Connection)
        @context_loader = TradeContextLoader.new(@conn_db)
        @repo = SettingsRepository.new(@conn_db)
      end

      def call(*,
               trade_ident : String | PkId,
               scale_ident : String | PkId,
               timestamp : Time,
               option_split : Exchange::Security::Split? = nil,
               option_sync : TradingRules::Position? = nil,
               option_reinit : TradingSystem::ReInitOption? = nil) : Int64
        @ref = Core::Utils.ref(trade_ident)
        context = @context_loader.load!(trade_ident)
        unless (x = context.current_settings).nil? || !x.operations.empty?
          # Current settings not used yet, cannot create another !
          raise LowLevelError.new(
            key: "settings.create.last_settings_not_used",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        scale = TradingRules::Scale.new(@conn_db, scale_ident)

        validate_timestamp!(timestamp)
        validate_global_options!(context, option_split, option_sync, option_reinit)

        state =
          if !context.has_settings?
            build_initial_state()
          elsif !option_reinit.nil? && option_reinit.reset?
            build_reinit_reset_state(context, option_reinit, option_split)
          elsif !option_reinit.nil? && option_reinit.merge?
            build_reinit_merge_state(context, option_reinit, option_split)
          elsif !option_sync.nil?
            if scale.operational.type.one?
              build_sync_state(context, option_sync, scale)
            else
              raise LowLevelError.new(
                key: "settings.create.sync_type_one_only",
                log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
            end
          elsif !option_split.nil?
            build_split_state(context, option_split, scale)
          else
            build_standard_state(context, scale)
          end

        id = @repo.insert!(timestamp, state, context.trade.id, scale.id)
        @ref_settings = Core::Utils.ref(id)
        App.info(key: "settings.create.success",
          params: {:ref_settings => ref_settings, :ref => ref})
        id
      end

      private def validate_global_options!(context, option_split, option_sync, option_reinit) : Nil
        # Split and reinit may be combined; sync must remain on its own.
        if option_sync && (option_split || option_reinit)
          raise LowLevelError.new(
            key: "settings.create.zero_or_one_option_only",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        if option_sync || option_split || option_reinit
          unless context.has_settings?
            # aucune de ces 3 options n'est autorisée sans paramétrage existant
            # autrement dit : impossible de les utiliser pour un premier paramétrage
            raise LowLevelError.new(
              key: "settings.create.option_not_allowed_in_empty_settings",
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
        end
      end

      private def validate_timestamp!(timestamp : Time) : Nil
        last_operation = TradingLife::Operations.new(@conn_db)
          .fetch("SELECT id FROM operation ORDER BY timestamp DESC, id DESC LIMIT 1")
          .last?

        if !last_operation.nil? && timestamp <= last_operation.timestamp
          # new settings timestamp must be > last operation timestamp
          raise LowLevelError.new(
            key: "settings.create.datetime_operation",
            context: {:date => "#{timestamp}"},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        last_settings = SettingsChain.new(@conn_db)
          .fetch("SELECT id FROM settings ORDER BY timestamp DESC LIMIT 1")
          .last?

        if !last_settings.nil? && timestamp <= last_settings.timestamp
          # new settings timestamp must be > last settings timestamp
          raise LowLevelError.new(
            key: "settings.create.datetime_settings",
            context: {:date => "#{timestamp}"},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end

      private def build_initial_state : SettingsState
        SettingsState.new(
          rank: 1,
          split: nil,
          sync: nil,
          reinit: nil,
          q0: 0.0,
          c0: 0.0,
          position: TradingRules::Position.new("0:0:0"),
          kspc: 1.0,
          kcpc: 1.0
        )
      end

      private def build_reinit_reset_state(context : TradeContext,
                                           option_reinit : ReInitOption,
                                           option_split : Exchange::Security::Split?) : SettingsState
        current_settings = context.current_settings.not_nil!
        last_operation = context.last_operation.not_nil!

        q0, c0 = {last_operation.stock.to_f, option_reinit.c0}
        if option_split
          # The held stock is integral, as in LastData. Fractional rights are
          # not accounted for by Jedi. The supplied price is already post-split.
          q0 = option_split.quantity(last_operation.stock).to_i.to_f
        end
        SettingsState.new(
          rank: current_settings.rank + 1,
          split: option_split,
          sync: nil,
          reinit: option_reinit,
          q0: q0,
          c0: c0,
          position: TradingRules::Position.new("0:0:0"),
          kspc: 1.0,
          kcpc: 1.0
        )
      end

      private def build_reinit_merge_state(context : TradeContext,
                                           option_reinit : TradingSystem::ReInitOption,
                                           option_split : Exchange::Security::Split?) : SettingsState
        current_settings = context.current_settings.not_nil!

        SettingsState.new(
          rank: current_settings.rank + 1,
          split: option_split,
          sync: nil,
          reinit: option_reinit,
          q0: 0.0,
          c0: 0.0,
          position: TradingRules::Position.new("0:0:0"),
          kspc: 1.0,
          kcpc: 1.0
        )
      end

      private def build_standard_state(context : TradeContext, scale) : SettingsState
        current_settings = context.current_settings.not_nil!
        last_operation = context.last_operation.not_nil!

        position = last_operation.position.reset_jumps
        validate_scale_compatibility!(scale, position)

        q0, c0 = {current_settings.q0, current_settings.c0}

        SettingsState.new(
          rank: current_settings.rank + 1,
          split: nil,
          sync: nil,
          reinit: nil,
          q0: q0,
          c0: c0,
          position: position,
          kspc: current_settings.kspc * last_operation.ksp,
          kcpc: current_settings.kcpc * last_operation.kcp
        )
      end

      private def build_split_state(context : TradeContext,
                                    option_split,
                                    scale) : SettingsState
        current_settings = context.current_settings.not_nil!
        last_operation = context.last_operation.not_nil!

        position = last_operation.position.reset_jumps
        validate_scale_compatibility!(scale, position)

        lastdata = TradingRules::LastData.new(current_settings, last_operation)

        coeffs = TradingRules::Coefficient.new(
          lastdata: lastdata,
          price_direction: TradingRules::Direction::None,
          origin: TradingRules::Origin::FromSettings,
          sync: nil
        )

        SettingsState.new(
          rank: current_settings.rank + 1,
          split: option_split,
          sync: nil,
          reinit: nil,
          q0: option_split.quantity(current_settings.q0),
          c0: option_split.price(current_settings.c0),
          position: position,
          kspc: current_settings.kspc * coeffs.ksp,
          kcpc: current_settings.kcpc * coeffs.kcp
        )
      end

      private def build_sync_state(context : TradeContext, option_sync, scale) : SettingsState
        current_settings = context.current_settings.not_nil!
        last_operation = context.last_operation.not_nil!

        position = option_sync.reset_jumps
        validate_scale_compatibility!(scale, position)

        lastdata = TradingRules::LastData.new(current_settings, last_operation)

        coeffs = TradingRules::Coefficient.new(
          lastdata: lastdata,
          price_direction: TradingRules::Direction::None,
          origin: TradingRules::Origin::FromSettings,
          sync: option_sync
        )

        SettingsState.new(
          rank: current_settings.rank + 1,
          split: nil,
          sync: option_sync,
          reinit: nil,
          q0: current_settings.q0,
          c0: current_settings.c0,
          position: position,
          kspc: current_settings.kspc * coeffs.ksp,
          kcpc: current_settings.kcpc * coeffs.kcp
        )
      end

      private def validate_scale_compatibility!(scale : TradingRules::Scale,
                                                position : TradingRules::Position) : Nil
        opscale = scale.operational

        if position.e >= opscale.emax || position.e <= opscale.emin
          raise LowLevelError.new(
            key: "settings.create.scale_steps_incompatibility",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)}
          )
        end
      end
    end
  end
end
