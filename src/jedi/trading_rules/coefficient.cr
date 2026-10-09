module Jedi
  module TradingRules
    enum Origin
      FromOperation
      FromOrder
      FromSettings
    end

    enum Direction
      UpWard   =  1
      None     =  0
      DownWard = -1
    end

    enum Kb
      Pwr = 0 # (1+k)^(x-y)
      Mtp = 1 # (1+k)^x * (1-k)^y
    end

    struct LastData
      getter maybe_splitted_price : Float64 = 0.0
      getter maybe_splitted_stock : Int32 = 0
      getter settings
      getter operation

      def initialize(@settings : TradingSystem::Settings,
                     @operation : TradingLife::Operation)
        @maybe_splitted_stock = @operation.stock
        @maybe_splitted_price = @operation.price
        unless @settings.split.nil?
          # In the event of a security split or reverse security split, the final stock held
          # will always be a whole value, with the allocation of rights if the
          # reverse security split is not fair (see Phaxiam Therapeutics in September 2023).
          #
          # A split must be applied if no operations were recorded since last settings,
          # as, in that case, stock from last operation would not be correct
          if @settings.operations.empty?
            @maybe_splitted_stock = @settings.split.as(Exchange::Security::Split)
              .quantity(@operation.stock).to_i
            @maybe_splitted_price = @settings.split.as(Exchange::Security::Split)
              .price(@operation.price)
          end
        end
      end
    end

    class Coefficient
      getter next_position : Position
      getter start_position : Position

      # Initializer à partir de données de Settings et Operation
      def initialize(lastdata : LastData,
                     @price_direction : TradingRules::Direction,
                     @origin : TradingRules::Origin,
                     @operation_price : Float64 = 0.0,
                     @sync : TradingRules::Position? = nil)
        # Definir ici les données utilisées dans les méthodes
        @settings_operations_count = lastdata.settings.operations.size

        @opscale = lastdata.settings.scale.operational
        @q0 = lastdata.settings.q0
        @c0 = lastdata.settings.c0
        @kcpc = lastdata.settings.kcpc
        @kspc = lastdata.settings.kspc
        @start_position = calculate_start_position(@sync, lastdata)
        @next_position = calculate_next_position(@start_position, @price_direction, @opscale)
        @price = lastdata.maybe_splitted_price
        # @price = lastdata.operation.price  : bug, corrigé ci-dessus !
        @kcp = lastdata.operation.kcp
      end

      # Initializer for simulating orders
      def initialize(@opscale : Scale::Operational,
                     @q0 : Float64,
                     @c0 : Float64,
                     @kcpc : Float64,
                     @kspc : Float64,
                     @start_position : Position,
                     @next_position : Position,
                     @price : Float64,
                     @kcp : Float64,
                     @origin : Origin,
                     @price_direction : Direction,
                     @settings_operations_count : Int32,
                     @operation_price : Float64 = 0.0,
                     @sync : Position? = nil)
      end

      # @price : price of last recorded operation
      # @operation_price : price of new operation, before saving

      private def calculate_start_position(sync, lastdata)
        case
        when !sync.nil?
          sync.as(TradingRules::Position)
        when lastdata.settings.operations.empty?
          lastdata.settings.position
        else
          lastdata.operation.position
        end
      end

      private def calculate_next_position(start_position, price_direction, opscale)
        case price_direction
        in TradingRules::Direction::UpWard
          start_position.upmove(opscale.emax)
        in TradingRules::Direction::DownWard
          start_position.downmove(opscale.emin)
        in TradingRules::Direction::None
          start_position
        end
      end

      private def kcb
        case @opscale.kb
        in Kb::Pwr
          (1 + @opscale.ki) ** (@next_position.x - @next_position.y)
        in Kb::Mtp
          (1 + @opscale.ki) ** @next_position.x * (1 - @opscale.ki) ** @next_position.y
        end
      end

      def kcp
        case @opscale.type
        in Scale::Operational::Type::One
          @opscale.kc(@opscale.emax) ** @next_position.x *
            @opscale.kc(@opscale.emin) ** @next_position.y
        in Scale::Operational::Type::Two
          if @next_position.jump?(@start_position) # occurs when new settings or level jump
            case @origin
            in TradingRules::Origin::FromOperation
              # Only when recording a new operation
              @operation_price.as(Float64) / (@c0 * @kcpc)
            in TradingRules::Origin::FromSettings
              # Only when split or sync options
              @price / (@c0 * @kcpc)
            in TradingRules::Origin::FromOrder
              #  All other cases
              cpe / (@c0 * @kcpc)
            end
          elsif @settings_operations_count.zero?
            1.0
          else
            # current one !
            @kcp
          end
        end
      end

      def ksp
        kcb / kcp
      end

      def spe
        @q0 * @kspc * ksp * @opscale.ks(@next_position.e)
      end

      def cpe
        case @opscale.type
        in Scale::Operational::Type::One
          @c0 * @kcpc * kcp * @opscale.kc(@next_position.e)
        in Scale::Operational::Type::Two
          @price * (1 + @price_direction.value * @opscale.vr)
        end
      end
    end
  end
end
