module Jedi
  module Core
    # Opérations sur les collections : sélection, répartition.
    module Collection
      # Selects elements from `collection` according to a selector string.
      #
      # `selected` is a comma-separated list of tokens:
      # - "F<n>" / "f<n>" → first n elements
      # - "L<n>" / "l<n>" → last n elements
      # - "<i>"            → element at 1-based index (negative = from end)
      # - "<i>:<j>"        → range from i to j (1-based, negative ok)
      #
      # Returns an array of the selected elements in order.
      # Raises `LowLevelError` on unrecognised token format.
      def self.select_records(collection, selected : String)
        indexes = [] of Int32
        max_size = collection.size

        selected.split(",").each do |token|
          case token
          when /^[FfLl][1-9]\d*$/
            letter = token[0]
            count = token[1..].to_i.clamp(1, max_size)
            range = case letter
                    when 'F', 'f' then 0...count
                    when 'L', 'l' then (max_size - count)...max_size
                    end
            indexes.concat(range.as(Range).to_a)
          when /^-?[1-9]\d*$/
            indexes << calc_index(token.to_i, max_size)
          when /^-?[1-9]\d*:-?[1-9]\d*$/
            b, e = token.split(":").map(&.to_i)
            indexes.concat((calc_index(b, max_size)..calc_index(e, max_size)).to_a)
          else
            raise LowLevelError.new(
              "invalid record selection '#{token}'",
              key: "core.collection.invalid_selection",
              context: {:selection => token},
              kind: LowLevelError::Kind::UserInput,
              log_context: {
                :selection => token,
                :source    => Core::Utils.source(__FILE__, __LINE__),
              }
            )
          end
        end

        indexes.uniq.sort.map { |idx| collection[idx] }
      end

      # 'ks' values distribution
      # Distributes a total value `v` into `n` parts with a geometric weight
      # coefficient `coef`.
      #
      # - coef = 1.0 → uniform distribution
      # - coef > 1.0 → progressive (later parts are larger)
      # - coef < 1.0 → degressive (later parts are smaller)
      def self.distribute(v : Float64, n : Int32, coef : Float64 = 1.0) : Array(Float64)
        return Array.new(n, v / n) if coef == 1.0

        weights = Array(Float64).new(n)
        sum_weights = 0.0

        n.times do |i|
          w = coef ** i
          weights << w
          sum_weights += w
        end

        weights.map { |w| v * w / sum_weights }
      end

      # Converts a 1-based (or negative end-based) index to a 0-based array index,
      # clamped to [0, max_size - 1].
      private def self.calc_index(value : Int32, max_size : Int32) : Int32
        if value < 0
          [value + max_size, 0].max
        else
          [value - 1, max_size - 1].min
        end
      end
    end
  end
end
