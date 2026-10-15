module Jedi
  module Tools
    class Play
      # Synthetic identity: valid format and ISIN/Luhn check digit, while
      # remaining unmistakably associated with Jedi's in-memory simulation.
      SIMULATION_SECURITY_ISIN   = "FRJEDI000000"
      SIMULATION_SECURITY_NAME   = "JEDI SIMULATION SECURITY"
      SIMULATION_SECURITY_TICKER = "JEDI"

      # ============================================================
      # Internal data types
      # ============================================================
      alias RunningOrdersMap = Hash(Symbol, TradingSystem::OrderEngine::Order)
      record RunningOrders,
        oper_id : PkId,
        key : Symbol,
        orders : RunningOrdersMap

      enum LossTrigger
        Fallback
        Active
      end

      def self.parse_loss_trigger(raw : String?) : LossTrigger
        return LossTrigger::Fallback if raw.nil?

        value = raw.strip.downcase
        return LossTrigger::Fallback if value.empty?

        case value
        when "fallback"
          LossTrigger::Fallback
        when "active"
          LossTrigger::Active
        else
          raise LowLevelError.new(
            "invalid play loss trigger '#{raw}'",
            key: "tools.play.invalid_trigger",
            kind: LowLevelError::Kind::UserInput,
            context: {:trigger => raw.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end

      struct TradeParams
        # All mandatory or optional with defaults
        getter scale_raw : String
        getter q0 : Int32
        getter c0 : Float64
        getter tick : Exchange::Security::Tick
        getter money : TradingSystem::Money?
        getter stop : TradingSystem::TradeStop?
        getter loss_trigger : LossTrigger

        def initialize(raw : String)
          params = Helpers.parse_params(raw) # TODO Peut-être pas un Helper finalement !!!
          # mandatory
          # scale checked only on presence, not its definition validity
          @scale_raw = params["scale"]? ||
                       raise LowLevelError.new(
                         "missing play scale",
                         key: "tools.play.missing_scale",
                         kind: LowLevelError::Kind::UserInput,
                         log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          @q0 = Helpers.parse_int(params["q0"]?, "q0")
          @c0 = Helpers.parse_float(params["c0"]?, "c0")
          # optional
          # Tick.new raises if tick invalid (blank, nil, invalid value)
          @tick = Exchange::Security::Tick.new((x = params["tick"]?) ? x : "0.01")
          begin
            # Money raises if invalid string definition, empty string is ok
            @money = TradingSystem::Money.parse(params["money"]?)
          rescue ex : LowLevelError
            raise LowLevelError.new(
              "invalid play money definition '#{params["money"]?}'",
              key: "tools.play.invalid_money",
              kind: LowLevelError::Kind::UserInput,
              context: {:money => params["money"].to_s},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
              cause: ex)
          end
          @stop = nil # TODO To be fixed  ?
          @loss_trigger = Play.parse_loss_trigger(params["loss_trigger"]? || params["loss"]?)
        end
      end

      # ============================================================
      # Current simulation context
      # ============================================================
      class Context
        property timestamp : Time
        property current_settings : TradingSystem::Settings
        property current_operation : TradingLife::Operation
        getter running_orders : Array(RunningOrders)

        def initialize(
          @timestamp : Time,
          @current_settings : TradingSystem::Settings,
          @current_operation : TradingLife::Operation,
          @running_orders = [] of RunningOrders,
        )
        end
      end

      # ============================================================
      # Play actions
      # ============================================================
      abstract class Action
      end

      class MarkAction < Action
      end

      class StepAction < Action
        getter steps : Array(Int32)

        def initialize(@steps : Array(Int32))
        end
      end

      class TargetPriceAction < Action
        getter price : Float64

        def initialize(@price : Float64)
        end
      end

      class ManualOperationAction < Action
        getter quantity : Int32
        getter price : Float64

        def initialize(@quantity : Int32, @price : Float64)
        end
      end

      class SettingsChangeAction < Action
        getter scale_name : String?
        getter split : Exchange::Security::Split?
        getter sync : TradingRules::Position?
        getter reinit : TradingSystem::ReInitOption?
        getter loss_trigger : LossTrigger?

        def initialize(
          @scale_name = nil,
          @split = nil,
          @sync = nil,
          @reinit = nil,
          @loss_trigger = nil,
        )
        end

        def empty? : Bool
          @scale_name.nil? && @split.nil? && @sync.nil? && @reinit.nil? &&
            @loss_trigger.nil?
        end

        def settings_change? : Bool
          !(@scale_name.nil? && @split.nil? && @sync.nil? && @reinit.nil?)
        end

        def loss_trigger_only? : Bool
          !@loss_trigger.nil? && !settings_change?
        end

        def options_compatible? : Bool
          @sync.nil? || (@split.nil? && @reinit.nil?)
        end
      end

      class TradeMoneyChangeAction < Action
        getter money_raw : String

        def initialize(@money_raw : String)
        end
      end

      class TradeStopChangeAction < Action
        getter stop_raw : String

        def initialize(@stop_raw : String)
        end
      end

      # ============================================================
      # Action builders / parsers
      # ============================================================

      class SettingsChangeBuilder
        property scale_name : String?
        property split : Exchange::Security::Split?
        property sync : TradingRules::Position?
        property reinit : TradingSystem::ReInitOption?
        property loss_trigger : LossTrigger?

        def initialize
          @scale_name = nil
          @split = nil
          @sync = nil
          @reinit = nil
          @loss_trigger = nil
        end

        def empty? : Bool
          @scale_name.nil? && @split.nil? && @sync.nil? && @reinit.nil? &&
            @loss_trigger.nil?
        end

        def to_action : SettingsChangeAction
          SettingsChangeAction.new(
            scale_name: @scale_name,
            split: @split,
            sync: @sync,
            reinit: @reinit,
            loss_trigger: @loss_trigger
          )
        end

        def clear : Nil
          @scale_name = nil
          @split = nil
          @sync = nil
          @reinit = nil
          @loss_trigger = nil
        end
      end

      class CommandParser
        def parse(argv : Array(String)) : Array(Action)
          actions = [] of Action
          settings_builder = SettingsChangeBuilder.new
          mark_seen = false
          argv.each do |token|
            if token == "mark"
              if mark_seen
                raise LowLevelError.new(
                  "play scenario contains more than one mark",
                  key: "tools.play.one_mark_only",
                  kind: LowLevelError::Kind::UserInput,
                  log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
              end
              flush_settings_builder(actions, settings_builder)
              actions << MarkAction.new
              mark_seen = true
              next
            end
            if settings_assignment?(token)
              Core::Input.kv_decode(token, ESEP).each do |sub_token|
                apply_settings_token(settings_builder, sub_token)
              end
              next
            end
            if money_assignment?(token)
              flush_settings_builder(actions, settings_builder)
              actions << TradeMoneyChangeAction.new(token.split("=", 2)[1])
              next
            end
            if stop_assignment?(token)
              flush_settings_builder(actions, settings_builder)
              actions << TradeStopChangeAction.new(token.split("=", 2)[1])
              next
            end

            flush_settings_builder(actions, settings_builder)
            actions << parse_non_settings_token(token)
          end
          flush_settings_builder(actions, settings_builder)
          actions
        end

        private def flush_settings_builder(
          actions : Array(Action),
          builder : SettingsChangeBuilder,
        ) : Nil
          return if builder.empty?
          actions << builder.to_action
          builder.clear
        end

        private def settings_assignment?(token : String) : Bool
          token.starts_with?("scale=") ||
            token.starts_with?("split=") ||
            token.starts_with?("sync=") ||
            token.starts_with?("reinit=") ||
            token.starts_with?("loss=") ||
            token.starts_with?("loss_trigger=")
        end

        private def money_assignment?(token : String) : Bool
          token.starts_with?("money=")
        end

        private def stop_assignment?(token : String) : Bool
          token.starts_with?("stop=")
        end

        private def apply_settings_token(
          builder : SettingsChangeBuilder,
          token : String,
        ) : Nil
          key, value = token.split("=", 2)
          case key
          when "scale"
            builder.scale_name = value
          when "split"
            builder.split = parse_split(value)
          when "sync"
            builder.sync = parse_sync(value)
          when "reinit"
            builder.reinit = TradingSystem::ReInitOption.parse(value)
          when "loss", "loss_trigger"
            builder.loss_trigger = Play.parse_loss_trigger(value)
          else
            raise LowLevelError.new(
              "unknown play settings keyword '#{key}'",
              key: "tools.play.unknown_settings_keyword",
              kind: LowLevelError::Kind::UserInput,
              context: {:keyword => key},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
        end

        private def parse_non_settings_token(token : String) : Action
          if token.includes?("@")
            return parse_manual_operation(token)
          end

          if step_token?(token)
            return parse_step_token(token)
          end

          if target_price_token?(token)
            return TargetPriceAction.new(token.to_f64)
          end

          raise LowLevelError.new(
            "unsupported play argument '#{token}'",
            key: "tools.play.unsupported_argument",
            kind: LowLevelError::Kind::UserInput,
            context: {:arg => token},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        private def step_token?(token : String) : Bool
          return true if token.matches?(/\A-?\d+\z/)
          return true if token.matches?(/\A\d+x-?\d+(,-?\d+)*\z/)
          false
        end

        private def target_price_token?(token : String) : Bool
          token.matches?(/\A\d+\.\d+\z/)
        end

        private def parse_manual_operation(token : String) : ManualOperationAction
          parts = token.split("@", 2)
          raise LowLevelError.new(
            "invalid manual play operation '#{token}'",
            key: "tools.play.invalid_manual_operation",
            kind: LowLevelError::Kind::UserInput,
            context: {:oper => token},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)}) unless parts.size == 2
          qty = parts[0].to_i?
          price = parts[1].to_f64?
          raise LowLevelError.new(
            "invalid manual play operation quantity '#{token}'",
            key: "tools.play.invalid_manual_operation_quantity",
            kind: LowLevelError::Kind::UserInput,
            context: {:oper => token},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)}) if qty.nil?
          raise LowLevelError.new(
            "invalid manual play operation price '#{token}'",
            key: "tools.play.invalid_manual_operation_price",
            kind: LowLevelError::Kind::UserInput,
            context: {:oper => token},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)}) if price.nil?
          ManualOperationAction.new(qty, price)
        end

        private def parse_step_token(token : String) : StepAction
          if token.matches?(/\A-?\d+\z/)
            n = token.to_i
            step = n < 0 ? -1 : 1
            return StepAction.new(Array.new(n.abs, step))
          end
          if md = token.match(/\A(\d+)x(.+)\z/)
            repeat = md[1].to_i
            seq = md[2].split(",").map(&.to_i)
            steps = [] of Int32
            repeat.times do
              steps.concat(seq)
            end
            return StepAction.new(steps)
          end

          raise LowLevelError.new(
            "invalid play step argument '#{token}'",
            key: "tools.play.invalid_step_argument",
            kind: LowLevelError::Kind::UserInput,
            context: {:arg => token},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        private def parse_split(raw : String)
          Exchange::Security::Split.new(raw)
        end

        private def parse_sync(raw : String)
          TradingRules::Position.new(raw)
        end
      end

      # ============================================================
      # Attributes
      # ============================================================

      getter conn_main : DB::Connection
      getter conn_memory : DB::Connection
      getter! mem_trade : TradingSystem::Trade
      property! context : Context
      property mark : PkId = 0
      property new_operations_count = 0
      property mem_operation_id : PkId = 0
      property loss_trigger : LossTrigger = LossTrigger::Fallback
      getter? simulation_stopped : Bool = false

      property trans_id = {} of PkId => String
      property trade_history = {} of PkId => String
      property base_id : PkId? = nil
      property base_offset : Int32 = 0
      private getter reported_operating_warnings = Set(String).new

      # ============================================================
      # Constructor
      # ============================================================

      def initialize(@conn_main : DB::Connection,
                     @conn_memory : DB::Connection,
                     @params : String | PkId,
                     argv : Array(String))
        init_memory_schema

        case params
        when PkId
          App.simulation = SimulationMode::FromOperation
          bootstrap_from_operation(@params.as(PkId))
        else
          App.simulation = SimulationMode::FromSeed
          bootstrap_from_seed(@params.as(String))
        end
        do_simulation(argv)
      end

      # ============================================================
      # Public API
      # # ============================================================

      def run(option_command)
        result = ""
        option_command.each_with_index do |(k, v), i|
          result += "\n\n" unless i.zero?
          cols = v.empty? ? nil : v
          case k
          when 'T'
            result += TradingSystem::TradeLister.new(conn_memory).call option_extended: true,
              option_columns: cols
          when 't'
            result += TradingSystem::TradeLister.new(conn_memory).call option_columns: cols
          when 'K'
            result += Exchange::SecurityLister.new(conn_memory).call option_extended: true,
              option_columns: cols
          when 'k'
            result += Exchange::SecurityLister.new(conn_memory).call option_columns: cols
          when 'S'
            result += TradingRules::ScaleLister.new(conn_memory).call option_extended: true,
              option_columns: cols
          when 's'
            result += TradingRules::ScaleLister.new(conn_memory).call option_columns: cols
          when 'c'
            result += TradingSystem::SettingsLister.new(conn_memory).call option_columns: cols
          when 'o'
            result += TradingLife::OperationLister.new(conn_memory).call(
              option_records: "l#{new_operations_count + 1}",
              option_columns: v.empty? ? nil : v,
              from_play: trans_id)
          when 'd' then result += list_debug_lines
          when 'r' then result += list_running_orders
          when 'f' then result += list_results(mark)
          else
            raise LowLevelError.new(
              "invalid play output command letter '#{k}'",
              key: "infra.option_invalid_argument",
              kind: LowLevelError::Kind::UserInput,
              context: {
                :option => "--command",
                :arg    => k.to_s,
              },
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
        end
        result
      end

      # ============================================================
      # Bootstraps
      # ============================================================

      private def bootstrap_from_seed(params : String) : Nil
        trade_params = TradeParams.new(params)
        self.loss_trigger = trade_params.loss_trigger
        timestamp = Time.local

        # Exchange::SecurityCreator.new(conn_memory).call(
        security_id = Exchange::SecurityCreator.new(conn_memory).call(
          isin: SIMULATION_SECURITY_ISIN,
          name: SIMULATION_SECURITY_NAME,
          ticker: SIMULATION_SECURITY_TICKER,
          tick_buy: trade_params.tick,
          tick_sell: trade_params.tick,
          tax: 0.0
        )

        trade_id = TradingSystem::TradeCreator.new(conn_memory).call(
          name: "PLAY",
          money: trade_params.money,
          stop: trade_params.stop,
          security_ident: security_id
          # security_ident: SIMULATION_SECURITY_ISIN
        )

        @mem_trade = TradingSystem::Trade.new(conn_memory, trade_id)

        scale_id = Tools::Helpers.scale(conn_main, conn_memory, trade_params.scale_raw).id

        settings_id = TradingSystem::SettingsCreator.new(conn_memory).call(
          trade_ident: trade_id,
          scale_ident: scale_id,
          timestamp: timestamp
        )

        op_id = TradingLife::OperationCreator.new(conn_memory).call(
          trade_ident: trade_id,
          timestamp: timestamp,
          type: TradingLife::Operation::Type::Buy,
          mode: TradingLife::Operation::Mode::Market,
          quantity: trade_params.q0,
          price: trade_params.c0,
          cfees: App.fees,
          tickcheck: false
        )

        self.mem_operation_id = op_id

        @context = Context.new(
          timestamp,
          TradingSystem::Settings.new(conn_memory, settings_id),
          TradingLife::Operation.new(conn_memory, op_id)
        )
      end

      private def bootstrap_from_operation(operation_id : PkId) : Nil
        source_operation = TradingLife::Operation.new(conn_main, operation_id)
        source_settings = source_operation.settings
        source_trade = source_settings.trade
        source_security = source_trade.security

        Exchange::SecurityCreator.new(conn_memory).call(
          isin: source_security.isin,
          name: source_security.name,
          ticker: source_security.ticker,
          tick_buy: source_security.tick_buy,
          tick_sell: source_security.tick_sell,
          tax: source_security.tax
        )

        trade_id = TradingSystem::TradeCreator.new(conn_memory).call(
          name: source_trade.name,
          # money and stop must be given as arguments in command line
          # Using them from the production database is not possible, as
          # the operation may be far in the past !
          # money and stop set to nil without error, no need to rescue
          money: TradingSystem::Money.parse(""),    # source_trade.money,
          stop: TradingSystem::TradeStop.parse(""), # source_trade.stop,
          security_ident: source_security.isin
        )

        @mem_trade = TradingSystem::Trade.new(conn_memory, trade_id)

        scale_id = TradingRules::ScaleCreator.new(conn_memory).restore(
          name: source_settings.scale.name,
          comment: source_settings.scale.comment,
          builder: source_settings.scale.operational.builder
        )

        settings_id = insert_copied_settings!(
          rank: source_settings.rank,
          timestamp: source_settings.timestamp,
          split_raw: source_settings.split.to_s,
          sync_raw: source_settings.sync.to_s,
          reinit_raw: source_settings.reinit.to_s,
          q0: source_settings.q0,
          c0: source_settings.c0,
          position: source_settings.position.to_s,
          kspc: source_settings.kspc,
          kcpc: source_settings.kcpc,
          trade_id: trade_id,
          scale_id: scale_id
        )

        current_operation = nil.as(TradingLife::Operation?)
        source_trade.operations.each do |op|
          break if op.id > operation_id

          op_id = insert_copied_operation!(
            timestamp: op.timestamp,
            type: op.type,
            mode: op.mode,
            quantity: op.quantity,
            price: op.price,
            buy: op.buy,
            sell: op.sell,
            trade_invest: op.trade_invest,
            global_invest: op.global_invest,
            fees: op.fees,
            stock: op.stock,
            position: op.position.to_s,
            ksp: op.ksp,
            kcp: op.kcp,
            settings_id: settings_id
          )
          self.mem_operation_id = op_id
          current_operation = TradingLife::Operation.new(conn_memory, op_id)
        end
        self.base_id = operation_id
        self.base_offset = 0
        trans_id[mem_operation_id] = "#{mem_operation_id}=#{operation_id}"

        raise LowLevelError.new(
          "cannot build play context from copied operation",
          kind: LowLevelError::Kind::Technical,
          log_context: {
            :operation_id => operation_id.to_s,
            :source       => Core::Utils.source(__FILE__, __LINE__),
          }) if current_operation.nil?

        @context = Context.new(
          current_operation.not_nil!.timestamp,
          TradingSystem::Settings.new(conn_memory, settings_id),
          current_operation.not_nil!
        )
      end

      # ============================================================
      # Main simulation loop
      # ============================================================
      private def do_simulation(argv : Array(String)) : Nil
        actions = CommandParser.new.parse(argv)
        actions_count = actions.size
        last = false
        actions.each.with_index(1) do |action, i|
          last = i == actions_count
          execute_action(action, last)
          break if simulation_stopped?
        end
      end

      private def stop_simulation! : Nil
        @simulation_stopped = true
      end

      private def execute_action(action : Action, last) : Nil
        return if simulation_stopped?
        if merge_pending?
          case action
          when ManualOperationAction
            execute_manual_operation_action(action)
          when SettingsChangeAction
            if action.loss_trigger_only?
              execute_settings_change_action(action)
            else
              raise LowLevelError.new(
                "reinit=merge requires a following manual operation",
                key: "tools.play.reinit_merge_manual_operation",
                kind: LowLevelError::Kind::UserInput,
                log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
            end
          else
            raise LowLevelError.new(
              "reinit=merge requires a following manual operation",
              key: "tools.play.reinit_merge_manual_operation",
              kind: LowLevelError::Kind::UserInput,
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
        else
          case action
          when StepAction
            execute_step_action(action)
          when TargetPriceAction
            execute_target_price_action(action)
          when ManualOperationAction
            # TODO
            execute_manual_operation_action(action)
            unless last
              stop_simulation!
              App.warn(key: "tools.play.no_merge_pending")
            end
          when SettingsChangeAction
            if action.options_compatible?
              execute_settings_change_action(action)
            else
              raise LowLevelError.new(
                "play sync cannot be combined with split or reinit",
                key: "tools.play.reinit_split_sync_exclusive",
                kind: LowLevelError::Kind::UserInput,
                log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
            end
          when TradeMoneyChangeAction
            execute_trade_money_change_action(action)
          when TradeStopChangeAction
            execute_trade_stop_change_action(action)
          when MarkAction
            execute_mark_action
          else
            raise LowLevelError.new(
              "unsupported internal play action '#{action.class.name}'",
              kind: LowLevelError::Kind::Technical,
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
        end
      end

      # ============================================================
      # Action execution

      # ============================================================
      private def execute_step_action(action : StepAction) : Nil
        action.steps.each do |step|
          actual_step =
            case step
            when -1
              -1
            when 1
              1
            when 0
              rand < 0.5 ? -1 : 1
            else
              raise LowLevelError.new(
                "invalid internal play step value '#{step}'",
                kind: LowLevelError::Kind::Technical,
                log_context: {
                  :step   => step.to_s,
                  :source => Core::Utils.source(__FILE__, __LINE__),
                })
            end

          key = actual_step > 0 ? :up : :down
          break unless add_operation(key)
        end
      end

      private def execute_target_price_action(action : TargetPriceAction) : Nil
        current_price = TradingRules::LastData.new(
          context.current_settings, context.current_operation).maybe_splitted_price
        target_price = action.price
        return if target_price == current_price
        if target_price > current_price
          execute_target_price_steps(:up, target_price)
        else
          execute_target_price_steps(:down, target_price)
        end
      end

      private def execute_manual_operation_action(action : ManualOperationAction) : Nil
        self.new_operations_count += 1
        if action.quantity > 0
          add_fixed_operation(
            TradingLife::Operation::Type::Buy,
            TradingLife::Operation::Mode::Market,
            action.quantity,
            action.price
          )
        elsif action.quantity < 0
          available_stock = TradingRules::LastData.new(
            context.current_settings, context.current_operation).maybe_splitted_stock
          validate_no_short_selling!(action.quantity.abs, available_stock)
          add_fixed_operation(
            TradingLife::Operation::Type::Sell,
            TradingLife::Operation::Mode::Market,
            action.quantity.abs,
            action.price
          )
        else
          raise LowLevelError.new(
            "manual play operation quantity cannot be zero",
            key: "tools.play.invalid_quantity_zero",
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end

      private def execute_settings_change_action(action : SettingsChangeAction) : Nil
        # self.loss_trigger = action.loss_trigger if action.loss_trigger

        if loss_trigger = action.loss_trigger
          self.loss_trigger = loss_trigger
        end

        return if action.loss_trigger_only?

        change_settings(
          action.scale_name || context.current_settings.scale.name,
          action.split,
          action.sync,
          action.reinit
        )
      end

      private def execute_trade_money_change_action(action : TradeMoneyChangeAction) : Nil
        apply_trade_money_change(action.money_raw)
      end

      private def execute_trade_stop_change_action(action : TradeStopChangeAction) : Nil
        apply_trade_stop_change(action.stop_raw)
      end

      private def execute_mark_action : Nil
        @mark = context.current_operation.id
      end

      private def current_order_selection(requested_key : Symbol)
        engine = TradingSystem::OrderEngine.new(mem_trade)
        orders = engine.orders
        selected = selected_order_for(orders, requested_key)
        relevant_key = selected.try(&.[:key]) || requested_key
        report_operating_warnings(engine, relevant_key)
        {orders: orders, selected: selected}
      end

      private def selected_order_for(
        orders : RunningOrdersMap,
        requested_key : Symbol,
      ) : NamedTuple(key: Symbol, order: TradingSystem::OrderEngine::Order)?
        selected_key = selected_order_key_for(orders, requested_key)
        return nil if selected_key.nil?

        order = orders[selected_key]?
        return nil if order.nil?

        {key: selected_key, order: order}
      end

      private def selected_order_key_for(orders : RunningOrdersMap, requested_key : Symbol) : Symbol?
        return requested_key unless requested_key == :down
        down_available = orders.has_key?(:down)
        loss_available = orders.has_key?(:loss)
        case loss_trigger
        when LossTrigger::Fallback
          return :down if down_available
          return :loss if loss_available
        when LossTrigger::Active
          return :loss if loss_available
          return :down if down_available
        end

        nil
      end

      private def report_operating_warnings(
        engine : TradingSystem::OrderEngine,
        relevant_key : Symbol,
      ) : Nil
        engine.operating_warning_details.each do |warning|
          next unless warning.order_key == relevant_key
          next if warning.message.in?(reported_operating_warnings)

          reported_operating_warnings << warning.message
          App.warn("tools.play.warning", params: {
            :operation => context.current_operation.id.to_s,
            :warning   => warning.message,
          })
        end
      end

      # ============================================================
      # Operation application helpers
      # ============================================================
      private def add_operation(key : Symbol) : Bool
        if context.current_operation.stock <= 0
          stop_simulation!
          return false
        end
        selection = current_order_selection(key)
        orders = selection[:orders]
        selected = selection[:selected]
        return false if selected.nil?

        advance_time!
        self.new_operations_count += 1

        order = selected[:order]

        op_id = insert_simulated_operation!(
          type: order.type,
          mode: order.mode,
          quantity: order.quantity,
          price: order.price
        )
        # Line below added by hutou, 2026-08-20
        trade_history[op_id] = "money:#{@mem_trade.not_nil!.money}, stop:#{@mem_trade.not_nil!.stop}"

        if base_id
          self.base_offset += 1
          # trans_id[op_id] = "#{base_id}+#{base_offset}"
          trans_id[op_id] = "#{op_id}=#{base_id}+#{base_offset}"
        end

        register_context!(operation_id: op_id)
        context.running_orders << RunningOrders.new(
          oper_id: op_id,
          key: selected[:key],
          orders: orders
        )
        context.current_operation.stock > 0
      end

      private def add_fixed_operation(
        type : TradingLife::Operation::Type,
        mode : TradingLife::Operation::Mode,
        quantity : Int32,
        price : Float64,
      ) : Bool
        if context.current_operation.stock <= 0
          stop_simulation!
          return false
        end
        advance_time!
        op_id = insert_simulated_operation!(
          type: type,
          mode: mode,
          quantity: quantity,
          price: price
        )
        if base_id
          self.base_offset += 1
          # trans_id[op_id] = "#{base_id}+#{base_offset}"
          trans_id[op_id] = "#{op_id}=#{base_id}+#{base_offset}"
        end
        register_context!(operation_id: op_id)
        context.current_operation.stock > 0
      end

      # ============================================================
      # Merge-pending guards
      # ============================================================
      private def merge_pending? : Bool
        reinit = reinit_option_of(context.current_settings)
        return false if reinit.nil?
        return false unless reinit.merge?
        # context.current_settings.q0 == 0.0
        context.current_operation.settings.id != context.current_settings.id
      end

      # ============================================================
      # Settings changes
      # ============================================================
      private def change_settings(
        scale_name : String,
        split : Exchange::Security::Split? = nil,
        sync : TradingRules::Position? = nil,
        reinit : TradingSystem::ReInitOption? = nil,
      ) : Nil
        advance_time!(days: 1)

        scale = Tools::Helpers.scale(conn_main, conn_memory, scale_name)

        settings_id = TradingSystem::SettingsCreator.new(conn_memory).call(
          trade_ident: mem_trade.id,
          scale_ident: scale.id,
          timestamp: context.timestamp,
          option_split: split,
          option_sync: sync,
          option_reinit: reinit
        )

        register_context!(settings_id: settings_id)
      end

      # ============================================================
      # Simulated operation creation
      # ============================================================
      private def insert_simulated_operation!(
        *,
        type : TradingLife::Operation::Type,
        mode : TradingLife::Operation::Mode,
        quantity : Int32,
        price : Float64,
      ) : PkId
        operation_id = TradingLife::OperationCreator.new(conn_memory).call(
          trade_ident: mem_trade.id,
          timestamp: context.timestamp,
          type: type,
          mode: mode,
          quantity: quantity,
          price: price,
          cfees: App.fees,
          tickcheck: false
        )
        mem_trade.reload!(mem_trade.id)
        operation_id
      end

      # ============================================================
      # Output / reporting
      # ============================================================
      private def list_debug_lines
        String.build do |io|
          io << "Debug orders:" << "\n"
          context.running_orders.each do |running_order|
            op_id = running_order.oper_id
            x = trans_id.has_key?(op_id) ? trans_id[op_id] : op_id
            io << "Operation Id: ##{x}" << "\n"
            key = running_order.key
            running_order.orders.each_with_index do |(k, v), i|
              kf = "%4s" % k
              io << "  " << (k == key ? "→ #{kf}:" : "  #{kf}:")
              if k == :loss
                # hack, not very clean !!!
                # Replace operation_id with prod_operation_id + offset
                debug_lines = [] of String
                v.debug_line.split(" ").each do |s|
                  name, value = s.split("=")
                  if name.ends_with?("_stop")
                    elts = value.split(":")
                    if trans_id.has_key?(elts[0].to_i)
                      elts[0] = trans_id[elts[0].to_i]
                      value = elts.join(":")
                    end
                    debug_lines << "#{name}=#{value}"
                  else
                    debug_lines << s
                  end
                end
                io << " " << debug_lines.join(" ") << "\n"
              else
                io << " #{v.debug_line}" << "\n"
              end
            end
            io << "Trade status after operation -> #{trade_history[op_id]}\n"
            io << "\n"
          end
        end
      end

      private def list_running_orders
        array_orders = [] of NamedTuple(opid: String, op_id: PkId, key: Symbol,
          dir: Symbol, order: TradingSystem::OrderEngine::Order)

        ar_price = [] of Float64
        ar_spe = [] of Float64
        ar_cpe = [] of Float64
        context.running_orders.each do |running_order|
          op_id = running_order.oper_id
          key = running_order.key
          running_order.orders.each_with_index do |(k, v), i|
            opid = i.zero? ? op_id.to_s : ""
            array_orders << {opid: opid, op_id: op_id, key: key, dir: k, order: v}
            ar_price << v.price
            ar_spe << v.spe
            ar_cpe << v.cpe
          end
        end
        price_precision = Tablo::Functions.fp_reduce_precision(ar_price, 4)
        spe_precision = Tablo::Functions.fp_reduce_precision(ar_spe, 6)
        cpe_precision = Tablo::Functions.fp_reduce_precision(ar_cpe, 6)

        table = Tablo::Table.new(array_orders,
          body_formatter: ->(value : Tablo::CellType, coords : Tablo::Cell::Data::Coords) {
            if coords.column_index == 4
              Tablo::Functions.fp_align(value.as(Float), price_precision, :dot_zero)
            elsif coords.column_index == 6
              Tablo::Functions.fp_align(value.as(Float), spe_precision, :dot_zero)
            elsif coords.column_index == 7
              Tablo::Functions.fp_align(value.as(Float), cpe_precision, :dot_zero)
            else
              value.to_s
            end
          },
          header_alignment: Tablo::Justify::Center,
          title: Tablo::Heading.new(I18n.t("tools.play.orders.title"),
            framed: true)) do |t|
          t.add_column(0, header: I18n.t("tools.play.orders.oper"),
            header_alignment: Tablo::Justify::Center,
            body_alignment: Tablo::Justify::Center) { |n|
            if n[:opid].empty?
              ""
            else
              trans_id.empty? ? n[:opid] : trans_id[n[:opid].to_i]
            end
          }

          t.add_column(1, header: I18n.t("tools.play.orders.type")) { |n|
            sel = n[:dir] == n[:key] ? "→ " : "  "
            n[:dir] == :up ? "↑ " + sel + n[:order].type.to_s : "↓ " + sel + n[:order].type.to_s
          }
          t.add_column(2, header: I18n.t("tools.play.orders.mode")) { |n| n[:order].mode.to_s }
          t.add_column(3, header: I18n.t("tools.play.orders.quantity")) { |n| order_quantity_label(n[:dir], n[:order]) }
          t.add_column(4, header: I18n.t("tools.play.orders.price")) { |n| n[:order].price }
          t.add_column(5, header: I18n.t("tools.play.orders.position")) { |n| n[:order].position.to_s }
          t.add_column(6, header: I18n.t("tools.play.orders.spe")) { |n| n[:order].spe }
          t.add_column(7, header: I18n.t("tools.play.orders.cpe")) { |n| n[:order].cpe }
        end

        nrow = 0
        String.build do |io|
          # table.pack(except: 0).each do |row|
          table.pack.each do |row|
            if row.source[:op_id] != nrow
              io << table.horizontal_rule(Tablo::RuleType::BodyBody) << "\n" if nrow > 0

              nrow = row.source[:op_id]
            end
            io << row << "\n"
          end
        end
      end

      private def order_quantity_label(dir : Symbol, order : TradingSystem::OrderEngine::Order) : String
        if dir == :loss && (original_quantity = order.original_quantity) && order.quantity != original_quantity
          "#{original_quantity} → #{order.quantity}"
        else
          order.quantity.to_s
        end
      end

      private def list_results(mark)
        base = mem_operation_id
        buy_part1 = buy_part2 = buy_part3 = 0.0
        sell_part1 = sell_part2 = sell_part3 = 0.0
        portfolio1 = portfolio2 = portfolio3 = 0.0
        operations = TradingLife::Operations.new(conn_memory).fetch

        mark = 0 if mark.nil?
        if mark == base
          raise LowLevelError.new(
            "play result mark cannot be the base operation",
            key: "tools.play.results.mark_position",
            kind: LowLevelError::Kind::Domain,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        operations.each do |operation|
          if operation.id <= base
            buy_part1 += operation.buy
            sell_part1 += operation.sell
            portfolio1 = (operation.price * operation.stock * 100).round if operation.id == base
          elsif operation.id <= mark
            buy_part2 += operation.buy
            sell_part2 += operation.sell
            portfolio2 = (operation.price * operation.stock * 100).round if operation.id == mark
          else
            buy_part3 += operation.buy
            sell_part3 += operation.sell
          end
        end
        portfolio3 = (operations.last.price * operations.last.stock * 100).round
        result1 = portfolio1 + sell_part1 - buy_part1
        if mark > 0
          result2 = portfolio2 - portfolio1 + sell_part2 - buy_part2
          result3 = portfolio3 - portfolio2 + sell_part3 - buy_part3
        else
          result2 = 0.0
          result3 = portfolio3 - portfolio1 + sell_part3 - buy_part3
        end
        result1 + result2 + result3
        result0 = portfolio3 + sell_part1 + sell_part2 + sell_part3 -
                  buy_part1 - buy_part2 - buy_part3
        table = Tablo::Table.new([[result0,
                                   result1,
                                   result2,
                                   result3]],
          title: Tablo::Heading.new(I18n.t("tools.play.results.title"),
            framed: true), header_alignment: Tablo::Justify::Center,
          subtitle: (mark > 0 ? Tablo::Heading.new(I18n.t("tools.play.results.subtitle_mark",
            base: "#{base}", mark: "#{mark}")) : Tablo::Heading.new(
            I18n.t("tools.play.results.subtitle", base: "#{base}"))),
          body_formatter: ->(value : Tablo::CellType) { "%.2f" % (value.as(Float64) / 100) }) do |t|
          t.add_column(0, header: I18n.t("tools.play.results.total")) { |n| n[0] }
          t.add_column(1, header: I18n.t("tools.play.results.real_initial")) { |n| n[1] }
          if mark > 0
            t.add_column(2, header: I18n.t("tools.play.results.le_mark")) { |n| n[2] }
          end
          hdr = mark > 0 ? I18n.t("tools.play.results.gt_mark") : I18n.t("tools.play.results.simulated")
          t.add_column(3, header: hdr) { |n| n[3] }
          t.add_group(I18n.t("tools.play.results.gains_losses"))
        end.pack(44).to_s
      end

      # ============================================================
      # Business helpers
      # ============================================================
      private def reinit_option_of(settings) : TradingSystem::ReInitOption?
        raw = settings.reinit
        return nil if raw.nil?
        s = raw.to_s.strip
        return nil if s.empty?
        TradingSystem::ReInitOption.parse(s)
      end

      private def validate_no_short_selling!(
        quantity : Int32,
        available_stock : Int32,
      ) : Nil
        if quantity > available_stock
          raise LowLevelError.new(
            "play operation would create a short position",
            key: "tools.play.short_selling_prohibited",
            kind: LowLevelError::Kind::Domain,
            context: {:quantity => quantity.to_s, :stock => available_stock.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end

      private def next_order_for(key : Symbol)
        selection = current_order_selection(key)
        selected = selection[:selected]
        if selected.nil?
          raise LowLevelError.new(
            "no running order available for play direction '#{key}'",
            key: "tools.play.unknown_order_key",
            kind: LowLevelError::Kind::Domain,
            context: {:key => key.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        selected[:order]
      end

      private def execute_target_price_steps(key : Symbol, target_price : Float64) : Nil
        loop do
          order = next_order_for(key)
          next_price = order.price

          should_execute = case key
                           when :up
                             next_price <= target_price
                           when :down
                             next_price >= target_price
                           else
                             raise LowLevelError.new(
                               "invalid internal play price direction '#{key}'",
                               kind: LowLevelError::Kind::Technical,
                               log_context: {
                                 :direction => key.to_s,
                                 :source    => Core::Utils.source(__FILE__, __LINE__),
                               })
                           end
          break unless should_execute
          break unless add_operation(key)
        end
      end

      private def apply_trade_money_change(raw : String) : Nil
        # mem_trade.update(money: raw)
        TradingSystem::TradeUpdater.new(mem_trade).call money: raw
      end

      private def apply_trade_stop_change(raw : String) : Nil
        if mem_trade.money.nil?
          raise LowLevelError.new(
            "play stop cannot be set without money management",
            key: "tools.play.stop_needs_money",
            kind: LowLevelError::Kind::Domain,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        if (splitted_raw = raw.split(":")).size == 2
          raw = "0:#{splitted_raw[0]}:0:0:#{splitted_raw[1]}"
        end
        mem_trade.stop_clear

        stop = begin
          TradingSystem::TradeStop.parse(raw)
        rescue ex : LowLevelError
          raise LowLevelError.new(
            "invalid play trade stop '#{raw}'",
            key: "trade.invalid_trade_stop",
            kind: LowLevelError::Kind::UserInput,
            context: {
              :trade => mem_trade.name,
              :stop  => raw,
            },
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            cause: ex)
        end

        mem_trade.stop_update(stop: stop)
      end

      private def operation_count_for_settings(settings_id : PkId) : Int64
        conn_memory.scalar(
          "SELECT COUNT(*) FROM operation WHERE settings_id = ?",
          settings_id
        ).as(Int64)
      end

      # ============================================================
      # Context helpers
      # ============================================================
      private def register_context!(settings_id : PkId? = nil, operation_id : PkId? = nil) : Nil
        if settings_id
          context.current_settings = TradingSystem::Settings.new(conn_memory, settings_id)
        end
        if operation_id
          op = TradingLife::Operation.new(conn_memory, operation_id)
          context.current_operation = op
          context.timestamp = op.timestamp
        end
      end

      private def advance_time!(days = 0, seconds = 1) : Nil
        context.timestamp += days.days if days != 0
        context.timestamp += seconds.seconds if seconds != 0
      end

      # ============================================================
      # In-memory DB writes
      # ============================================================
      private def insert_copied_settings!(
        *,
        rank : Int32,
        timestamp : Time,
        split_raw : String,
        sync_raw : String,
        reinit_raw : String,
        q0 : Float64,
        c0 : Float64,
        position : String,
        kspc : Float64,
        kcpc : Float64,
        trade_id : PkId,
        scale_id : PkId,
      ) : PkId
        res = conn_memory.exec(
          "INSERT INTO settings
           (rank, timestamp, split, sync, reinit, q0, c0, position, kspc, kcpc, trade_id, scale_id)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          rank,
          timestamp,
          split_raw,
          sync_raw,
          reinit_raw,
          q0,
          c0,
          position,
          kspc,
          kcpc,
          trade_id,
          scale_id
        )
        sg_id = res.last_insert_id
        App.info(key: "tools.play.settings_created", params: {:sg_id => "#{sg_id}"})
        sg_id
      end

      private def insert_copied_operation!(
        *,
        timestamp : Time,
        type : TradingLife::Operation::Type,
        mode : TradingLife::Operation::Mode,
        quantity : Int32,
        price : Float64,
        buy : Int32,
        sell : Int32,
        trade_invest : Int32,
        global_invest : Int32,
        fees : Int32,
        stock : Int32,
        position : String,
        ksp : Float64,
        kcp : Float64,
        settings_id : PkId,
      ) : PkId
        res = conn_memory.exec(
          "INSERT INTO operation
           (timestamp, type, mode, quantity, price, buy, sell, trade_invest, global_invest,
            fees, stock, position, ksp, kcp, settings_id)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
          timestamp,
          type.to_s,
          mode.to_s,
          quantity,
          price,
          buy,
          sell,
          trade_invest,
          global_invest,
          fees,
          stock,
          position,
          ksp,
          kcp,
          settings_id
        )
        op_id = res.last_insert_id
        App.info(key: "tools.play.operation_created", params: {:op_id => "#{op_id}"})
        op_id
      end

      # ============================================================
      # In-memory schema
      # ============================================================
      private def init_memory_schema
        Database::Main.new(conn_memory).create_table_security
        Database::Main.new(conn_memory).create_table_trade
        Database::Main.new(conn_memory).create_table_scale
        Database::Main.new(conn_memory).create_table_settings
        Database::Main.new(conn_memory).create_table_operation
      end
    end
  end
end
