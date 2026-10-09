require "../spec_helper"

private def candidate_memory_db(&)
  path = "/tmp/jedi_candidate_memory_#{Time.utc.to_unix_ns}_#{rand(1_000_000)}.db"
  conn = DB.connect("sqlite3://#{path}")
  begin
    # Deliberately keep this database empty. CandidateEvaluator must prepare
    # the in-memory scale table itself, just like the real CLI path using
    # App.conn_memory.
    yield conn
  ensure
    conn.close
    File.delete(path) if File.exists?(path)
  end
end

private def candidate_operable_scale : Jedi::TradingRules::Scale::Operational
  Jedi::TradingRules::Scale::Operational.new(
    type: Jedi::TradingRules::Scale::Operational::Type::Two,
    definition: "candidate operable type II",
    builder: "vr:10%,ks:0.6,0.8,1.2,1.5,ki:0%,kb:0",
    ks_values: {
      -2 => 1.50,
      -1 => 1.20,
       0 => 1.00,
       1 => 0.80,
       2 => 0.60,
    },
    emax: 3,
    emin: -3,
    ki: 0.0,
    kb: Jedi::TradingRules::Kb::Pwr,
    vr_value: 0.10,
  )
end

describe Jedi::Tools::CandidateEvaluator do
  it "evaluates an external candidate with an explicit price" do
    JediSpec.with_db do |main|
      JediSpec.insert_scale(main)

      candidate_memory_db do |memory|
        result = Jedi::Tools::CandidateEvaluator.new(main, memory).call(
          isin: "FR4487601001",
          price: 100.0,
          scaledef: "S_TEST",
          amount: 10_000.0,
          money: nil,
          capital: nil,
          minimum_quantity: 2,
          operability_steps: 2,
        )

        result.isin.should eq("FR4487601001")
        result.security.should be_nil
        result.price.should eq(100.0)
        result.price_source.explicit?.should be_true
        result.price_date.should be_nil
        result.mode.fixed_amount?.should be_true
        result.target_amount.should eq(10_000.0)
        result.quantity.should eq(100)
        result.opening_amount.should eq(10_000.0)
        result.minimum_operable_quantity.should eq(43)
        result.operable?.should be_true
      end
    end
  end

  it "derives T from K, r and the n-step scale distance" do
    JediSpec.with_db do |main|
      JediSpec.insert_scale(main, scale: candidate_operable_scale)
      money = Jedi::TradingSystem::Money.new(
        risk_rate: 0.02,
        target_coeff: 1.0,
        steps_down: 2,
      )

      candidate_memory_db do |memory|
        result = Jedi::Tools::CandidateEvaluator.new(main, memory).call(
          isin: "FR4487601001",
          price: 100.0,
          scaledef: "S_TEST",
          amount: nil,
          money: money,
          capital: 10_000.0,
          minimum_quantity: 2,
          operability_steps: 2,
        )

        sizing = result.position_sizing.not_nil!
        result.mode.capital?.should be_true
        sizing.risk_distance.should be_close(0.19, JediSpec::EPSILON)
        result.target_amount.should be_close(200.0 / 0.19, JediSpec::EPSILON)
        result.quantity.should eq(10)
        result.opening_amount.should eq(1_000.0)
        result.operable?.should be_true
      end
    end
  end

  it "requires an explicit price for an unregistered candidate" do
    JediSpec.with_db do |main|
      JediSpec.insert_scale(main)

      candidate_memory_db do |memory|
        ex = expect_raises(Jedi::LowLevelError) do
          Jedi::Tools::CandidateEvaluator.new(main, memory).call(
            isin: "FR4487601001",
            scaledef: "S_TEST",
            amount: 10_000.0,
            money: nil,
            capital: nil,
          )
        end

        ex.key.should eq("tools.candidate.price_required")
      end
    end
  end

  it "uses the Jedi quotation when no explicit price is supplied" do
    JediSpec.with_db do |main|
      quotation_date = Time.utc(2026, 10, 2, 16, 30)
      JediSpec.insert_security(main, quotation_date: quotation_date)
      JediSpec.insert_scale(main)
      main.exec("UPDATE security SET quotation_price = ? WHERE id = ?", 125.0, 1_i64)

      candidate_memory_db do |memory|
        result = Jedi::Tools::CandidateEvaluator.new(main, memory).call(
          isin: "FR4487601001",
          scaledef: "S_TEST",
          amount: 10_000.0,
          money: nil,
          capital: nil,
        )

        result.security.should_not be_nil
        result.price.should eq(125.0)
        result.price_source.stored?.should be_true
        result.price_date.should eq(quotation_date)
        result.quantity.should eq(80)
      end
    end
  end

  it "lets an explicit price override the Jedi quotation" do
    JediSpec.with_db do |main|
      JediSpec.insert_security(main, quotation_date: Time.utc(2026, 10, 2, 16, 30))
      JediSpec.insert_scale(main)
      main.exec("UPDATE security SET quotation_price = ? WHERE id = ?", 125.0, 1_i64)

      candidate_memory_db do |memory|
        result = Jedi::Tools::CandidateEvaluator.new(main, memory).call(
          isin: "FR4487601001",
          price: 100.0,
          scaledef: "S_TEST",
          amount: 10_000.0,
          money: nil,
          capital: nil,
        )

        result.security.should_not be_nil
        result.price.should eq(100.0)
        result.price_source.explicit?.should be_true
        result.price_date.should be_nil
        result.quantity.should eq(100)
      end
    end
  end

  it "rejects a ticker because candidate is keyed by ISIN" do
    JediSpec.with_db do |main|
      JediSpec.insert_security(main)
      JediSpec.insert_scale(main)
      main.exec("UPDATE security SET quotation_price = ? WHERE id = ?", 100.0, 1_i64)

      candidate_memory_db do |memory|
        ex = expect_raises(Jedi::LowLevelError) do
          Jedi::Tools::CandidateEvaluator.new(main, memory).call(
            isin: "SPEC",
            price: 100.0,
            scaledef: "S_TEST",
            amount: 10_000.0,
            money: nil,
            capital: nil,
          )
        end
        ex.key.should eq("infra.field_required")
      end
    end
  end

  it "rejects ambiguous sizing options" do
    JediSpec.with_db do |main|
      JediSpec.insert_security(main)
      JediSpec.insert_scale(main)
      main.exec("UPDATE security SET quotation_price = ? WHERE id = ?", 100.0, 1_i64)
      money = Jedi::TradingSystem::Money.new(0.01, 1.0, 2)

      candidate_memory_db do |memory|
        expect_raises(Jedi::LowLevelError) do
          Jedi::Tools::CandidateEvaluator.new(main, memory).call(
            isin: "FR4487601001",
            scaledef: "S_TEST",
            amount: 10_000.0,
            money: money,
            capital: nil,
          )
        end
      end
    end
  end

  it "evaluates portfolio funding for a fixed user amount" do
    JediSpec.with_db do |main|
      JediSpec.insert_scale(main)

      candidate_memory_db do |memory|
        result = Jedi::Tools::CandidateEvaluator.new(main, memory).call(
          isin: "FR4487601001",
          price: 100.0,
          scaledef: "S_TEST",
          amount: 10_000.0,
          money: nil,
          capital: 20_000.0,
          minimum_quantity: 2,
          operability_steps: 2,
        )

        funding = result.funding.not_nil!
        funding.portfolio_capital.should eq(20_000.0)
        funding.running_trade_count.should eq(0)
        funding.current_global_investment.should eq(0.0)
        funding.candidate_reserve.should be > 0.0
        funding.financeable?.should be_true
      end
    end
  end

  it "reserves future funding for already open trades" do
    JediSpec.with_db do |main|
      JediSpec.seed_basic_trade(main)

      candidate_memory_db do |memory|
        result = Jedi::Tools::CandidateEvaluator.new(main, memory).call(
          isin: "FR4487601001",
          price: 10.0,
          scaledef: "S_TEST",
          amount: 1_000.0,
          money: nil,
          capital: 10_000.0,
          minimum_quantity: 2,
          operability_steps: 2,
        )

        funding = result.funding.not_nil!
        funding.running_trade_count.should eq(1)
        funding.current_global_investment.should be_close(1_000.0, JediSpec::EPSILON)
        funding.existing_trade_reserve.should be_close(386.55, JediSpec::EPSILON)
        funding.trade_reserves.size.should eq(1)
        funding.trade_reserves.first.trade_name.should eq("T_TEST")
      end
    end
  end

  it "keeps operability distinct from funding after reserving existing trades" do
    JediSpec.with_db do |main|
      JediSpec.seed_basic_trade(main)
      candidate_memory_db do |memory|
        [2_400.0, 3_000.0].each do |capital|
          result = Jedi::Tools::CandidateEvaluator.new(main, memory).call(
            isin: "FR4487601001", price: 10.0, scaledef: "S_TEST",
            amount: 1_000.0, money: nil, capital: capital,
            minimum_quantity: 2, operability_steps: 2,
          )

          result.operable?.should be_true
          funding = result.funding.not_nil!
          funding.existing_trade_reserve.should be_close(386.55, JediSpec::EPSILON)
          funding.candidate_requirement.should be_close(1_386.55, JediSpec::EPSILON)
          funding.margin_after_candidate.should be_close(capital - 2_773.10, JediSpec::EPSILON)
          funding.financeable?.should eq(capital == 3_000.0)
        end
      end
    end
  end

  it "rejects non-finite prices amounts and capitals as user input" do
    JediSpec.with_db do |main|
      JediSpec.insert_scale(main)
      candidate_memory_db do |memory|
        evaluator = Jedi::Tools::CandidateEvaluator.new(main, memory)
        [Float64::NAN, Float64::INFINITY].each do |value|
          error = expect_raises(Jedi::LowLevelError) do
            evaluator.call(
              isin: "FR4487601001", price: value, scaledef: "S_TEST",
              amount: 1_000.0, money: nil, capital: 10_000.0,
            )
          end
          error.key.should eq("tools.candidate.invalid_price")
          error.kind.user_input?.should be_true

          error = expect_raises(Jedi::LowLevelError) do
            evaluator.call(
              isin: "FR4487601001", price: 10.0, scaledef: "S_TEST",
              amount: value, money: nil, capital: 10_000.0,
            )
          end
          error.key.should eq("tools.candidate.invalid_amount")

          error = expect_raises(Jedi::LowLevelError) do
            evaluator.call(
              isin: "FR4487601001", price: 10.0, scaledef: "S_TEST",
              amount: 1_000.0, money: nil, capital: value,
            )
          end
          error.key.should eq("tools.candidate.invalid_capital")
        end
      end
    end
  end

  it "rejects an explicitly invalid capital even with a fixed amount" do
    JediSpec.with_db do |main|
      JediSpec.insert_scale(main)
      candidate_memory_db do |memory|
        error = expect_raises(Jedi::LowLevelError) do
          Jedi::Tools::CandidateEvaluator.new(main, memory).call(
            isin: "FR4487601001", price: 10.0, scaledef: "S_TEST",
            amount: 1_000.0, money: nil, capital: -1.0,
          )
        end
        error.key.should eq("tools.candidate.invalid_capital")
      end
    end
  end
