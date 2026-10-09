module Jedi
  module Tools
    record CandidateTradeFunding,
      trade_id : PkId,
      trade_name : String,
      current_investment : Float64,
      maximum_investment : Float64,
      reserve : Float64,
      step_limit : Int32

    class CandidateFunding
      getter portfolio_capital : Float64
      getter current_global_investment : Float64
      getter available_before_reserve : Float64
      getter running_trade_count : Int32
      getter existing_trade_reserve : Float64
      getter available_after_reserve : Float64
      getter candidate_reserve : Float64
      getter candidate_requirement : Float64
      getter margin_after_candidate : Float64
      getter candidate_step_limit : Int32
      getter trade_reserves : Array(CandidateTradeFunding)

      def initialize(
        @portfolio_capital : Float64,
        @current_global_investment : Float64,
        @available_before_reserve : Float64,
        @running_trade_count : Int32,
        @existing_trade_reserve : Float64,
        @available_after_reserve : Float64,
        @candidate_reserve : Float64,
        @candidate_requirement : Float64,
        @margin_after_candidate : Float64,
        @candidate_step_limit : Int32,
        @trade_reserves : Array(CandidateTradeFunding),
      )
      end

      def financeable? : Bool
        candidate_requirement > 0.0 && margin_after_candidate >= 0.0
      end
    end

    # Computes the capital which must remain available for current trades and
    # for a proposed candidate. Each reserve is the maximum additional net
    # investment reachable over the operational horizon. Both upward and
    # downward trajectories are explored; no special case is needed for
    # optimized scales. Fees are excluded.
    class CandidateFundingEvaluator
      def initialize(@conn_main : DB::Connection)
      end

      def call(
        *,
        portfolio_capital : Float64,
        candidate_quantity : Int32,
        candidate_price : Float64,
        candidate_scale : TradingRules::Scale::Operational,
        candidate_money : TradingSystem::Money?,
      ) : CandidateFunding
        validate_capital!(portfolio_capital)

        current_global_investment = latest_global_investment
        trade_reserves = [] of CandidateTradeFunding
        running_trade_count = 0
        existing_trade_reserve = 0.0

        TradingSystem::Trades.new(@conn_main).fetch.each do |trade|
          operation = trade.last_operation
          next if operation.nil? || operation.stock <= 0

          running_trade_count += 1
          step_limit = funding_steps(trade.money)
          projection = FundingProjector.new(step_limit).trade(trade)
          existing_trade_reserve += projection.reserve
          trade_reserves << CandidateTradeFunding.new(
            trade_id: trade.id,
            trade_name: trade.name,
            current_investment: projection.current_investment,
            maximum_investment: projection.maximum_investment,
            reserve: projection.reserve,
            step_limit: step_limit,
          )
        end

        available_before_reserve = portfolio_capital - current_global_investment
        available_after_reserve = available_before_reserve - existing_trade_reserve

        candidate_step_limit = funding_steps(candidate_money)
        candidate_projection = FundingProjector.new(candidate_step_limit).candidate(
          scale: candidate_scale,
          quantity: candidate_quantity,
          price: candidate_price,
        )
        opening_amount = candidate_projection.current_investment
        candidate_reserve = candidate_projection.reserve
        candidate_requirement = opening_amount + candidate_reserve
        margin_after_candidate = available_after_reserve - candidate_requirement

        CandidateFunding.new(
          portfolio_capital: portfolio_capital,
          current_global_investment: current_global_investment,
          available_before_reserve: available_before_reserve,
          running_trade_count: running_trade_count,
          existing_trade_reserve: existing_trade_reserve,
          available_after_reserve: available_after_reserve,
          candidate_reserve: candidate_reserve,
          candidate_requirement: candidate_requirement,
          margin_after_candidate: margin_after_candidate,
          candidate_step_limit: candidate_step_limit,
          trade_reserves: trade_reserves,
        )
      end

      private def latest_global_investment : Float64
        cents = @conn_main.query_one?(
          "SELECT global_invest FROM operation ORDER BY timestamp DESC, id DESC LIMIT 1",
          as: Int32,
        ) || 0
        cents / 100.0
      end

      private def funding_steps(money : TradingSystem::Money?) : Int32
        steps = App.diagnostic_steps
        if money && money.steps_down > steps
          steps = money.steps_down
        end
        steps
      end

      private def validate_capital!(capital : Float64) : Nil
        return if capital.finite? && capital > 0.0
        raise LowLevelError.new(
          key: "tools.candidate.invalid_capital",
          kind: LowLevelError::Kind::UserInput,
          context: {:capital => capital.to_s},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
        )
      end
    end
  end
end
