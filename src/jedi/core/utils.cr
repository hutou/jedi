module Jedi
  module Core
    # Conversions de dates, valeurs numériques et pourcentages.
    module Utils
      extend self

      def ref(id : Int32 | Int64) : String
        I18n.t("infra.record_ref.id", {:id => id.to_s})
      end

      def ref(name : String) : String
        I18n.t("infra.record_ref.name", {:name => name.capitalize})
      end

      def to_pct(value : Float64, rnd : Int32 = 2) : String
        (value * 100).round(rnd).to_s.gsub(/\.0$/, "") + "%"
      end

      # --------------------------------------------------------------------
      #                       Misc
      # --------------------------------------------------------------------
      def source(path : String, line : Int32) : String
        path.sub(/^.*?src\//, "") + ":" + line.to_s
      end

      def to_pkid(value) : PkId
        if value =~ /^\d+$/
          value.to_i64
        else
          raise LowLevelError.new("infra.invalid_table_id",
            context: {:id => value},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end
    end
  end
end
