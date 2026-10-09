module Jedi
  module MarketData
    class QuoteRepository
      PRICE_TOLERANCE          = 0.001
      FLOAT_COMPARISON_EPSILON = 1e-12

      getter conn : DB::Connection

      def initialize(@conn : DB::Connection)
      end

      def history(
        isin : String,
        selection : HistorySelection = HistorySelection.new,
      ) : Array(Quote)
        quotes = if selection.date_filter?
                   operator = selection.date_operator.not_nil!.sql
                   date_value = self.class.date_to_i(selection.date.not_nil!)

                   read_quotes(
                     <<-SQL,
                       SELECT date, open, high, low, close, volume
                       FROM quotes
                       WHERE isin = ? AND date #{operator} ?
                       ORDER BY date
                     SQL
                     isin,
                     date_value
                   )
                 else
                   read_quotes(
                     <<-SQL,
                       SELECT date, open, high, low, close, volume
                       FROM quotes
                       WHERE isin = ?
                       ORDER BY date
                     SQL
                     isin
                   )
                 end

        if records = selection.records
          Core::Collection.select_records(quotes, records)
        else
          quotes
        end
      rescue ex : LowLevelError
        enrich_error!(ex, isin)
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot load quotation history for '#{isin}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:isin => isin},
          cause: ex
        )
      end

      def latest_closes : Hash(String, Tuple(Time, Float64))
        result = {} of String => Tuple(Time, Float64)

        conn.query(
          <<-SQL
            SELECT q.isin, q.date, q.close
            FROM quotes AS q
            INNER JOIN (
              SELECT isin, MAX(date) AS date
              FROM quotes
              GROUP BY isin
            ) AS latest ON latest.isin = q.isin AND latest.date = q.date
          SQL
        ) do |rs|
          rs.each do
            isin = rs.read(String)
            date = self.class.date_from_i(rs.read(Int64))
            close = rs.read(Float64)
            result[isin] = {date, close}
          end
        end

        result
      rescue ex
        raise LowLevelError.new(
          "cannot load latest market quotations: #{ex.message || ex.class.name}",
          cause: ex
        )
      end

      # Most recent market-session dates of one dataset, bounded by the given
      # reference date. Dates later than its validated freshness are ignored.
      def recent_trading_dates_for_dataset(
        dataset_code : String,
        through : Time,
        limit : Int32,
      ) : Array(Time)
        dates = [] of Time

        conn.query(
          <<-SQL,
            SELECT DISTINCT date
            FROM quote_datasets
            WHERE dataset_code = ? AND date <= ?
            ORDER BY date DESC
            LIMIT ?
          SQL
          dataset_code,
          self.class.date_to_i(through),
          limit
        ) do |rs|
          rs.each do
            dates << self.class.date_from_i(rs.read(Int64))
          end
        end

        dates.reverse!
        dates
      rescue ex
        raise LowLevelError.new(
          "cannot load recent quotation dates for dataset '#{dataset_code}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:dataset_code => dataset_code},
          cause: ex
        )
      end

      def find(isin : String, date : Time) : Quote?
        read_quotes(
          <<-SQL,
            SELECT date, open, high, low, close, volume
            FROM quotes
            WHERE isin = ? AND date = ?
          SQL
          isin,
          self.class.date_to_i(date)
        ).first?
      rescue ex : LowLevelError
        enrich_error!(ex, isin)
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot find quotation '#{isin}' at #{date.to_s("%F")}: " \
          "#{ex.message || ex.class.name}",
          log_context: {
            :isin => isin,
            :date => date.to_s("%F"),
          },
          cause: ex
        )
      end

      def insert(isin : String, quote : Quote) : Nil
        conn.exec(
          <<-SQL,
            INSERT INTO quotes(isin, date, open, high, low, close, volume)
            VALUES (?, ?, ?, ?, ?, ?, ?)
          SQL
          isin,
          self.class.date_to_i(quote[:date]),
          quote[:open],
          quote[:high],
          quote[:low],
          quote[:close],
          quote[:volume]
        )
      rescue ex
        raise LowLevelError.new(
          "cannot insert quotation '#{isin}' at " \
          "#{quote[:date].to_s("%F")}: #{ex.message || ex.class.name}",
          log_context: {
            :isin => isin,
            :date => quote[:date].to_s("%F"),
          },
          cause: ex
        )
      end

      def link_dataset(
        dataset_code : String,
        isin : String,
        date : Time,
      ) : Bool
        conn.exec(
          <<-SQL,
            INSERT OR IGNORE INTO quote_datasets(dataset_code, isin, date)
            VALUES (?, ?, ?)
          SQL
          dataset_code,
          isin,
          self.class.date_to_i(date)
        ).rows_affected > 0
      rescue ex
        raise LowLevelError.new(
          "cannot link quotation '#{isin}' at #{date.to_s("%F")} " \
          "to dataset '#{dataset_code}': #{ex.message || ex.class.name}",
          log_context: {
            :dataset_code => dataset_code,
            :isin         => isin,
            :date         => date.to_s("%F"),
          },
          cause: ex
        )
      end

      def link_to_security_datasets(isin : String, date : Time) : Int64
        conn.exec(
          <<-SQL,
            INSERT OR IGNORE INTO quote_datasets(dataset_code, isin, date)
            SELECT dataset_code, ?, ?
            FROM security_datasets
            WHERE isin = ?
          SQL
          isin,
          self.class.date_to_i(date),
          isin
        ).rows_affected
      rescue ex
        raise LowLevelError.new(
          "cannot link quotation '#{isin}' at #{date.to_s("%F")} " \
          "to its datasets: #{ex.message || ex.class.name}",
          log_context: {
            :isin => isin,
            :date => date.to_s("%F"),
          },
          cause: ex
        )
      end

      def delete_history(isin : String) : Int64
        conn.exec(
          "DELETE FROM quotes WHERE isin = ?",
          isin
        ).rows_affected
      rescue ex
        raise LowLevelError.new(
          "cannot delete quotation history for '#{isin}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:isin => isin},
          cause: ex
        )
      end

      def delete_unlinked : Int64
        conn.exec(
          <<-SQL
            DELETE FROM quotes
            WHERE NOT EXISTS (
              SELECT 1
              FROM quote_datasets
              WHERE quote_datasets.isin = quotes.isin
                AND quote_datasets.date = quotes.date
            )
          SQL
        ).rows_affected
      rescue ex
        raise LowLevelError.new(
          "cannot delete unlinked quotations: #{ex.message || ex.class.name}",
          cause: ex
        )
      end

      def count : Int64
        conn.query_one("SELECT COUNT(*) FROM quotes", as: Int64)
      rescue ex
        raise LowLevelError.new(
          "cannot count market quotations: #{ex.message || ex.class.name}",
          cause: ex
        )
      end

      def count_for_dataset(dataset_code : String) : Int64
        conn.query_one(
          <<-SQL,
            SELECT COUNT(*)
            FROM quote_datasets
            WHERE dataset_code = ?
          SQL
          dataset_code,
          as: Int64
        )
      rescue ex
        raise LowLevelError.new(
          "cannot count quotations for dataset '#{dataset_code}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:dataset_code => dataset_code},
          cause: ex
        )
      end

      def date_range_for_dataset(
        dataset_code : String,
      ) : Tuple(Time?, Time?)
        first = nil.as(Time?)
        last = nil.as(Time?)

        conn.query(
          <<-SQL,
            SELECT MIN(date), MAX(date)
            FROM quote_datasets
            WHERE dataset_code = ?
          SQL
          dataset_code
        ) do |rs|
          rs.each do
            first = stored_date(rs.read(Int64?))
            last = stored_date(rs.read(Int64?))
          end
        end

        {first, last}
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot read quotation period for dataset '#{dataset_code}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:dataset_code => dataset_code},
          cause: ex
        )
      end

      def first_date_after(
        dataset_code : String,
        date : Time,
      ) : Time?
        value = nil.as(Time?)

        conn.query(
          <<-SQL,
            SELECT MIN(date)
            FROM quote_datasets
            WHERE dataset_code = ? AND date > ?
          SQL
          dataset_code,
          self.class.date_to_i(date)
        ) do |rs|
          rs.each do
            value = stored_date(rs.read(Int64?))
          end
        end

        value
      rescue ex : LowLevelError
        raise ex
      rescue ex
        raise LowLevelError.new(
          "cannot find first quotation after #{date.to_s("%F")} " \
          "for dataset '#{dataset_code}': #{ex.message || ex.class.name}",
          log_context: {
            :dataset_code => dataset_code,
            :date         => date.to_s("%F"),
          },
          cause: ex
        )
      end

      def self.same?(left : Quote, right : Quote) : Bool
        left[:date] == right[:date] &&
          price_same?(left[:open], right[:open]) &&
          price_same?(left[:high], right[:high]) &&
          price_same?(left[:low], right[:low]) &&
          price_same?(left[:close], right[:close]) &&
          left[:volume] == right[:volume]
      end

      private def self.price_same?(left : Float64, right : Float64) : Bool
        (left - right).abs <= PRICE_TOLERANCE + FLOAT_COMPARISON_EPSILON
      end

      def self.date_to_i(date : Time) : Int32
        date.year * 10_000 + date.month * 100 + date.day
      end

      def self.date_from_i(value : Int64 | Int32) : Time
        integer = value.to_i32
        year = integer // 10_000
        month = integer // 100 % 100
        day = integer % 100
        Time.utc(year, month, day)
      rescue ex
        raise LowLevelError.new(
          "invalid SQL quotation date '#{value}': " \
          "#{ex.message || ex.class.name}",
          log_context: {:date_value => value.to_s},
          cause: ex
        )
      end

      private def read_quotes(sql : String, *params) : Array(Quote)
        quotes = [] of Quote

        conn.query(sql, *params) do |rs|
          rs.each do
            quotes << {
              date:   self.class.date_from_i(rs.read(Int64)),
              open:   rs.read(Float64),
              high:   rs.read(Float64),
              low:    rs.read(Float64),
              close:  rs.read(Float64),
              volume: rs.read(Int64),
            }
          end
        end

        quotes
      end

      private def stored_date(value : Int64?) : Time?
        value.try { |item| self.class.date_from_i(item) }
      end

      private def enrich_error!(ex : LowLevelError, isin : String) : Nil
        ex.log_context[:isin] = isin unless ex.log_context.has_key?(:isin)
      end
    end
  end
end
