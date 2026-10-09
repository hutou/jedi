module Jedi
  module Tools
    class Rule
      getter conn_main, conn_memory, defscale
      getter! scale : TradingRules::Scale
      class_property number = 0

      def initialize(@conn_main : DB::Connection,
                     @conn_memory : DB::Connection,
                     @scaledef : String)
        Rule.number += 1
        @scale = get_scale(scaledef)
      end

      private def get_scale(defscale)
        scale = TradingRules::Scales.new(conn_main)
          .fetch("SELECT id FROM scale WHERE name = '#{defscale}'").first?
        if scale.nil?
          # No, probably a literal scale is given
          # store in memory db if valid
          scale_id = TradingRules::Scales.new(conn_memory).create name: "S#{Rule.number}",
            comment: "Literal", definition: defscale
        else
          # Yes, defscale is known, clone into memory db unless it is already here !
          mem_scale = TradingRules::Scales.new(conn_memory)
            .fetch("SELECT id FROM scale WHERE name = '#{defscale}'").first?
          if mem_scale.nil?
            scale_id = TradingRules::Scales.new(conn_memory).create name: scale.name,
              comment: scale.comment, definition: scale.operational.definition
          else
            scale_id = mem_scale.id
          end
        end
        TradingRules::Scale.new(conn_memory, scale_id)
      end
    end
  end
end
