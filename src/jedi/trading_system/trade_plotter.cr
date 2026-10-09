module Jedi
  module TradingSystem
    class TradePlotter
      def initialize(@conn_db : DB::Connection)
      end

      def call(ident, position)
        trade = Trade.new(@conn_db, ident)
        operations = trade.operations
        if operations.size < 2
          raise LowLevelError.new(key: "trade.plot.error_too_few_operations",
            context: {:nbop => "#{operations.size}"},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
        end
        settings = operations.last.settings
        transaction_days = operations.map { |op| (op.timestamp - operations.first.timestamp).days.to_f }

        gains_losses = operations.map { |op| op.price * op.stock - op.trade_invest / 100 }
        trade_invest = operations.map { |op| op.trade_invest / 100 }

        initial_buy = settings.q0 * settings.c0
        prices_first_value = operations.first.price
        prices_reduced = operations.map { |op| op.price / prices_first_value }

        gains_losses_reduced = gains_losses.map { |value| value / initial_buy }
        trade_invest_reduced = trade_invest.map { |value| value / initial_buy }

        # <<<
        # Compute graph for elapsed time from last transaction
        elapsed_days = [
          (operations.last.timestamp - operations.first.timestamp).days.to_f,
          (Time.local - operations.first.timestamp).days.to_f,
        ]
        current_price = Exchange::QuoteResolver.new(trade.security).price.as(Float64)
        last_gain_loss_reduced = (current_price * operations.last.stock -
                                  operations.last.trade_invest / 100) / initial_buy
        current_gains_losses_reduced = [gains_losses_reduced[-1], last_gain_loss_reduced]
        current_prices_reduced = [prices_reduced[-1], current_price / prices_first_value]
        # >>>
        Cryplot.plot {
          palette(:set2)
          title("#{trade.name} - #{trade.security.isin} - #{trade.security.name}")
            .title_font_size(14).title_text_color("blue")
          xlabel(I18n.t("trade.plot.transaction_days",
            first: %(#{operations.first.timestamp.to_s("%Y-%m-%d")}),
            last: %(#{operations.last.timestamp.to_s("%Y-%m-%d")})))
          ylabel(I18n.t("trade.plot.transaction_prices"))
          case position.downcase
          when "tl"
            legend.at_top_left
          when "tr"
            legend.at_top_right
          when "bl"
            legend.at_bottom_left
          when "br"
            legend.at_bottom_right
          else
            raise LowLevelError.new(key: "trade.plot.legend_invalid_position",
              context: {:position => "#{position}"},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
          end
          grid
            .show
            .back
            .line_width(1)
          border.none
          style_fill.border_show
          tics.hide
          border.left.right.top.bottom.back
          draw_curve(transaction_days, gains_losses_reduced)
            .label(I18n.t("trade.plot.gains"))
          draw_curve(transaction_days, trade_invest_reduced)
            .label(I18n.t("trade.plot.investment"))
          draw_curve(transaction_days, prices_reduced)
            .label(I18n.t("trade.plot.prices"))
          draw_curve(elapsed_days, current_gains_losses_reduced)
            .label("").dash_type(3).line_style(1)
          draw_curve(elapsed_days, current_prices_reduced)
            .label("").dash_type(3).line_style(3)
          size(640, 480)
          if STDOUT.tty?
            save("jedi_plot.svg")
            show
          else
            outfile = "jedi_plot_#{trade.name}.svg"
            puts outfile
            save(outfile)
          end
        }
      end
    end
  end
end
