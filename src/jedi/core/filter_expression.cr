module Jedi
  module Core
    module FilterExpression
      extend self

      record FilterTerm,
        field_name : String?,
        regex : Regex

      alias AndGroup = Array(FilterTerm)
      alias FilterTree = Array(AndGroup)

      def compile(filter : String?, allowed_fields : Enumerable(String)) : FilterTree?
        return nil if filter.nil?

        source = filter.strip
        return nil if source.empty?

        allowed = allowed_fields.map(&.downcase).to_set

        or_parts = source.split("||").map(&.strip).reject(&.empty?)
        return nil if or_parts.empty?

        or_parts.map do |or_part|
          and_parts = or_part.split("&&").map(&.strip).reject(&.empty?)
          if and_parts.empty?
            raise LowLevelError.new("Invalid filter expression",
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
          and_parts.map do |part|
            compile_term(part, allowed)
          end
        end
      rescue ex : LowLevelError
        raise LowLevelError.new(
          key: "infra.invalid_regex",
          context: {:regex => source.to_s},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          cause: ex)
      end

      def matches?(
        tree : FilterTree?,
        all_fields_text : String,
        named_fields : Hash(String, Array(String)),
      ) : Bool
        return true unless tree

        normalized_fields = {} of String => Array(String)
        named_fields.each do |name, values|
          normalized_fields[name.downcase] = values
        end

        tree.any? do |and_group|
          and_group.all? do |term|
            if field_name = term.field_name
              values = normalized_fields[field_name]?
              values && values.any? { |value| term.regex.matches?(value) }
            else
              term.regex.matches?(all_fields_text)
            end
          end
        end
      end

      private def compile_term(part : String, allowed : Set(String)) : FilterTerm
        field_name = nil
        regex_source = part

        if eq_index = part.index('=')
          candidate_field = part[0...eq_index].strip.downcase
          candidate_regex = part[(eq_index + 1)..].strip

          if allowed.includes?(candidate_field)
            if candidate_regex.empty?
              raise LowLevelError.new("Missing filter regex for field '#{candidate_field}'",
                log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
            end
            field_name = candidate_field
            regex_source = candidate_regex
          end
        end

        begin
          regex = Regex.new(regex_source, Regex::Options::IGNORE_CASE)
          FilterTerm.new(field_name, regex)
        rescue ex : ArgumentError
          raise LowLevelError.new("Invalid filter regex: #{regex_source}",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end
    end
  end
end
