module Jedi
  module Tools
    class Calc
      enum Direction
        Up   =  1
        Down = -1
      end

      @raw_c0 : String? = nil
      getter! c0 : Float64

      @raw_q0 : String? = nil
      getter! q0 : Int32

      @raw_position : String? = nil
      getter! position : TradingRules::Position

      @raw_scale : String? = nil
      getter! scale : TradingRules::Scale::Operational

      @raw_dir : String? = nil
      getter! dir : Int32

      @raw_tick : String? = nil
      getter! tick : Float64

      @raw_stock : String? = nil
      getter! stock : Int32

      @context = {} of String => Hash(String, String)
      @order = [] of String
      @given = [] of String

      def initialize(@conn_main : DB::Connection,
                     @conn_memory : DB::Connection)
        init_memory_schema
      end

      def run(key : String,
              argv : Array(String))
        args = [] of String
        @context.clear
        @order.clear
        unless argv.empty?
          argv.each do |arg|
            begin
              args += Core::Input.kv_decode(arg)
            rescue ex
              raise LowLevelError.new(
                "invalid calc argument '#{arg}'",
                key: "tools.calc.invalid_format",
                kind: LowLevelError::Kind::UserInput,
                context: {:arg => arg},
                log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
                cause: ex,
              )
            end
          end
        end
        args.each do |arg|
          k, v = arg.split("=", 2)
          case k
          when "q0"
            @raw_q0 = v
          when "c0"
            @raw_c0 = v
          when "position"
            @raw_position = v
          when "scale"
            @raw_scale = v
          when "dir"
            @raw_dir = v
          when "tick"
            @raw_tick = v
          when "stock"
            @raw_stock = v
          else
            raise LowLevelError.new(
              "unknown calc parameter '#{k}'",
              key: "tools.calc.unknown_parameter",
              kind: LowLevelError::Kind::UserInput,
              context: {:arg => k},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            )
          end
          @given << arg
        end
        # scale is mandatory for all cases
        if (x = @raw_scale).nil?
          raise LowLevelError.new(
            "missing calc scale",
            key: "tools.calc.missing_scale",
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        # barème = barème existant ou constructeur,
        # si constructeur non valide, exception via ScaleCreator !
        sc = Helpers.scale(@conn_main, @conn_memory, x)
        if sc.operational.type.two?
          raise LowLevelError.new(
            "unsupported scale type for tools calc",
            key: "tools.calc.unsupported_scale_type",
            kind: LowLevelError::Kind::Domain,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        @scale = sc.operational
        @given.delete("scale=#{@raw_scale}")

        # and also position
        if (x = @raw_position).nil?
          raise LowLevelError.new(
            "missing calc position",
            key: "tools.calc.missing_position",
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        @position = TradingRules::Position.new(x)
        @given.delete("position=#{@raw_position}")

        unless position.e < scale.emax && position.e > scale.emin
          raise LowLevelError.new(
            "calc position '#{position}' is outside the scale",
            key: "tools.calc.incompatible_position",
            context: {:position => position.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end

        case key
        when "kcb"      then calc_kcb
        when "kcp"      then calc_kcp
        when "ksp"      then calc_ksp
        when "spe"      then calc_spe
        when "cpe"      then calc_cpe
        when "price"    then calc_price
        when "quantity" then calc_quantity
        else
          raise LowLevelError.new(
            "unknown calc function '#{key}'",
            key: "tools.calc.unknown_function",
            kind: LowLevelError::Kind::UserInput,
            context: {:key => key},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        display_context
      end

      def calc_kcb
        value = case scale.kb
                in TradingRules::Kb::Pwr
                  calculation = "(1 + ki)ˣ⁻ʸ"
                  (1 + scale.ki) ** (position.x - position.y)
                in TradingRules::Kb::Mtp
                  calculation = "(1 + ki)ˣ × (1 - ki)ʸ"
                  (1 + scale.ki) ** position.x * (1 - scale.ki) ** position.y
                end.round(12)
        @context["kcb"] = {
          "value"          => "#{calculation} = #{value}",
          "ki = scale.ki"  => "#{scale.ki}",
          "kb = scale.kb"  => "#{scale.kb.value}",
          "x = position.x" => "#{position.x}",
          "y = position.y" => "#{position.y}",
        }
        @order << "kcb"
        value
      end

      def calc_kcp
        value = (scale.kc(scale.emax) ** position.x * scale.kc(scale.emin) ** position.y).round(12)
        calculation = "kc_emaxˣ × kc_eminʸ"
        @context["kcp"] = {
          "value"                          => "#{calculation} = #{value}",
          "scale.emax"                     => "#{scale.emax}",
          "kc_emax = scale.kc(scale.emax)" => "#{scale.kc(scale.emax)}",
          "x = position.x"                 => "#{position.x}",
          "scale.emin"                     => "#{scale.emin}",
          "kc_emin = scale.kc(scale.emin)" => "#{scale.kc(scale.emin)}",
          "y = position.y"                 => "#{position.y}",
        }
        @order << "kcp"
        value
      end

      def calc_ksp
        value = (calc_kcb / calc_kcp).round(12)
        calculation = "kcb ÷ kcp"
        @context["ksp"] = {
          "value" => "#{calculation} = #{value}",
        }
        @order << "ksp"
        value
      end

      private def calc_spe
        @q0 = Core::Input.ensure_integer_valid!(@raw_q0, field: "q0")
        @given.delete("q0=#{@raw_q0}")
        ksp = calc_ksp
        value = (q0 * ksp * scale.ks(position.e)).round(12)
        calculation = "q0 × ksp × ksₑ"
        @context["spe"] = {
          "value"                      => "#{calculation} = #{value}",
          "q0"                         => "#{q0}",
          "ksp"                        => "#{ksp}",
          "e = position.e"             => "#{position.e}",
          "ksₑ = scale.ks(position.e)" => "#{scale.ks(position.e)}",
        }
        @order << "spe"
        value
      end

      def calc_cpe
        @c0 = Core::Input.ensure_decimal_valid!(@raw_c0, field: "c0")
        @given.delete("c0=#{@raw_c0}")
        value = (c0 * calc_kcp * scale.kc(position.e)).round(12)
        calculation = "c0 × kcp × kcₑ"
        @context["cpe"] = {
          "value"             => "#{calculation} = #{value}",
          "c0"                => "#{c0}",
          "kcp"               => "#{calc_kcp}",
          "e = position.e"    => "#{position.e}",
          "kcₑ = scale.kc(e)" => "#{scale.kc(position.e)}",
        }
        @order << "cpe"
        value
      end

      def calc_price
        @dir = expect_dir
        @given.delete("dir=#{@raw_dir}")
        case dir
        when 1 # up, sell or buy
          calculation = "round_up(cpe)"
          value = round_up
        when -1 # down, buy or sell
          calculation = "round_down(cpe)"
          value = round_down
        end
        @context["price"] = {
          "value" => "#{calculation} = #{value}",
          "cpe"   => "#{calc_cpe}",
        }
        @order << "price"
        value
      end

      def calc_quantity
        @stock = Core::Input.ensure_integer_valid!(@raw_stock, field: "stock")
        @given.delete("stock=#{@raw_stock}")
        calculation = "round(spe) - stock)"
        value = calc_spe.round.to_i - stock
        @context["quantity"] = {
          "value"      => "#{calculation} = #{value}",
          "round(spe)" => "#{calc_spe.round.to_i}",
          "stock"      => "#{stock}",
        }
        @order << "quantity"
        value
      end

      # TODO
      # 2) Vérifier que les formules de calcul du tick sont bien correctes
      #    --> avec play d'une part
      #    --> avec la logique ci-dessous d'autre part
      #         Implementation of 2 tick values : tick_buy and tick_sell
      #         As their names say, tick_buy applies for buys and tick_sell for sells, but...
      #
      #         | type and mode of orders:
      #         | Sell Limit  |   Buy Stop            ==> Higher than jedi price) ==> up orders
      #         |--^----------+----^-----------------> price calculated by jedi (full precision)
      #         | Sell Stop   |   Buy Limit           ==> Lower than jedi price   ==> down orders
      #            ^               ^
      #            |               |
      #            |               +-----------------> use tick_buy
      #            +---------------------------------> use tick_sell
      # TODO

      def round_up
        @tick = expect_tick
        @given.delete("tick=#{@raw_tick}")
        calculation = "round((ceil(cpe ÷ tick) × tick), floor(-log10(tick)))"
        value = ((calc_cpe / tick).ceil * tick).round(-Math.log10(tick).floor)
        @context["round_up"] = {
          "value" => "#{calculation} = #{value}",
          "cpe"   => "#{calc_cpe}",
          "tick"  => "#{tick}",
          "dir"   => "#{dir}",
        }
        @order << "round_up"
        value
      end

      def round_down
        @tick = expect_tick
        @given.delete("tick=#{@raw_tick}")
        calculation = "round((floor(cpe ÷ tick) × tick), floor(-log10(tick)))"
        value = ((calc_cpe / tick).floor * tick).round(-Math.log10(tick).floor)
        @context["round_down"] = {
          "value" => "#{calculation} = #{value}",
          "cpe"   => "#{calc_cpe}",
          "tick"  => "#{tick}",
          "dir"   => "#{dir}",
        }
        @order << "round_down"
        value
      end

      private def display_context
        title = I18n.t("tools.calc.title")
        String.build do |io|
          io << title << "\n"
          io << "=" * title.size << "\n\n"
          @order.uniq.reverse.each do |key|
            io << key << " = " # << "\n"
            @context[key].each_with_index do |(k1, v1), i|
              if i == 0
                io << v1 << "\n"
              else
                io << "  " << k1 << " = " << v1 << "\n"
              end
            end
          end
          unless @given.empty?
            io << "\n" << I18n.t("tools.calc.unused_arguments").colorize(COLOR_WARN) << "\n"
            @given.each do |arg|
              io << "  " << arg << "\n"
            end
          end
        end
      end

      private def expect_dir
        if (x = @raw_dir).nil?
          raise LowLevelError.new(
            "missing calc price direction",
            key: "tools.calc.missing_price_direction",
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        else
          if (y = Direction.parse?(x)).nil?
            raise LowLevelError.new(
              "invalid calc price direction '#{x}'",
              key: "tools.calc.invalid_price_direction",
              kind: LowLevelError::Kind::UserInput,
              context: {:dir => x},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          else
            y.value
          end
        end
      end

      #
      #
      # TODO I am here !!!
      #
      #

      private def expect_tick
        if (x = @raw_tick).nil?
          raise LowLevelError.new(
            "missing calc security tick",
            key: "tools.calc.missing_tick",
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        Exchange::Security::Tick.new(x).value
      end

      private def init_memory_schema
        Database::Main.new(@conn_memory).create_table_scale
      end
    end
  end
end
