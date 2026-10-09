module Jedi
  module TradingRules
    class Scales
      include Enumerable(Scale)

      def initialize(@conn_db : DB::Connection? = nil,
                     @items : Array(Scale) = [] of Scale)
      end

      private def conn_db! : DB::Connection
        @conn_db || raise LowLevelError.new(
          key: "infra.database_required",
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      def each(&)
        @items.each { |item| yield item }
      end

      def fetch(sql = "SELECT id FROM scale ORDER BY id", *params) : self
        db = conn_db!
        @items.clear
        db.query(sql, *params) do |rs|
          rs.each do
            id = rs.read(PkId)
            @items << Scale.new(db, id)
          end
        end

        self
      end

      def to_a
        @items
      end

      def [](index : Int)
        @items[index]
      end

      def first
        @items.first
      end

      def first?
        @items.first?
      end

      def last
        @items.last
      end

      def last?
        @items.last?
      end

      def size
        @items.size
      end

      def empty?
        @items.empty?
      end

      def any?
        @items.any?
      end

      def <<(item : Scale) : self
        @items << item
        self
      end

      def clear : self
        @items.clear
        self
      end
    end
  end
end