end

describe Jedi::Tools::CandidateReporter do
  it "renders only the investor-facing decision summary by default" do
    Jedi.init_i18n("en")
    JediSpec.with_db do |main|
      JediSpec.insert_scale(main)

      candidate_memory_db do |memory|
        evaluation = Jedi::Tools::CandidateEvaluator.new(main, memory).call(
          isin: "FR4487601001",
          price: 100.0,
          scaledef: "S_TEST",
          amount: 10_000.0,
          money: nil,
          capital: 20_000.0,
          minimum_quantity: 2,
          operability_steps: 2,
        )
        report = Jedi::Tools::CandidateReporter.new(evaluation).render

        report.should contain(I18n.t("tools.candidate.report.summary_title"))
        report.should contain(I18n.t("tools.candidate.report.opening_title"))
        report.should contain(I18n.t("tools.candidate.report.operability"))
        report.should contain(I18n.t("tools.candidate.report.funding_status"))
        report.should contain(I18n.t("tools.candidate.report.margin_after_candidate"))
        report.should contain(I18n.t("tools.candidate.report.available_after_reserve"))
        report.should contain(I18n.t("tools.candidate.report.candidate_requirement"))
        report.should contain(I18n.t("tools.candidate.report.summary_funding_note", {:steps => "3"}))
        report.should contain(evaluation.scale.operational.definition)
        report.should contain(I18n.t("tools.candidate.price_sources.explicit"))
        report.should_not contain(I18n.t("tools.candidate.report.price_date"))
        report.should_not contain(I18n.t("tools.candidate.report.minimum_quantity"))
        report.should_not contain(I18n.t("tools.candidate.report.trade_reserves"))
        report.should_not contain("missing translation")
      end
    end
  end

  it "keeps the complete technical report in extended mode" do
    Jedi.init_i18n("en")
    JediSpec.with_db do |main|
      JediSpec.insert_scale(main)

      candidate_memory_db do |memory|
        evaluation = Jedi::Tools::CandidateEvaluator.new(main, memory).call(
          isin: "FR4487601001",
          price: 100.0,
          scaledef: "S_TEST",
          amount: 10_000.0,
          money: nil,
          capital: 20_000.0,
          minimum_quantity: 2,
          operability_steps: 2,
        )
        report = Jedi::Tools::CandidateReporter.new(evaluation).render(extended: true)

        report.should contain(I18n.t("tools.candidate.report.title"))
        report.should contain(I18n.t("tools.candidate.report.minimum_quantity"))
        report.should contain(I18n.t("tools.candidate.report.financeability"))
        report.should contain(I18n.t("tools.candidate.report.funding_note"))
        report.should_not contain("missing translation")
      end
    end
  end

  it "shows the stored quotation date in both reports and makes a missing date explicit" do
    Jedi.init_i18n("en")
    JediSpec.with_db do |main|
      date = Time.utc(2026, 10, 2, 16, 30)
      JediSpec.insert_security(main, quotation_price: 10.0, quotation_date: date)
      JediSpec.insert_scale(main)
      candidate_memory_db do |memory|
        evaluator = Jedi::Tools::CandidateEvaluator.new(main, memory)
        evaluation = evaluator.call(
          isin: "FR4487601001", scaledef: "S_TEST",
          amount: 1_000.0, money: nil, capital: 10_000.0,
        )
        [false, true].each do |extended|
          report = Jedi::Tools::CandidateReporter.new(evaluation).render(extended: extended)
          report.should contain(I18n.t("tools.candidate.price_sources.stored"))
          report.should contain(evaluation.price_date.not_nil!.to_s("%F %T %:z"))
          report.should_not contain("missing translation")
        end

        main.exec("UPDATE security SET quotation_date = NULL WHERE id = 1")
        undated = evaluator.call(
          isin: "FR4487601001", scaledef: "S_TEST",
          amount: 1_000.0, money: nil, capital: 10_000.0,
        )
        Jedi::Tools::CandidateReporter.new(undated).render
          .should contain(I18n.t("tools.candidate.price_sources.unknown_date"))
      end
    end
  end

  it "reports the actual capital-sizing failure instead of a generic refusal" do
    Jedi.init_i18n("en")
    JediSpec.with_db do |main|
      JediSpec.insert_scale(main, scale: candidate_operable_scale)
      candidate_memory_db do |memory|
        evaluator = Jedi::Tools::CandidateEvaluator.new(main, memory)
        risk_limited = evaluator.call(
          isin: "FR4487601001", price: 100.0, scaledef: "S_TEST",
          amount: nil, money: Jedi::TradingSystem::Money.new(0.02, 1.0, 2),
          capital: 100.0, minimum_quantity: 1, operability_steps: 2,
        )
        risk_limited.position_sizing.not_nil!.failure.should eq(Jedi::Tools::PositionSizingFailure::RiskQuantityZero)
        Jedi::Tools::CandidateReporter.new(risk_limited).render
          .should contain(I18n.t("tools.candidate.failure.risk_quantity_zero"))

        inoperable = evaluator.call(
          isin: "FR4487601001", price: 100.0, scaledef: "S_TEST",
          amount: nil, money: Jedi::TradingSystem::Money.new(0.02, 1.0, 2),
          capital: 10_000.0, minimum_quantity: 100, operability_steps: 2,
        )
        inoperable.position_sizing.not_nil!.failure.should eq(Jedi::Tools::PositionSizingFailure::InsufficientOperability)
        Jedi::Tools::CandidateReporter.new(inoperable).render
          .should contain(I18n.t("tools.candidate.failure.insufficient_operability"))
      end
    end
  end
end
