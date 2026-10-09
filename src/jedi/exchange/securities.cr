module Jedi
  module Exchange
    class Securities
      include Enumerable(Security)

      def initialize(@conn_db : DB::Connection? = nil,
                     @items : Array(Security) = [] of Security)
      end

      private def conn_db! : DB::Connection
        @conn_db || raise LowLevelError.new(
          key: "infra.database_required",
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
      end

      def each(&)
        @items.each { |item| yield item }
      end

      def fetch(sql = "SELECT id FROM security ORDER BY id", *params) : self
        db = conn_db!
        @items.clear
        db.query(sql, *params) do |rs|
          rs.each do
            id = rs.read(PkId)
            @items << Security.new(db, id)
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

      def <<(item : Security) : self
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
