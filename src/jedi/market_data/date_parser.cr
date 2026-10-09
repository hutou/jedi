module Jedi
  module MarketData
    enum DateOrder
      Ymd
      Dmy
      Mdy
    end

    enum DateSeparator
      Slash
      Dash
      None

      def char : Char?
        case self
        in Slash then '/'
        in Dash  then '-'
        in None  then nil
        end
      end
    end

    enum YearWidth
      Two
      Four

      def size : Int32
        case self
        in Two  then 2
        in Four then 4
        end
      end
    end

    record DateLayout,
      order : DateOrder,
      separator : DateSeparator,
      year_width : YearWidth

    # Parses a date according to one previously detected layout.
    #
    # Dates are deliberately built in UTC: a market session date is a calendar
    # date, not an instant in the local timezone.
    class DateParser
      getter layout : DateLayout
      getter year_pivot : Int32

      def initialize(
        @layout : DateLayout,
        @year_pivot : Int32 = 70,
      )
        return if year_pivot.in?(0..99)

        raise LowLevelError.new(
          "year pivot must be between 0 and 99, got #{year_pivot}",
          log_context: {
            :year_pivot => year_pivot.to_s,
          }
        )
      end

      def parse(value : String) : Time
        parts = split(value)
        year, month, day = ordered_values(parts)
        year = expand_year(year) if layout.year_width.two?

        Time.utc(year, month, day)
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "invalid date '#{value}': #{ex.message || ex.class.name}",
          log_context: {
            :value  => value,
            :layout => layout.to_s,
          },
          cause: ex
        )
      end

      private def split(value : String) : Array(Int32)
        text = value.strip
        separator = layout.separator.char

        parts = if separator
                  text.split(separator).map(&.strip)
                else
                  split_compact(text)
                end

        unless parts.size == 3
          raise date_error(value, "date does not match #{layout}")
        end

        parts.map do |part|
          unless part.matches?(/\A\d+\z/)
            raise date_error(value, "date contains a non-numeric component")
          end

          begin
            part.to_i32
          rescue ex
            raise LowLevelError.new(
              "invalid numeric date component '#{part}' in '#{value}'",
              log_context: {
                :value     => value,
                :component => part,
                :layout    => layout.to_s,
              },
              cause: ex
            )
          end
        end
      end

      private def split_compact(value : String) : Array(String)
        unless value.matches?(/\A\d+\z/)
          raise date_error(value, "compact date contains a non-numeric character")
        end

        expected_size = layout.year_width.four? ? 8 : 6
        unless value.size == expected_size
          raise date_error(
            value,
            "compact date must contain #{expected_size} digits"
          )
        end

        year_size = layout.year_width.size

        case layout.order
        in DateOrder::Ymd
          [
            value[0, year_size],
            value[year_size, 2],
            value[year_size + 2, 2],
          ]
        in DateOrder::Dmy, DateOrder::Mdy
          [
            value[0, 2],
            value[2, 2],
            value[4, year_size],
          ]
        end
      end

      private def ordered_values(parts : Array(Int32)) : Tuple(Int32, Int32, Int32)
        case layout.order
        in DateOrder::Ymd
          {parts[0], parts[1], parts[2]}
        in DateOrder::Dmy
          {parts[2], parts[1], parts[0]}
        in DateOrder::Mdy
          {parts[2], parts[0], parts[1]}
        end
      end

      private def expand_year(year : Int32) : Int32
        unless year.in?(0..99)
          raise LowLevelError.new(
            "two-digit year expected, got #{year}",
            log_context: {
              :year       => year.to_s,
              :year_pivot => year_pivot.to_s,
            }
          )
        end

        year < year_pivot ? 2000 + year : 1900 + year
      end

      private def date_error(value : String, message : String) : LowLevelError
        LowLevelError.new(
          "#{message}: '#{value}'",
          log_context: {
            :value  => value,
            :layout => layout.to_s,
          }
        )
      end
    end

    # Detects one date layout for a complete file or a representative sample.
    # It never guesses between DMY and MDY when both remain possible.
    module DateFormatDetector
      extend self

      SAMPLE_SIZE = 100

      def detect(
        values : Enumerable(String),
        order : DateOrder? = nil,
        year_pivot : Int32 = 70,
      ) : DateLayout
        sample = values
          .map(&.strip)
          .reject(&.empty?)
          .first(SAMPLE_SIZE)

        if sample.empty?
          raise LowLevelError.new(
            "cannot detect a date format from an empty sample"
          )
        end

        separator = detect_separator(sample.first)
        year_width = detect_year_width(sample.first, separator)

        candidates = [] of DateLayout
        candidate_orders(order).each do |candidate_order|
          layout = DateLayout.new(candidate_order, separator, year_width)
          parser = DateParser.new(layout, year_pivot)

          candidates << layout if sample.all? { |value| valid?(parser, value) }
        end

        case candidates.size
        when 1
          candidates.first
        when 0
          raise LowLevelError.new(
            "no supported date format matches sample: #{sample.first}",
            log_context: {
              :sample       => sample.first,
              :year_pivot   => year_pivot.to_s,
              :forced_order => order.try(&.to_s) || "auto",
            }
          )
        else
          orders = candidates.map(&.order.to_s.downcase).join(", ")
          raise LowLevelError.new(
            "ambiguous date format '#{sample.first}'; possible orders: #{orders}",
            log_context: {
              :sample          => sample.first,
              :possible_orders => orders,
              :year_pivot      => year_pivot.to_s,
            }
          )
        end
      end

      private def candidate_orders(order : DateOrder?) : Array(DateOrder)
        if selected = order
          [selected]
        else
          DateOrder.values
        end
      end

      private def detect_separator(value : String) : DateSeparator
        text = value.strip

        if text.includes?('/')
          DateSeparator::Slash
        elsif text.includes?('-')
          DateSeparator::Dash
        elsif text.matches?(/\A\d+\z/)
          DateSeparator::None
        else
          raise LowLevelError.new(
            "unsupported date separator in '#{value}'",
            log_context: {:value => value}
          )
        end
      end

      private def detect_year_width(
        value : String,
        separator : DateSeparator,
      ) : YearWidth
        text = value.strip

        if separator.none?
          case text.size
          when 6 then YearWidth::Two
          when 8 then YearWidth::Four
          else
            raise LowLevelError.new(
              "compact date '#{value}' must contain 6 or 8 digits",
              log_context: {:value => value}
            )
          end
        else
          parts = text.split(separator.char.as(Char)).map(&.strip)
          unless parts.size == 3
            raise LowLevelError.new(
              "date '#{value}' must contain three components",
              log_context: {:value => value}
            )
          end

          widths = parts.map(&.size)
          if widths.includes?(4)
            YearWidth::Four
          elsif widths.all? { |width| width.in?(1..2) }
            YearWidth::Two
          else
            raise LowLevelError.new(
              "cannot determine year width in '#{value}'",
              log_context: {:value => value}
            )
          end
        end
      end

      private def valid?(parser : DateParser, value : String) : Bool
        parser.parse(value)
        true
      rescue
        false
      end
    end
  end
end
