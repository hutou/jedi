module Jedi
  module TradingRules
    # Console presentation of a scale. It contains no persistence or mutation.
    class ScalePresenter
      def initialize(@scale : Scale)
      end

      def show : Nil
        puts table
      end

      def table
        source = [scale]
        result = Tablo::Table.new(
          source,
          header_alignment: Tablo::Justify::Left,
          body_alignment: Tablo::Justify::Left,
          title: title) do |table|
          add_identity_columns(table) unless scale.literal?
          add_operational_columns(table)
        end

        result.transpose(
          field_names_header_alignment: Tablo::Justify::Right,
          field_names_body_alignment: Tablo::Justify::Right,
          field_names_header: I18n.t("scale.show.transpose.fields"),
          field_names_width: nil,
          body_headers: I18n.t("scale.show.transpose.contents"),
          row_divider_frequency: 1,
          wrap_mode: Tablo::WrapMode::Rune).pack
      end

      def self.format_definition(definition : String, width : Int32, header : String = "") : String
        parts = definition.split(", ")

        String.build do |io|
          line_width = 0
          parts.each_with_index do |part, index|
            if index.zero?
              io << header << part
              line_width = part.size
            elsif line_width > width || line_width + part.size > width
              io << '\n' << " " * header.size << part
              line_width = part.size
            else
              io << ", " << part
              line_width += part.size
            end
          end
        end
      end

      def self.show_one(operational : Scale::Operational) : String
        String.build do |io|
          io << I18n.t("scale.show.type_one.ki")
          io << Core::Utils.to_pct(operational.ki)
          io << " (#{operational.ki})\n"
          io << I18n.t("scale.show.type_one.kb") << operational.kb
          io << (operational.kb == TradingRules::Kb::Pwr ? " (0)" : " (1)") << "\n\n"
          io << I18n.t("scale.show.type_one.step_header") << '\n'

          operational.kclist.keys.sort! { |left, right| right <=> left }.each do |step|
            if step == operational.emax
              io << "%4s:%3d %23.2f\n" % ["emax", operational.emax, operational.kc(operational.emax)]
            elsif step == operational.emin
              io << "%4s:%3d %23.2f" % ["emin", operational.emin, operational.kc(operational.emin)]
            else
              io << "%4s %3d %23.2f %23.2f\n" % ["", step, operational.kc(step), operational.ks(step)]
            end
          end
        end.gsub(' ', '\u{a0}')
      end

      def self.show_two(operational : Scale::Operational) : String
        String.build do |io|
          io << I18n.t("scale.show.type_two.ki")
          io << Core::Utils.to_pct(operational.ki)
          io << " (#{operational.ki})\n"
          io << I18n.t("scale.show.type_two.kb") << operational.kb
          io << (operational.kb == TradingRules::Kb::Pwr ? " (0)" : " (1)") << "\n\n"
          io << I18n.t("scale.show.type_two.vr")
          io << Core::Utils.to_pct(operational.vr)
          io << " (#{operational.vr})\n\n"
          io << I18n.t("scale.show.type_two.step_header") << '\n'
          io << "%4s:%3d\n" % ["emax", operational.emax]

          operational.kslist.keys.sort! { |left, right| right <=> left }.each do |step|
            io << "%4s %3d %26.2f\n" % ["", step, operational.ks(step)]
          end

          io << "%4s:%3d" % ["emin", operational.emin]
        end.gsub(' ', '\u{a0}')
      end

      private getter scale

      private def title : Tablo::Heading
        text = if scale.literal?
                 I18n.t("scale.show.title_literal")
               else
                 I18n.t("scale.show.title", id: scale.id.to_s)
               end
        Tablo::Heading.new(text, framed: true)
      end

      private def add_identity_columns(table) : Nil
        table.add_column(I18n.t("scale.show.table.id"), &.id)
        table.add_column(I18n.t("scale.show.table.name"), &.name)
        table.add_column(I18n.t("scale.show.table.comment"), &.comment)
      end

      private def add_operational_columns(table) : Nil
        operational = scale.operational

        table.add_column(I18n.t("scale.show.table.type")) do |item|
          I18n.t("scale.operational.type.#{item.operational.type.to_s.downcase}")
        end
        table.add_column(I18n.t("scale.show.table.optimized")) do |item|
          item.operational.optimized? ? I18n.t("infra.yes") : I18n.t("infra.no")
        end
        if operational.builder != operational.definition
          table.add_column(I18n.t("scale.show.table.builder"), &.operational.builder)
        end
        table.add_column(I18n.t("scale.show.table.definition")) do |item|
          self.class.format_definition(item.operational.definition, 60)
        end

        developed_label = I18n.t("scale.show.table.developped")
        case operational.type
        in Scale::Operational::Type::One
          table.add_column(developed_label) { |item| self.class.show_one(item.operational) }
        in Scale::Operational::Type::Two
          table.add_column(developed_label) { |item| self.class.show_two(item.operational) }
        end
      end
    end
  end
end
