module Jedi
  module MarketData
    enum DateOperator
      Ge
      Gt
      Le
      Lt

      def sql : String
        case self
        in Ge then ">="
        in Gt then ">"
        in Le then "<="
        in Lt then "<"
        end
      end
    end

    # Selection applied to one quotation history.
    #
    # Date selection is applied first, then record selection, exactly as in the
    # former Tools::QuoteHistory implementation.
    class HistorySelection
      DATE_PATTERN = /\A\d{4}-\d{2}-\d{2}\z/

      getter records : String?
      getter date_operator : DateOperator?
      getter date : Time?

      def initialize(
        @records : String? = nil,
        @date_operator : DateOperator? = nil,
        @date : Time? = nil,
      )
      end

      def self.from_options(
        option_records : String? = nil,
        option_date : String? = nil,
      ) : self
        return new(records: option_records) if option_date.nil?
        date_option = option_date.as(String)

        parts = date_option.split(':', 2)
        unless parts.size == 2
          raise LowLevelError.new(
            "invalid date selection '#{date_option}'",
            key: "tools.quote_history.option_date_invalid",
            context: {:value => date_option},
            kind: LowLevelError::Kind::UserInput,
            log_context: {
              :value  => date_option,
              :source => Core::Utils.source(__FILE__, __LINE__),
            }
          )
        end

        operator_text = parts[0].strip.downcase
        date_text = parts[1].strip

        operator = parse_operator(operator_text)
        date = parse_date(date_text)

        new(
          records: option_records,
          date_operator: operator,
          date: date
        )
      end

      def apply(quotes : Array(Quote)) : Array(Quote)
        selected = apply_date(quotes)

        if records = @records
          Core::Collection.select_records(selected, records)
        else
          selected
        end
      end

      def apply_date(quotes : Array(Quote)) : Array(Quote)
        operator = @date_operator
        selected_date = @date
        return quotes if operator.nil? || selected_date.nil?

        operator = operator.not_nil!
        selected_date = selected_date.not_nil!

        case operator
        in DateOperator::Ge
          quotes.select { |quote| quote[:date] >= selected_date }
        in DateOperator::Gt
          quotes.select { |quote| quote[:date] > selected_date }
        in DateOperator::Le
          quotes.select { |quote| quote[:date] <= selected_date }
        in DateOperator::Lt
          quotes.select { |quote| quote[:date] < selected_date }
        end
      end

      def date_filter? : Bool
        !date_operator.nil? && !date.nil?
      end

      private def self.parse_operator(value : String) : DateOperator
        case value
        when "ge" then DateOperator::Ge
        when "gt" then DateOperator::Gt
        when "le" then DateOperator::Le
        when "lt" then DateOperator::Lt
        else
          raise LowLevelError.new(
            "invalid date operator '#{value}'",
            key: "tools.quote_history.date_operator_invalid",
            context: {:operator => value},
            kind: LowLevelError::Kind::UserInput,
            log_context: {
              :operator => value,
              :source   => Core::Utils.source(__FILE__, __LINE__),
            }
          )
        end
      end

      private def self.parse_date(value : String) : Time
        unless value.matches?(DATE_PATTERN)
          raise LowLevelError.new(
            "invalid date selection '#{value}'",
            key: "tools.quote_history.date_selection_invalid",
            context: {:date => value},
            kind: LowLevelError::Kind::UserInput,
            log_context: {
              :date   => value,
              :source => Core::Utils.source(__FILE__, __LINE__),
            }
          )
        end

        layout = DateLayout.new(
          DateOrder::Ymd,
          DateSeparator::Dash,
          YearWidth::Four
        )

        DateParser.new(layout).parse(value)
      rescue ex : LowLevelError
        raise ex if ex.key

        raise LowLevelError.new(
          "invalid date selection '#{value}'",
          key: "tools.quote_history.date_selection_invalid",
          context: {:date => value},
          kind: LowLevelError::Kind::UserInput,
          log_context: {
            :date   => value,
            :source => Core::Utils.source(__FILE__, __LINE__),
          },
          cause: ex
        )
      end
    end
  end
end
