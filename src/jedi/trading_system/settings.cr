module Jedi
  module TradingSystem
    class Settings
      private getter ref = ""
      enum ReInit
        Reset
        Merge
      end
      alias Fields = NamedTuple(id: PkId, rank: Int32, timestamp: Time,
        split: String, sync: String, reinit: String, q0: Float64, c0: Float64,
        position: String, kspc: Float64, kcpc: Float64,
        trade_id: PkId, scale_id: PkId)
      @record : Fields? = nil

      def initialize(@conn_db : DB::Connection, @ident : PkId)
      end

      def id : PkId
        record[:id]
      end

      def rank : Int32
        record[:rank]
      end

      def timestamp : Time
        record[:timestamp].to_local
      end

      def split : Exchange::Security::Split?
        (x = record[:split]).empty? ? nil : Exchange::Security::Split.new(x)
      end

      def sync : TradingRules::Position?
        (x = record[:sync]).empty? ? nil : TradingRules::Position.new(x)
      end

      def reinit : TradingSystem::ReInitOption?
        (x = record[:reinit]).empty? ? nil : TradingSystem::ReInitOption.parse(x)
      end

      def q0 : Float64
        record[:q0]
      end

      def c0 : Float64
        record[:c0]
      end

      def position : TradingRules::Position?
        TradingRules::Position.new(record[:position])
      end

      def kspc : Float64
        record[:kspc]
      end

      def kcpc : Float64
        record[:kcpc]
      end

      def trade_id : PkId
        record[:trade_id]
      end

      def scale_id : PkId
        record[:scale_id]
      end

      def record : Fields
        if cached = @record
          return cached
        end
        sql = "SELECT * FROM settings WHERE id=?"
        begin
          @record = @conn_db.query_one(sql, @ident, as: Fields.types)
        rescue ex # no LowLevelError here, just <DB::NoResultsError:no results>
          # no message as first argument to LowLevelError
          # => kind = domain, no help
          # else
          # => kind = unclassified
          # If kind set to UserInput
          # => idem as domain + Help
          @ref = Core::Utils.ref(@ident)
          raise LowLevelError.new(
            key: "settings.query_failed",
            context: {:ref => ref},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            cause: ex)
        end
      end

      def trade
        Trade.new(@conn_db, trade_id)
      end

      def scale
        TradingRules::Scale.new(@conn_db, scale_id)
      end

      def operations
        sql = "SELECT id FROM operation WHERE settings_id = ? ORDER BY id"
        TradingLife::Operations.new(@conn_db).fetch(sql, @ident)
      end

      def operation_count
        sql = "SELECT COUNT(*) FROM settings A \
              JOIN operation B on A.id = B.settings_id where A.id = ?"
        @conn_db.scalar(sql, @ident).as(PkId)
      end

      def show
        Tablo::Table.new([self],
          header_alignment: Tablo::Justify::Left,
          body_alignment: Tablo::Justify::Left,
          title: Tablo::Heading.new("\n" + I18n.t("settings.show.title",
            id: "#{id}") + "\n", framed: true)) do |t|
          t.add_column(I18n.t("settings.show.id"), &.id)
          t.add_column(I18n.t("settings.show.trade"), &.trade.name)
          t.add_column(I18n.t("settings.show.scale"), &.scale.name)
          t.add_column(I18n.t("settings.show.rank"), &.rank)
          t.add_column(I18n.t("settings.show.timestamp"),
            &.timestamp.to_local)
          t.add_column(I18n.t("settings.show.split"), &.split.to_s)
          t.add_column(I18n.t("settings.show.sync"), &.sync.to_s)
          t.add_column(I18n.t("settings.show.q0"), &.q0)
          t.add_column(I18n.t("settings.show.c0"), &.c0)
          t.add_column(I18n.t("settings.show.position"), &.position.to_s)
          t.add_column(I18n.t("settings.show.kspc"), &.kspc)
          t.add_column(I18n.t("settings.show.kcpc"), &.kcpc)
        end.transpose(
          field_names_header_alignment: Tablo::Justify::Right,
          field_names_body_alignment: Tablo::Justify::Right,
          field_names_header: I18n.t("settings.show.transpose.fields"),
          field_names_width: nil,
          body_headers: I18n.t("settings.show.transpose.contents"),
          row_divider_frequency: 1,
          wrap_mode: Tablo::WrapMode::Word).pack
      end
    end
  end
end
