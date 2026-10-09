module Jedi
  module TradingSystem
    class TradeCreator
      private getter ref = ""

      def initialize(@conn_db : DB::Connection)
        @repo = TradeRepository.new(@conn_db)
      end

      def call(*, name : String,
               security_ident : PkId | String,
               money : TradingSystem::Money?,
               stop : TradingSystem::TradeStop? = nil)
        name = validate_name!(name)
        security_ident = validate_security_ident!(security_ident)
        @ref = Core::Utils.ref(name)
        validate_create(name)
        security = Exchange::Security.new(@conn_db, security_ident) # raise if not found
        state = TradeState.new(
          name: name.capitalize,
          money: money,
          stop: stop,
          security_id: security.id
        )
        trade_id = @repo.insert!(state)
        App.info(key: "trade.create.success",
          params: {:ref => ref})
        trade_id
      end

      private def validate_name!(name : String) : String
        name = Core::Input.ensure_present!(name,
          field: "name",
          key: "trade.create.invalid_name",
          kind: LowLevelError::Kind::Domain)
        Core::Input.ensure_string_valid!(name,
          field: "name",
          regex: ALPHANUM,
          key: "trade.create.invalid_name",
          kind: LowLevelError::Kind::Domain)
      end

      private def validate_security_ident!(ident : PkId | String) : PkId | String
        case ident
        in PkId
          return ident if ident > 0
        in String
          return Core::Input.ensure_isin_valid!(ident,
            field: "security",
            key: "trade.create.invalid_security_identifier",
            context: {:ref => Core::Utils.ref(ident)},
            kind: LowLevelError::Kind::Domain)
        end

        raise LowLevelError.new(
          key: "trade.create.invalid_security_identifier",
          context: {:ref => Core::Utils.ref(ident)},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      private def validate_create(name)
        sql = "SELECT EXISTS(SELECT id FROM trade WHERE name=?)"
        unless @conn_db.scalar(sql, name).as(PkId).zero?
          raise LowLevelError.new(
            key: "trade.create.name_exists",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end
    end
  end
end
