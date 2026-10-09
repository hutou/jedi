require "../spec_helper"

private def with_scoring_behavior_environment(&)
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

describe Jedi::Tools::ScoringBehaviorAnalyzer do
  it "stores coverage and an operation signature on score results" do
    with_scoring_behavior_environment do |conn_main, conn_memory|
      filename = File.expand_path(
        "../fixtures/tools/backtest_quotes.csv",
        __DIR__,
      )
      builder = "vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0"

      scoring = Jedi::Tools::Scoring.new(
        conn_main,
        conn_memory,
        filename,
        builder,
      )
      scoring.run(option_ranking: "jedi")

      result = scoring.evaluated_results.first
      result.coverage.known.should be_true
      result.coverage.positive_available.should eq(4)
      result.coverage.negative_available.should eq(4)
      result.behavior_signature.empty?.should be_false
      result.operability.known.should be_true
      result.activity.known.should be_true
      (result.activity.history_months > 0).should be_true
      (result.activity.rolling_months > 0).should be_true
    end
  end
end
