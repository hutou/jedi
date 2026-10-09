module Jedi
  module Core
    module Input
      #
      # --------------------- ensure_valid methods -----------------------
      #

      def self.ensure_argv_empty!
        unless ARGV.empty?
          raise LowLevelError.new("unexpected argument(s) '#{ARGV.join(" ")}'",
            key: "infra.unexpected_arguments",
            context: {:args => "#{ARGV.join(" ")}"},
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end

      def self.ensure_present!(
        value : String?,
        *,
        key : String = "infra.field_not_set",
        context : Hash(Symbol, String) = Hash(Symbol, String).new,
        field : String? = nil,
        kind : LowLevelError::Kind = LowLevelError::Kind::UserInput,
      ) : String
        stripped = value.try(&.strip)

        if stripped.nil? || stripped.empty?
          if (x = field).nil? || x.empty?
            msg = "The field has no value."
          else
            msg = "The field '#{x}' has no value."
            context = context.merge({:field => "#{x}"})
          end
          raise LowLevelError.new(msg,
            key: key,
            kind: kind,
            context: context,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        stripped
      end

      def self.ensure_string_valid!(
        value : String?,
        *,
        key : String,
        context : Hash(Symbol, String) = Hash(Symbol, String).new,
        field : String? = nil,
        regex : Regex? = nil,
        kind : LowLevelError::Kind = LowLevelError::Kind::UserInput,
      ) : String
        value = Core::Input.ensure_present!(value, field: field)

        if regex && value !~ /#{regex}/
          raise LowLevelError.new("The field's content '#{value}' is not valid for '#{field}', regex condition is /#{regex}/.",
            key: key,
            kind: kind,
            context: context.merge({:field => "#{field}"}),
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        value
      end

      def self.ensure_decimal_pct_valid!(value, *, field : String? = nil,
                                         regex : Regex = NON_NEGATIVE_DECIMAL_PCT) : Float64
        value = Core::Input.ensure_string_valid!(value, field: field,
          regex: regex, key: "infra.field_required")
        value.ends_with?('%') ? value.chomp('%').to_f / 100 : value.to_f
      end

      def self.ensure_decimal_valid!(value, *, field : String? = nil,
                                     regex : Regex = NON_NEGATIVE_DECIMAL) : Float64
        value = Core::Input.ensure_string_valid!(value, field: field,
          regex: regex, key: "infra.field_required")
        value.to_f
      end

      def self.ensure_integer_valid!(value, *, field : String? = nil,
                                     regex : Regex = NON_NEGATIVE_INTEGER) : Int32
        value = Core::Input.ensure_string_valid!(value, field: field,
          regex: regex, key: "infra.field_required")
        value.to_i
      end

      def self.ensure_date_valid!(
        value : String?,
        *,
        key : String,
        context : Hash(Symbol, String) = Hash(Symbol, String).new,
        field : String? = nil,
        kind : LowLevelError::Kind = LowLevelError::Kind::UserInput,
      ) : Time
        value = Core::Input.ensure_present!(value, field: field)
        unless value =~ /\A\d{4}-\d{2}-\d{2}\z/
          raise LowLevelError.new(
            key: "infra.invalid_date_format",
            kind: kind,
            context: context.merge({:field => "#{field}"}),
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        format = "%Y-%m-%d"
        Time.parse(value, format, Time::Location::UTC)
      rescue ex : LowLevelError
        raise ex
      rescue ex : Exception
        raise LowLevelError.new("The field's content '#{value}' is not valid for '#{field}', format condition is '#{format}'.",
          key: key,
          kind: kind,
          context: context.merge({:field => "#{field}"}),
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          cause: ex
        )
      end

      def self.ensure_time_valid!(
        value : String?,
        *,
        key : String,
        context : Hash(Symbol, String) = Hash(Symbol, String).new,
        field : String? = nil,
        kind : LowLevelError::Kind = LowLevelError::Kind::UserInput,
      ) : Time
        value = Core::Input.ensure_present!(value, field: field)
        unless value =~ /\A\d{2}:\d{2}:\d{2}\z/
          raise LowLevelError.new(
            key: "infra.invalid_time_format",
            kind: kind,
            context: context.merge({:field => "#{field}"}),
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        format = "%H:%M:%S"
        Time.parse(value, format, Time::Location::UTC)
      rescue ex : LowLevelError
        raise ex
      rescue ex : Exception
        raise LowLevelError.new("The field's content '#{value}' is not valid for '#{field}', format condition is '#{format}'.",
          key: key,
          kind: kind,
          context: context.merge({:field => "#{field}"}),
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          cause: ex
        )
      end

      def self.ensure_operation_type_valid!(
        value : String?,
        *,
        key : String,
        context : Hash(Symbol, String) = Hash(Symbol, String).new,
        kind : LowLevelError::Kind = LowLevelError::Kind::UserInput,
        field : String? = nil,
      ) : TradingLife::Operation::Type
        value = Core::Input.ensure_present!(value, field: field)

        TradingLife::Operation::Type.parse(value)
      rescue ex : Exception
        raise LowLevelError.new("The field's content '#{value}' is not valid for '#{field}'.",
          key: key,
          kind: kind,
          context: context.merge({:field => field}),
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
        )
      end

      def self.ensure_operation_mode_valid!(
        value : String?,
        *,
        key : String,
        context : Hash(Symbol, String) = Hash(Symbol, String).new,
        kind : LowLevelError::Kind = LowLevelError::Kind::UserInput,
        field : String? = nil,
      ) : TradingLife::Operation::Mode
        value = Core::Input.ensure_present!(value, field: field)

        TradingLife::Operation::Mode.parse(value)
      rescue ex : Exception
        raise LowLevelError.new("The field's content '#{value}' is not valid for '#{field}'.",
          key: key,
          kind: kind,
          context: context.merge({:field => field}),
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
        )
      end

      def self.ensure_isin_valid!(
        value : String?,
        *,
        key : String,
        context : Hash(Symbol, String) = Hash(Symbol, String).new,
        field : String? = nil,
        kind : LowLevelError::Kind = LowLevelError::Kind::UserInput,
      ) : String
        value = Core::Input.ensure_present!(value, field: field)
        valid = false
        if (isin = value.strip.upcase).size == 12 &&
           isin.gsub(/[^A-Z0-9]/, "").size == 12
          # 1. Convertir les lettres en nombres (A=10, B=11, ..., Z=35)
          digits_str = String.build do |io|
            isin.each_char do |char|
              if char >= 'A' && char <= 'Z'
                io << (char.ord - 'A'.ord + 10)
              else
                io << char
              end
            end
          end
          # 2. Appliquer l'algorithme de Luhn de droite à gauche
          sum = 0
          double = false
          digits_str.chars.reverse_each do |char|
            val = char.to_i(10)
            if double
              val *= 2
              val = (val / 10).to_i + (val % 10) if val > 9
            end
            sum += val
            double = !double
          end
          # 3. Valide si le total est un multiple de 10
          valid = sum % 10 == 0
        end
        if valid
          isin
        else
          raise LowLevelError.new("The field's content '#{value}' is not valid for '#{field}'.",
            key: key,
            kind: kind,
            context: context.merge({:field => field}),
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
      end

      # Ensure ARGV.size if between min..max inclusive
      # or ARGV.size >= min if max is nil
      # otherwise raise
      # return ARGV.size
      def self.ensure_argument_count!(
        min : Int32,
        max : Int32?,
        *,
        key : String,
        context : Hash(Symbol, String) = Hash(Symbol, String).new,
      ) : Int32
        unless (min..max).includes?(ARGV.size) ||
               (ARGV.size >= min && max.nil?)
          count = if min == max
                    "#{min}"
                  elsif max.nil?
                    ">= #{min}"
                  else
                    "#{min}..#{max}"
                  end
          raise LowLevelError.new("Argument count must be #{count}.",
            key: key,
            context: {:count => count},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        ARGV.size
      end

      #
      # --------------------- decode methods -----------------------
      #
      # Decodes a key=value (or key:value) list string into an array of
      # "key=value" tokens, re-joining values that contain the separator.
      # Example: "a=1,2,3, b=4" with sep='=' → ["a=1,2,3", "b=4"]
      # ESEP = '=' (E as Equal)
      # CSEP = ':' (C as Colon)

      def self.kv_decode(str : String, sep : Char = ESEP) : Array(String)?
        result = [] of String

        str.gsub(/[\s,]+/, ",").split(",").each do |item|
          if item.index(sep)
            result << item
          elsif result.empty?
            raise LowLevelError.new(
              "cannot decode key/value list '#{str}': " \
              "value '#{item}' has no preceding key",
              log_context: {
                :source => Core::Utils.source(__FILE__, __LINE__),
              }
            )
          else
            result[-1] += "," + item
          end
        end

        result
      end

      # Decode a command strings into a hash of key, value
      # Values is a string to select column indexes
      # example:
      # "or1-5,9,12bd0" --> {'o' => "", 'r' => "1-5,9,12", 'b' => "", 'd' => "0"}
      def self.decode_commands(commands)
        cmds = commands.gsub(/ /, "")
        (indexes = cmds.split(/[A-Za-z]/)).shift
        letters = cmds.gsub(/[^A-Za-z]/, "")
        commands = {} of Char => String
        letters.each_char_with_index do |c, i|
          commands[c] = indexes[i].chomp(',')
        end
        commands
      end

      # Traduit le value de decode_commands en syntaxe propre à Tablo::Table.column_indexes
      # "1-5,9,12" --> {[{1, 5}, 9, 12], false}
      # "1-5,12,9" --> {[{1, 5}, 12, 9], true} : with columns reordering
      def self.parse_column_indexes(indexes : String, max_index : Int32)
        aridx = [] of Int32 | Tuple(Int32, Int32)
        err = nil
        indexes.gsub(/ /, "").split(",").each do |col|
          if col =~ /\A\d+-\d+\z/
            b, e = col.split("-").map &.to_i
            if (b > max_index) || (e > max_index)
              err = col
              break
            end
            aridx << {b, e}
          elsif col =~ /\A\d+\z/
            v = col.to_i
            if v > max_index
              err = col
              break
            end
            aridx << v
          else
            err = col
            break
          end
        end
        raise LowLevelError.new("infra.invalid_column_index",
          context: {:col => err},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)}) if err
        x = aridx.map { |e| e.is_a?(Int32) ? e : e.to_a }.flatten
        reordered = (x == x.sort) ? false : true
        {aridx, reordered}
      end
    end
  end
end
