require "../spec_helper"

private def s3_candidate(
  key : String,
  builder : String,
  family : Jedi::Tools::ScoringSearchFamily,
  scale_type : Int32,
) : Jedi::Tools::ScoringCandidate
  Jedi::Tools::ScoringCandidate.new(
    "scale-#{key}",
    builder,
    builder,
    family: family,
    scale_type: scale_type,
  )
end

private def s3_result(
  candidate : Jedi::Tools::ScoringCandidate,
  fitness : Float64,
  behavior_signature : String,
) : Jedi::Tools::ScoringResult
  Jedi::Tools::ScoringResult.new(
    "FR4487601001",
    candidate,
    fitness,
    1.0,
    1.5,
    behavior_signature: behavior_signature,
  )
end

describe Jedi::Tools::ScoringSearchPresets do
  it "keeps P1 P2 and P3 inside the code" do
    specs = Jedi::Tools::ScoringSearchPresets.all

    specs.map(&.key).should eq(["P1", "P2", "P3"])
    specs[0].builder.should contain("kc:1.61")
    specs[1].builder.should contain("vr:5%,10%,15%,20%,25%,30%")
    specs[2].builder.should contain("mg:2")
    Jedi::Tools::ScoringSearchPresets.resolve("p2").should_not be_nil
  end
end

describe Jedi::Tools::ScoringCompactReporter do
  it "shows only the three ordering metrics and the typed builder" do
    candidate = s3_candidate(
      "compact",
      "vr:15%,np:3,nn:3,ki:15%,kb:1,kd:0.1",
      Jedi::Tools::ScoringSearchFamily::RegularGeometric,
      2,
    )
    result = Jedi::Tools::ScoringResult.new(
      "FR4487601001",
      candidate,
      1.234,
      1.125,
      1.567,
    )

    output = Jedi::Tools::ScoringCompactReporter.new(
      [result],
      "tools.score.compact.title",
      5,
    ).render

    output.should contain("1.234")
    output.should contain("1.125")
    output.should contain("1.567")
    output.should contain("II:")
    output.should_not contain("Méd.loc")
    output.should_not contain("Coverage")
  end

  it "states explicitly when no Jedi scale is admissible" do
    output = Jedi::Tools::ScoringCompactReporter.new(
      [] of Jedi::Tools::ScoringResult,
      "tools.score.compact.title",
      5,
    ).render

    output.should contain(I18n.t("tools.score.compact.empty"))
    output.should_not contain(I18n.t("tools.score.compact.columns"))
  end

  it "keeps the raw compact list limited to twenty candidates" do
    results = (1..25).map do |index|
      candidate = s3_candidate(
        "compact-#{index}",
        "vr:#{index}%,np:3,nn:3,ki:15%,kb:1,kd:0.1",
        Jedi::Tools::ScoringSearchFamily::RegularGeometric,
        2,
      )
      s3_result(candidate, 1.0, "compact-#{index}")
    end

    output = Jedi::Tools::ScoringCompactReporter.new(
      results,
      "tools.score.compact.raw_title",
      20,
    ).render

    output.lines.count(&.includes?("II:")).should eq(20)
    output.should contain(results[19].candidate.typed_builder)
    output.should_not contain(results[20].candidate.typed_builder)
    output.should contain(I18n.t("tools.score.compact.ratios_note"))
  end
end

describe Jedi::Tools::ScoringPreferenceAnalyzer do
  it "computes local neighborhoods inside each search family" do
    regular_a = s3_candidate(
      "regular-a",
      "vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0.1",
      Jedi::Tools::ScoringSearchFamily::RegularGeometric,
      2,
    )
    regular_b = s3_candidate(
      "regular-b",
      "vr:11%,np:3,nn:3,ki:10%,kb:1,kd:0.1",
      Jedi::Tools::ScoringSearchFamily::RegularGeometric,
      2,
    )
    foreign = s3_candidate(
      "foreign",
      "vr:10.5%,np:3,nn:3,ki:10%,kb:1,kd:0.1",
      Jedi::Tools::ScoringSearchFamily::FlexibleGeometric,
      1,
    )

    results = [
      s3_result(regular_a, 0.98, "regular-a"),
      s3_result(regular_b, 0.96, "regular-b"),
      s3_result(foreign, 0.10, "foreign"),
    ]

    analyzer = Jedi::Tools::ScoringPreferenceAnalyzer.new(results)
    preferences = analyzer.analyze
    target = preferences.find { |preference| preference.result.candidate.key == regular_a.key }
    target.should_not be_nil
    target.not_nil!.local_median_fitness.should be_close(0.97, 1e-9)
  end

  it "collapses identical behavior only after family-local analysis" do
    first = s3_candidate(
      "same-a",
      "vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0.1",
      Jedi::Tools::ScoringSearchFamily::RegularGeometric,
      2,
    )
    second = s3_candidate(
      "same-b",
      "vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0.1",
      Jedi::Tools::ScoringSearchFamily::FlexibleGeometric,
      1,
    )
    other = s3_candidate(
      "other",
      "vr:20%,np:3,nn:3,ki:10%,kb:1,kd:0.1",
      Jedi::Tools::ScoringSearchFamily::RegularGeometric,
      2,
    )

    results = [
      s3_result(first, 1.0, "same-stream"),
      s3_result(second, 1.0, "same-stream"),
      s3_result(other, 0.8, "other-stream"),
    ]

    analyzer = Jedi::Tools::ScoringPreferenceAnalyzer.new(results)
    preferences = analyzer.analyze

    preferences.size.should eq(2)
    analyzer.behaviorally_redundant_count.should eq(1)
    equivalent = preferences.find { |preference| preference.result.behavior_signature == "same-stream" }
    equivalent.should_not be_nil
    equivalent.not_nil!.behavior_group_size.should eq(2)
  end
end

private def with_s3_scoring_environment(&)
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
  it "searches the three internal families when no builder is supplied" do
    with_s3_scoring_environment do |conn_main, conn_memory|
      filename = File.expand_path(
        "../fixtures/tools/backtest_quotes.csv",
        __DIR__,
      )
      scoring = Jedi::Tools::Scoring.new(conn_main, conn_memory, filename)

      scoring.run(
        option_ranking: "raw",
        option_search: "adaptive",
        option_budget: 3,
      )

      families = scoring.evaluated_results.map(&.candidate.family).uniq
      families.size.should eq(3)
      summary = scoring.search_summary
      summary.should_not be_nil
      summary.not_nil!.strategy.should eq("adaptive")
      (summary.not_nil!.evaluated_candidates <= 3).should be_true
    end
  end

  it "uses raw adaptive compact as the normal defaults" do
    with_s3_scoring_environment do |conn_main, conn_memory|
      filename = File.expand_path(
        "../fixtures/tools/backtest_quotes.csv",
        __DIR__,
      )
      builder = "vr:15%,np:3,nn:3,ki:15%,kb:1,kd:0.0"
      scoring = Jedi::Tools::Scoring.new(conn_main, conn_memory, filename, builder)

      output = scoring.run

      output.should contain(I18n.t("tools.score.compact.raw_title"))
      output.should contain("II:")
      output.should_not contain(I18n.t("tools.score.search.title"))
      scoring.search_summary.not_nil!.strategy.should eq("adaptive")
      scoring.preferred_results.empty?.should be_true
    end
  end
end
