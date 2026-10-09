require "./candidate_evaluation"

module Jedi
  module Tools
    # Mechanical evaluation of one candidate security. A registered Jedi
    # Security is optional when an explicit current price is supplied.
    # No historical quotation database is required.
    class CandidateEvaluator
      private record ResolvedPrice,
        value : Float64,
        source : CandidatePriceSource,
        date : Time? = nil

      def initialize(
        @conn_main : DB::Connection,
        @conn_memory : DB::Connection,
      )
        init_memory_schema
      end

      def call(
        *,
        isin : String,
        price : Float64? = nil,
        scaledef : String,
        amount : Float64?,
        money : TradingSystem::Money?,
        capital : Float64?,
        minimum_quantity : Int32 = TradingSystem::OrderEngine::WARNING_QUANTITY_THRESHOLD,
        operability_steps : Int32 = App.diagnostic_steps,
      ) : CandidateEvaluation
        validate_mode!(amount, money)
        if capital && (!capital.finite? || capital <= 0.0)
          raise LowLevelError.new(
            key: "tools.candidate.invalid_capital",
            kind: LowLevelError::Kind::UserInput,
            context: {:capital => capital.to_s},
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        normalized_isin = Core::Input.ensure_isin_valid!(
          isin,
          field: "isin",
          key: "infra.field_required",
        )
        security = resolve_security(normalized_isin)
        quotation = resolve_price!(normalized_isin, security, price)
        candidate_price = quotation.value
        scale = Helpers.scale(@conn_main, @conn_memory, scaledef, announce: false)
        sizer = PositionSizer.new(scale.operational)
        useful_directions = Array.new(
          operability_steps,
          TradingRules::Direction::UpWard,
        )
        portfolio_capital = capital || App.dedicated_capital

        if active_money = money
          if !portfolio_capital.finite? || portfolio_capital <= 0.0
            raise LowLevelError.new(
              key: "tools.candidate.invalid_capital",
              kind: LowLevelError::Kind::UserInput,
              context: {:capital => portfolio_capital.to_s},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            )
          end

          sizing = sizer.calculate(
            capital: portfolio_capital,
            risk_rate: active_money.risk_rate,
            entry_price: candidate_price,
            stop_steps: active_money.steps_down,
            minimum_quantity: minimum_quantity,
            useful_directions: useful_directions,
          )
          target_amount = sizing.risk_amount / sizing.risk_distance
          failure = sizing.failure.nil? ? nil : CandidateFailure::CapitalSizing
          funding = funding_for(
            portfolio_capital,
            sizing.quantity,
            candidate_price,
            scale.operational,
            active_money,
          )

          CandidateEvaluation.new(
            isin: normalized_isin,
            security: security,
            scale: scale,
            price: candidate_price,
            mode: CandidateSizingMode::Capital,
            target_amount: target_amount,
            quantity: sizing.quantity,
            opening_amount: sizing.initial_amount,
            minimum_operable_quantity: sizing.minimum_operable_quantity,
            operability_steps: operability_steps,
            minimum_quantity: minimum_quantity,
            failure: failure,
            capital: portfolio_capital,
            money: active_money,
            position_sizing: sizing,
            funding: funding,
            price_source: quotation.source,
            price_date: quotation.date,
          )
        else
          target_amount = amount.not_nil!
          if !target_amount.finite? || target_amount <= 0.0
            raise LowLevelError.new(
              key: "tools.candidate.invalid_amount",
              kind: LowLevelError::Kind::UserInput,
              context: {:amount => target_amount.to_s},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            )
          end

          quantity = (target_amount / candidate_price).floor.to_i
          minimum_operable_quantity = sizer.minimum_operable_quantity(
            entry_price: candidate_price,
            minimum_quantity: minimum_quantity,
            useful_directions: useful_directions,
          )
          failure = if quantity <= 0
                      CandidateFailure::InitialQuantityZero
                    elsif quantity < minimum_operable_quantity
                      CandidateFailure::InsufficientOperability
                    end
          funding = if portfolio_capital > 0.0
                      funding_for(
                        portfolio_capital,
                        quantity,
                        candidate_price,
                        scale.operational,
                        nil,
                      )
                    end

          CandidateEvaluation.new(
            isin: normalized_isin,
            security: security,
            scale: scale,
            price: candidate_price,
            mode: CandidateSizingMode::FixedAmount,
            target_amount: target_amount,
            quantity: quantity,
            opening_amount: quantity * candidate_price,
            minimum_operable_quantity: minimum_operable_quantity,
            operability_steps: operability_steps,
            minimum_quantity: minimum_quantity,
            failure: failure,
            capital: portfolio_capital > 0.0 ? portfolio_capital : nil,
            funding: funding,
            price_source: quotation.source,
            price_date: quotation.date,
          )
        end
      end

      private def init_memory_schema : Nil
        Database::Main.new(@conn_memory).create_table_scale
      end

      private def funding_for(
        portfolio_capital : Float64,
        quantity : Int32,
        price : Float64,
        scale : TradingRules::Scale::Operational,
        money : TradingSystem::Money?,
      ) : CandidateFunding
        CandidateFundingEvaluator.new(@conn_main).call(
          portfolio_capital: portfolio_capital,
          candidate_quantity: quantity,
          candidate_price: price,
          candidate_scale: scale,
          candidate_money: money,
        )
      end

      private def validate_mode!(
        amount : Float64?,
        money : TradingSystem::Money?,
      ) : Nil
        if amount && money
          raise LowLevelError.new(
            key: "tools.candidate.amount_money_conflict",
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
        if amount.nil? && money.nil?
          raise LowLevelError.new(
            key: "tools.candidate.sizing_required",
            kind: LowLevelError::Kind::UserInput,
            log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
          )
        end
      end

      private def resolve_security(isin : String) : Exchange::Security?
        sql = "SELECT EXISTS(SELECT id FROM security WHERE isin=?)"
        return nil if @conn_main.scalar(sql, isin).as(PkId).zero?
        Exchange::Security.new(@conn_main, isin)
      end

      private def resolve_price!(
        isin : String,
        security : Exchange::Security?,
        explicit_price : Float64?,
      ) : ResolvedPrice
        unless explicit_price.nil?
          if !explicit_price.finite? || explicit_price <= 0.0
            raise LowLevelError.new(
              key: "tools.candidate.invalid_price",
              kind: LowLevelError::Kind::UserInput,
              context: {:price => explicit_price.to_s},
              log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
            )
          end
          return ResolvedPrice.new(explicit_price, CandidatePriceSource::Explicit)
        end

        if security
          stored_price = security.quotation_price
          if stored_price && stored_price.finite? && stored_price > 0.0
            return ResolvedPrice.new(stored_price, CandidatePriceSource::Stored, security.quotation_date)
          end
        end

        raise LowLevelError.new(
          key: "tools.candidate.price_required",
          kind: LowLevelError::Kind::UserInput,
          context: {:ref => isin},
          log_context: {:source => Core::Utils.source(__FILE__, __LINE__)},
        )
      end
    end
  end
end
