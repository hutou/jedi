module Jedi
  module Exchange
    # In case of a split, quantity is returned as a float
    # so that q0 and c0 in settings can be properly adjusted
    class Security
      class Split
        @after : Int32 = 0
        @before : Int32 = 0
        @splitable : Bool = false

        # Primary constructor
        def initialize(split : String)
          if /^[1-9]\d*#{CSEP}[1-9]\d*$/.match(split)
            @after, @before = split.split(/:/).map &.to_i
          elsif /^n#{CSEP}[1-9]\d*,p#{CSEP}[1-9]\d*$/.match(split)
            @after, @before = split.split(",").map { |n| n.split(CSEP)[1].to_i }
          end

          if @after.zero? || @before.zero? || @after == @before
            raise LowLevelError.new(
              key: "split.invalid_value",
              context: {:split => split},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          else
            @splitable = true
          end
        end

        # recalc quantity
        def quantity(q)
          return q unless @splitable
          q / @before * @after
        end

        # recalc price
        def price(p)
          return p unless @splitable
          p / @after * @before
        end

        # Split display string
        def to_s(*, format = false)
          String.build { |io| to_s(io, format: format) }
        end

        def to_s(io : IO, *, format = false)
          if @splitable
            if format
              io << "n:" << @after << ",p:" << @before
            else
              io << @after << ":" << @before
            end
          else
            ""
          end
        end
      end
    end
  end
end
