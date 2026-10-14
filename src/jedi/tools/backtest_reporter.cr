module Jedi
  module Tools
    class BacktestReporter
      getter conn_memory : DB::Connection
      getter result : BacktestResult

      def initialize(@conn_memory : DB::Connection, @result : BacktestResult)
      end

      def render(commands : Hash(Char, String), *, technical : Bool = false) : String
        sections = [] of String

        commands.each do |key, columns|
          value = render_command(key, columns, technical)
          sections << value unless value.empty?
        end

        sections.join("\n\n")
      end

      private def render_command(key : Char, columns : String, technical : Bool) : String
        selected_columns = columns.empty? ? nil : columns

        case key
        when 'T'
          TradingSystem::TradeLister.new(conn_memory).call(
            option_extended: true,
            option_columns: selected_columns,
          )
        when 't'
          TradingSystem::TradeLister.new(conn_memory).call(
            option_columns: selected_columns,
          )
        when 'K'
          Exchange::SecurityLister.new(conn_memory).call(
            option_extended: true,
            option_columns: selected_columns,
          )
        when 'k'
          Exchange::SecurityLister.new(conn_memory).call(
            option_columns: selected_columns,
          )
        when 'S'
          TradingRules::ScaleLister.new(conn_memory).call(
            option_extended: true,
            option_columns: selected_columns,
          )
        when 's'
          TradingRules::ScaleLister.new(conn_memory).call(
            option_columns: selected_columns,
          )
        when 'c'
          TradingSystem::SettingsLister.new(conn_memory).call(
            option_columns: selected_columns,
          )
        when 'o'
          TradingLife::OperationLister.new(conn_memory).call(
            option_columns: selected_columns,
          )
        when 'r'
          technical ? summary_table.to_s : BacktestCompactReporter.new(result).render
        when 'f'
          if result.trade_count.zero?
            I18n.t("tools.backtest.no_trade_opened")
          else
            TradingSystem::TradeResults.new(conn_memory).list(
              option_update_now: false,
              option_chronological: true,
              option_global_maximum_investment: result.maximum_investment_cents,
            )
          end
        when 'd'
          TradingSystem::TradeOrders.new(conn_memory).list(
            option_net_stop: false,
            option_update_now: false,
          )
        when 'p'
          BacktestPlotter.new(result).plot
          ""
        else
          raise LowLevelError.new(
            "unknown backtest output '#{key}'",
            key: "tools.backtest.unknown_output",
            kind: LowLevelError::Kind::UserInput,
            context: {:output => key.to_s},
            log_context: {
              :output => key.to_s,
              :source => Core::Utils.source(__FILE__, __LINE__),
            },
          )
        end
      end

      private def summary_table
        title = I18n.t("tools.backtest.table.title")
        table = Tablo::Table.new(
          [1],
          title: Tablo::Heading.new(title, framed: true),
        ) do |t|
          t.add_column(I18n.t("tools.backtest.table.headers.ident")) {
            format_cell_ident
          }
          t.add_column(I18n.t("tools.backtest.table.headers.dates_duration")) {
            format_cell_dates
          }
          # definition = result.scale.format_definition(50)
          definition = TradingRules::ScalePresenter.format_definition(result.scale.operational.definition, 50)
          newlines = "\n" * definition.lines.size
          t.add_column(
            I18n.t("tools.backtest.table.headers.scale") + newlines +
            I18n.t("tools.backtest.table.headers.operations"),
          ) { format_cell_operations }
          t.add_column(I18n.t("tools.backtest.table.headers.linear_regression")) {
            format_cell_linear_regression
          }
          t.add_column(I18n.t("tools.backtest.table.headers.sizing")) {
            format_cell_sizing
          }
          t.add_column(I18n.t("tools.backtest.table.headers.execution")) {
            format_cell_execution
          }
          t.add_column(I18n.t("tools.backtest.table.headers.results")) {
            format_cell_financial_results
          }
        end.pack.transpose(
          field_names_header_alignment: Tablo::Justify::Right,
          field_names_body_alignment: Tablo::Justify::Right,
          field_names_header: "",
          field_names_width: 16,
          body_headers: "",
          row_divider_frequency: 1,
          masked_headers: true,
          wrap_mode: Tablo::WrapMode::Rune,
        ).pack
        table
      end

      private def format_cell_ident : String
        history = result.quote_history
        String.build do |io|
          io << "%12s - %-s" % [history.isin, history.name] << "\n"
          io << I18n.t("tools.backtest.table.cell_ident.daily_volatility") %
                [result.indicators.volatility * 100.0] << "\n"
          io << I18n.t("tools.backtest.table.cell_ident.tick_value") %
                [history.tick]
        end
      end

      private def format_cell_dates : String
        history = result.quote_history
        first_operation = result.first_operation_date
        last_operation = result.last_operation_date
        format = "%-12s %-15s %-15s"
        no_break_space = " "

        String.build do |io|
          io << format % [
            no_break_space,
            I18n.t("tools.backtest.table.cell_dates.start"),
            I18n.t("tools.backtest.table.cell_dates.end"),
          ] << "\n"
          io << format % [
            I18n.t("tools.backtest.table.cell_dates.quotations"),
            history.date_first.to_s("%d-%m-%Y"),
            history.date_last.to_s("%d-%m-%Y"),
          ] << "\n"
          io << format % [
            I18n.t("tools.backtest.table.cell_dates.operations"),
            first_operation.nil? ? "" : first_operation.to_s("%d-%m-%Y"),
            last_operation.nil? ? "" : last_operation.to_s("%d-%m-%Y"),
          ] << "\n"
          io << I18n.t("tools.backtest.table.cell_dates.days") % [
            result.simulation_trading_day_count,
            result.num_calendar_days,
          ] << "\n"
          io << I18n.t("tools.backtest.table.cell_dates.days_explained")

          density = result.quotation_density
          unless 0.68 < density && density < 0.71
            io << "\n" << I18n.t("tools.backtest.table.cell_dates.quotation_missing")
          end
        end.gsub(' ', '\u{a0}')
      end

      private def format_cell_operations : String
        String.build do |io|
          io << TradingRules::ScalePresenter.format_definition(result.scale.operational.definition, 50)
            .gsub(' ', '\u{a0}') << "\n"
          # io << result.scale
          #   .format_definition(50, result.scale.name + ": ")
          #   .gsub(' ', '\u{a0}') << "\n"
          io << I18n.t("tools.backtest.table.cell_operations.trades") %
                [result.trade_count] << "\n"
          io << I18n.t("tools.backtest.table.cell_operations.count") %
                [result.operation_count] << "\n"
          io << I18n.t("tools.backtest.table.cell_operations.average") %
                [result.average_operations_per_month] << "\n"
          timeline = result.timeline
          start = [timeline.size - 48, 0].max
          io << timeline[start, timeline.size - start] << "\n"
          io << I18n.t("tools.backtest.table.cell_operations.last_months")
        end
      end

      private def format_cell_linear_regression : String
        indicators = result.indicators
        String.build do |io|
          io << I18n.t("tools.backtest.table.cell_regression.slope_price") % [
            indicators.regression_slope,
          ] << "\n"
          io << I18n.t(
            "tools.backtest.table.cell_regression.slope_normalized",
          ) % [indicators.normalized_regression_slope_percent] << "\n"
          io << I18n.t("tools.backtest.table.cell_regression.intercept") % [
            indicators.regression_intercept,
          ] << "\n"
          io << I18n.t("tools.backtest.table.cell_regression.correlation") %
                [indicators.correlation_coefficient] << "\n"
          io << I18n.t("tools.backtest.table.cell_regression.determination") %
                [indicators.determination_coefficient]
        end
      end

      private def format_cell_sizing : String
        case policy = result.sizing_policy
        when FixedAmountSizingPolicy
          I18n.t("tools.backtest.table.cell_sizing.fixed") % [policy.amount]
        when CapitalSizingPolicy
          sizing = result.first_accepted_sizing.try(&.position_sizing)

          String.build do |io|
            io << I18n.t("tools.backtest.table.cell_sizing.capital") % [
              policy.capital,
            ] << "\n"
            io << I18n.t("tools.backtest.table.cell_sizing.risk") % [
              policy.risk_rate * 100.0,
              policy.stop_steps,
            ] << "\n"
            io << I18n.t("tools.backtest.table.cell_sizing.operability") % [
              policy.minimum_quantity,
              policy.operability_steps,
            ] << "\n"
            io << I18n.t("tools.backtest.table.cell_sizing.openings") % [
              result.accepted_sizing_events.size,
              result.opening_rejection_count,
            ]

            if result.opening_rejection_count > 0
              first = result.first_opening_rejection_date.not_nil!
              last = result.last_opening_rejection_date.not_nil!
              io << "\n" << I18n.t(
                "tools.backtest.table.cell_sizing.rejection_period",
              ) % [first.to_s("%d-%m-%Y"), last.to_s("%d-%m-%Y")]
            end

            unless sizing.nil?
              io << "\n" << I18n.t(
                "tools.backtest.table.cell_sizing.first_quantity",
              ) % [sizing.quantity, sizing.initial_amount]
              io << "\n" << I18n.t(
                "tools.backtest.table.cell_sizing.stop",
              ) % [sizing.stop_price, sizing.risk_distance * 100.0]
              io << "\n" << I18n.t(
                "tools.backtest.table.cell_sizing.projected_investment",
              ) % [sizing.maximum_projected_investment]
            end
          end
        else
          ""
        end
      end

      private def format_cell_execution : String
        policy = result.execution_policy
        mode_key = if policy.mode.conservative?
                     "tools.backtest.table.cell_execution.conservative"
                   else
                     "tools.backtest.table.cell_execution.legacy"
                   end
        opening_key = if policy.opening_day.next_session?
                        "tools.backtest.table.cell_execution.next_session"
                      else
                        "tools.backtest.table.cell_execution.same_session"
                      end

        String.build do |io|
          io << I18n.t(mode_key) << "\n"
          io << I18n.t(opening_key) << "\n"
          io << I18n.t("tools.backtest.table.cell_execution.events") % [
            result.conflict_execution_count,
            result.gap_execution_count,
          ]

          if result.opening_day_execution_count > 0
            io << "\n" << I18n.t(
              "tools.backtest.table.cell_execution.opening_day_executions",
            ) % [result.opening_day_execution_count]
          end
        end
      end

      private def format_cell_financial_results : String
        String.build do |io|
          io << I18n.t("tools.backtest.table.cell_results.cumulative_gain") % [
            result.gross_gain_cents / 100.0,
            result.net_gain_cents / 100.0,
          ] << "\n"
          io << I18n.t(
            "tools.backtest.table.cell_results.return_on_maximum",
          ) % [
            result.gross_return_on_maximum_investment,
            result.net_return_on_maximum_investment,
          ] << "\n"
          io << I18n.t(
            "tools.backtest.table.cell_results.annualized_return",
          ) % [
            result.gross_annualized_return,
            result.net_annualized_return,
          ] << "\n"
          io << I18n.t("tools.backtest.table.cell_results.investment") % [
            result.current_investment_cents / 100.0,
            result.maximum_investment_cents / 100.0,
            result.current_investment_to_maximum_percent,
          ]

          if utilization = result.capital_utilization_percent
            io << "\n" << I18n.t(
              "tools.backtest.table.cell_results.capital_utilization",
            ) % [utilization]
          end

          io << "\n" << I18n.t(
            "tools.backtest.table.cell_results.position",
          ) % [result.final_position]
        end
      end
    end
  end
end
