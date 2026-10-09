module Jedi
  module TradingRules
    # Class intended for the management of the position in the trade
    # Position is defined by :
    # - the number of level jumps, up and down ones
    # - the current step
    class Position # Immutable
      protected getter x, y
      getter e

      # Primary constructor, with given coordinates as integers
      def initialize(@x : Int32, @y : Int32, @e : Int32)
        if @x < 0 || @y < 0
          raise LowLevelError.new(
            "Position: Level jump values must be positive (x=#{@x}, y=#{@y})",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
      end

      # Secondary constructor (arg = formatted position)
      def self.new(str : String)
        s = str.gsub(/ /, "").downcase
        if s.match /^x#{CSEP}(?<x>\d{1,2}),y#{CSEP}(?<y>\d{1,2}),e#{CSEP}(?<e>[-+]?\d{1,2})$/
          # x:?,y:?,e:?
          x = $~["x"].to_i
          y = $~["y"].to_i
          e = $~["e"].to_i
        elsif s.match /^(?<x>\d{1,2})#{CSEP}(?<y>\d{1,2})#{CSEP}(?<e>[-+]?\d{1,2})$/
          # ?:?:?
          x = $~["x"].to_i
          y = $~["y"].to_i
          e = $~["e"].to_i
        else
          raise LowLevelError.new(
            "Position: Invalid format (#{str})",
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        new(x, y, e)
      end

      # Test wether 2 positions are equal (same coordinates)
      def ==(other : self)
        other.x == x &&
          other.y == y &&
          other.e == e
      end

      def to_s(*, format = false)
        String.build { |io| to_s(io, format: format) }
      end

      # Display a formatted position
      def to_s(io : IO, *, format = false)
        if format
          io << "x:" << @x
          io << ",y:" << @y
          io << ",e:" << (@e == 0 ? " " : (@e > 0 ? "+" : "")) << @e
        else
          io << @x << ":" << @y << ":" <<
            (@e == 0 ? " " : (@e > 0 ? "+" : "")) << @e
        end
      end

      # Output position coordiantes as a tuple
      def coords
        {@x, @y, @e}
      end

      # Test wether a level jump occured between two positions
      def jump?(other : Position)
        @x != other.x || @y != other.y
      end

      # Set x and y jump counters to 0, but keep current step value
      def reset_jumps
        Position.new(0, 0, @e)
      end

      # Moves the position up one step, activating a level jump if necessary
      def upmove(emax)
        position = Position.new(@x, @y, @e + 1)
        if position.e >= emax
          position = Position.new(@x + 1, @y, 0)
        end
        position
      end

      # Moves the position down one step, activating a level jump if necessary
      def downmove(emin)
        position = Position.new(@x, @y, @e - 1)
        if position.e <= emin
          position = Position.new(@x, @y + 1, 0)
        end
        position
      end
    end
  end
end
