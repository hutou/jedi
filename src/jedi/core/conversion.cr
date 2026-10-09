module Jedi
  module Core
    # Conversions de dates, valeurs numériques et pourcentages.
    module Conversion
      # common method checking if value present
      def self.check_value(value : String?, name : String? = nil) : String
        if value.nil? || value.strip.empty?
          if name
            raise LowLevelError.new("'#{name}' is nil or empty.",
              key: "infra.nil_or_empty_value_for_name",
              context: {:name => name},
              log_backtrace: false,
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          else
            raise LowLevelError.new("Nil or empty value",
              key: "infra.nil_or_empty_value",
              log_backtrace: false,
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
        else
          value.as(String)
        end
      end

      # --------------------------------------------------------------------
      #                       Date & Time converters
      # --------------------------------------------------------------------
      def self.datetime(date : String?, time : String?) : Time
        Time.parse_local("#{date} #{time}", "%Y-%m-%d %H:%M:%S")
      rescue ex
        raise LowLevelError.new("Invalid date '#{date}' or time '#{time}'",
          key: "infra.invalid_datetime",
          context: {:date => "#{date}", :time => "#{time}"},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      def self.old_datetime(date : String?, time : String?) : Time
        if (date_value = check_value(date, "date")) =~ /^\d{4}-\d{2}-\d{2}$/ &&
           (time_value = check_value(time, "time")) =~ /^\d{2}:\d{2}:\d{2}$/
          Time.parse("#{date_value} #{time_value}", DATETIME_FIELDS, Time::Location.local)
        else
          raise LowLevelError.new("Invalid date '#{date}' or time '#{time}'",
            key: "infra.invalid_datetime",
            context: {:date => "#{date}", :time => "#{time}"},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)}
          )
        end
      end

      def self.date(date : String?) : Time
        if (date_value = check_value(date, "date")) =~ /^\d{4}-\d{2}-\d{2}$/
          Time.parse(date_value, DATE_FORMAT, Time::Location.local)
        else
          raise LowLevelError.new("infra.invalid_date",
            context: {:date => "#{date}"},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end

      def self.operation_type(type : String) : TradingLife::Operation::Type
        TradingLife::Operation::Type.parse(type)
      rescue
        raise LowLevelError.new(
          # "Unrecognized operation type '#{type}'",
          key: "infra.invalid_operation_type",
          context: {:type => type},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      def self.operation_mode(mode : String) : TradingLife::Operation::Mode
        TradingLife::Operation::Mode.parse(mode)
      rescue
        raise LowLevelError.new(
          # "Unrecognized operation mode '#{mode}'",
          key: "infra.invalid_operation_mode",
          context: {:mode => mode},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      # --------------------------------------------------------------------
      #                       Numericals
      # --------------------------------------------------------------------
      def self.read_decimal(value : String?, name : String? = nil) : Float64
        if (value = check_value(value, name)) =~ /^[+-]?\d+\.?\d*$/
          value.to_f
        else
          if name
            raise LowLevelError.new("Invalid decimal value '#{value}' for name '#{name}'",
              key: "infra.invalid_decimal_value_for_name",
              context: {:value => "#{value}", :name => name},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          else
            raise LowLevelError.new("Invalid decimal value '#{value}'",
              key: "infra.invalid_decimal_value",
              context: {:value => "#{value}"},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
        end
      end

      def self.read_integer(value : String?, name : String? = nil) : Int32
        if (value = check_value(value, name)) =~ /^[+-]?\d+$/
          value.to_i
        else
          if name
            raise LowLevelError.new("Invalid integer value '#{value}' for '#{name}'",
              key: "infra.invalid_integer_value_for_name",
              context: {:value => "#{value}", :name => name},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          else
            raise LowLevelError.new("Invalid integer value '#{value}'",
              key: "infra.invalid_integer_value",
              context: {:value => "#{value}"},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
        end
      end

      def self.read_decimal_pct(value : String?, name : String? = nil) : Float64
        if (v = value) && v.ends_with?("%")
          read_decimal(v.chomp('%'), name) / 100
        else
          read_decimal(v, name)
        end
      end
    end
  end
end
