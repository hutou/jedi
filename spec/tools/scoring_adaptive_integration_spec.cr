require "../spec_helper"

private def with_scoring_adaptive_environment(&)
  JediSpec.with_db do |conn_main|
    conn_memory = DB.connect "sqlite3://%3Amemory%3A"

    previous_simulation = Jedi::App.simulation
    previous_initial_investment = Jedi::App.initial_investment

    begin
      Jedi::App.simulation = Jedi::SimulationMode::FromSeed
      Jedi::App.initial_investment = 1_000
      yield conn_main, conn_memory
    ensure
      Jedi::App.simulation = previous_simulation
      Jedi::App.initial_investment = previous_initial_investment
      conn_memory.close
    end
  end
end

describe Jedi::Tools::Scoring do
  it "reserves influence diagnostics for technical reports without changing adaptive results" do
    with_scoring_adaptive_environment do |conn_main, conn_memory|
      filename = File.expand_path("../fixtures/tools/backtest_capital_quotes.csv", __DIR__)
      builder = "vr:5%,15%,np:2,3,4,nn:2,3,4,ki:0%,20%,kb:1,kd:0.0"
      policy = Jedi::Tools::ScoringSearchPolicy.new(
        exploration_ratio: 0.5,
        minimum_exploration: 8,
        elite_count: 2,
      )
      scoring = Jedi::Tools::Scoring.new(
        conn_main,
        conn_memory,
        filename,
        builder,
        search_policy: policy,
        progress_io: IO::Memory.new,
      )

      technical = scoring.run(option_budget: 12, option_display: "technical")
      scoring.parameter_impacts.empty?.should be_false
      technical.should contain(I18n.t("tools.score.search.influence_title"))
      reference = scoring.evaluated_results.map do |result|
        {result.candidate.key, result.fitness, result.num_avg_oper_month, result.maximum_investment_ratio}
      end
      summary = scoring.search_summary.not_nil!
      summary.exploration_candidates.should eq(8)
      summary.refinement_candidates.should eq(4)

      ["compact", "study"].each do |display|
        output = scoring.run(option_budget: 12, option_display: display)
        scoring.parameter_impacts.empty?.should be_true
        output.should_not contain(I18n.t("tools.score.search.influence_title"))
        actual = scoring.evaluated_results.map do |result|
          {result.candidate.key, result.fitness, result.num_avg_oper_month, result.maximum_investment_ratio}
        end
        actual.should eq(reference)
        scoring.search_summary.should eq(summary)
      end
    end
  end

  it "keeps Jedi enrichment available without running influence diagnostics in compact or study" do
    with_scoring_adaptive_environment do |conn_main, conn_memory|
      filename = File.expand_path("../fixtures/tools/backtest_capital_quotes.csv", __DIR__)
      builder = "vr:5%,15%,np:2,3,4,nn:2,3,4,ki:0%,20%,kb:1,kd:0.0"
      scoring = Jedi::Tools::Scoring.new(
        conn_main,
        conn_memory,
        filename,
        builder,
        progress_io: IO::Memory.new,
      )

      ["jedi", "both"].each do |ranking|
        ["compact", "study"].each do |display|
          output = scoring.run(option_ranking: ranking, option_budget: 12, option_display: display)

          scoring.parameter_impacts.empty?.should be_true
          output.should_not contain(I18n.t("tools.score.search.influence_title"))
          scoring.evaluated_results.each do |result|
            result.coverage.known.should be_true
            result.behavior_signature.empty?.should be_false
            result.operability.known.should be_true
            result.activity.known.should be_true
          end
        end
      end
    end
  end

  it "reports one increasing percentage across exploration and refinement" do
    with_scoring_adaptive_environment do |conn_main, conn_memory|
      filename = File.expand_path("../fixtures/tools/backtest_capital_quotes.csv", __DIR__)
      builder = "vr:5%,15%,np:2,3,4,nn:2,3,4,ki:0%,20%,kb:1,kd:0.0"
      progress = IO::Memory.new
      policy = Jedi::Tools::ScoringSearchPolicy.new(
        exploration_ratio: 0.5,
        minimum_exploration: 8,
      )
      scoring = Jedi::Tools::Scoring.new(
        conn_main,
        conn_memory,
        filename,
        builder,
        search_policy: policy,
        progress_io: progress,
      )

      scoring.run(option_budget: 12)

      scoring.search_summary.not_nil!.refinement_candidates.should eq(4)
      updates = progress.to_s.scan(/([\d.]+)% (\d+)\/(\d+)/)
      updates.size.should eq(12)
      updates.map { |match| match[2].to_i }.should eq((1..12).to_a)
      updates.all? { |match| match[3] == "12" }.should be_true
      percentages = updates.map { |match| match[1].to_f }
      percentages.should eq(percentages.sort)
      percentages.last.should eq(100.0)
    end
  end

  it "reports progress across all families using the effective adaptive budget" do
    with_scoring_adaptive_environment do |conn_main, conn_memory|
      filename = File.expand_path("../fixtures/tools/backtest_quotes.csv", __DIR__)
      progress = IO::Memory.new
      scoring = Jedi::Tools::Scoring.new(
        conn_main,
        conn_memory,
        filename,
        progress_io: progress,
      )

      scoring.run(option_budget: 3)

      updates = progress.to_s.scan(/([\d.]+)% (\d+)\/(\d+)/)
      updates.map { |match| match[2].to_i }.should eq([1, 2, 3])
      updates.all? { |match| match[3] == "3" }.should be_true
      updates.last[1].should eq("100.0")
      scoring.evaluated_results.map(&.candidate.family).uniq.size.should eq(3)
    end
  end

  it "finishes at one hundred percent in grid mode and when the budget exceeds the search space" do
    with_scoring_adaptive_environment do |conn_main, conn_memory|
      filename = File.expand_path("../fixtures/tools/backtest_quotes.csv", __DIR__)
      builder = "vr:10%,15%,np:3,4,nn:3,ki:15%,kb:1,kd:0.0"
      progress = IO::Memory.new
      scoring = Jedi::Tools::Scoring.new(
        conn_main,
        conn_memory,
        filename,
        builder,
        progress_io: progress,
      )

      ["adaptive", "grid"].each do |strategy|
        progress.clear
        scoring.run(option_search: strategy, option_budget: 50)

        updates = progress.to_s.scan(/([\d.]+)% (\d+)\/(\d+)/)
        updates.size.should eq(4)
        updates.map { |match| match[2].to_i }.should eq([1, 2, 3, 4])
        updates.all? { |match| match[3] == "4" }.should be_true
        updates.last[1].should eq("100.0")
      end
    end
  end

  it "limits the main search to the adaptive budget" do
    with_scoring_adaptive_environment do |conn_main, conn_memory|
      filename = File.expand_path(
        "../fixtures/tools/backtest_quotes.csv",
        __DIR__,
      )
      builder = "vr:10%,15%,np:3,4,nn:3,ki:15%,kb:1,kd:0.0"

      scoring = Jedi::Tools::Scoring.new(
        conn_main,
        conn_memory,
        filename,
        builder,
      )
      scoring.run(
        option_search: "adaptive",
        option_budget: 2,
      )

      summary = scoring.search_summary
      summary.should_not be_nil
      value = summary.not_nil!
      value.strategy.should eq("adaptive")
      value.evaluated_candidates.should eq(2)
      scoring.evaluated_results.size.should eq(2)
      (value.available_candidates >= value.evaluated_candidates).should be_true
    end
  end
end
