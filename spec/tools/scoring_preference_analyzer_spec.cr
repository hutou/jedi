require "../spec_helper"

private def scoring_result(
  builder : String,
  fitness : Float64,
  operations : Float64 = 1.0,
  investment : Float64 = 1.5,
  coverage : Jedi::Tools::ScoringCoverage = Jedi::Tools::ScoringCoverage.unknown,
  behavior_signature : String = "",
  operability : Jedi::Tools::ScoringOperability = Jedi::Tools::ScoringOperability.unknown,
  activity : Jedi::Tools::ScoringActivity = Jedi::Tools::ScoringActivity.unknown,
) : Jedi::Tools::ScoringResult
  candidate = Jedi::Tools::ScoringCandidate.new(
    "scale:#{builder}",
    builder,
    builder,
  )
  Jedi::Tools::ScoringResult.new(
    "FR4487601001",
    candidate,
    fitness,
    operations,
    investment,
    coverage,
    behavior_signature,
    operability,
    activity,
  )
end

describe Jedi::Tools::ScoringBehaviorAnalyzer do
  it "measures reached and unused steps from recorded positions" do
    positions = [
      Jedi::TradingRules::Position.new(0, 0, 2),
      Jedi::TradingRules::Position.new(0, 0, -3),
    ]

    coverage = Jedi::Tools::ScoringBehaviorAnalyzer.coverage(
      5,
      -5,
      positions,
    )

    coverage.positive_reached.should eq(2)
    coverage.negative_reached.should eq(3)
    coverage.unused_positive.should eq(3)
    coverage.unused_negative.should eq(2)
    coverage.significant?(2).should be_false
  end

  it "recognizes a terminal step when a level jump occurred" do
    positions = [
      Jedi::TradingRules::Position.new(1, 0, 0),
      Jedi::TradingRules::Position.new(0, 1, 0),
    ]

    coverage = Jedi::Tools::ScoringBehaviorAnalyzer.coverage(
      5,
      -4,
      positions,
    )

    coverage.positive_reached.should eq(5)
    coverage.negative_reached.should eq(4)
    coverage.total_unused.should eq(0)
  end
end

describe Jedi::Tools::ScoringPreferenceAnalyzer do
  it "prefers a local plateau to an isolated peak inside one result tier" do
    results = [
      scoring_result("vr:1%,np:3,nn:3,ki:10%,kb:1,kd:0.1", 1.000),
      scoring_result("vr:40%,np:3,nn:3,ki:10%,kb:1,kd:0.1", 0.980),
      scoring_result("vr:41%,np:3,nn:3,ki:10%,kb:1,kd:0.1", 0.970),
      scoring_result("vr:39%,np:3,nn:3,ki:10%,kb:1,kd:0.1", 0.960),
      scoring_result("vr:2%,np:3,nn:3,ki:10%,kb:1,kd:0.1", 0.550),
      scoring_result("vr:3%,np:3,nn:3,ki:10%,kb:1,kd:0.1", 0.500),
    ]
    policy = Jedi::Tools::ScoringPreferencePolicy.new(
      fitness_tolerance_ratio: 0.10,
      operations_tolerance: 1.0,
      investment_tolerance_ratio: 1.0,
      neighbor_count: 2,
    )

    ranked = Jedi::Tools::ScoringPreferenceAnalyzer.new(results, policy).analyze

    ranked.first.result.fitness.should eq(0.980)
    ranked.first.raw_rank.should eq(2)
    ranked.first.local_median_fitness.should be_close(0.970, 1e-9)
  end

  it "never promotes a lower equivalence tier above a better raw tier" do
    results = [
      scoring_result("vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0.1", 1.000),
      scoring_result("vr:20%,np:3,nn:3,ki:10%,kb:1,kd:0.1", 0.700),
      scoring_result("vr:21%,np:3,nn:3,ki:10%,kb:1,kd:0.1", 0.700),
      scoring_result("vr:22%,np:3,nn:3,ki:10%,kb:1,kd:0.1", 0.700),
    ]
    policy = Jedi::Tools::ScoringPreferencePolicy.new(
      fitness_tolerance_ratio: 0.02,
      operations_tolerance: 1.0,
      investment_tolerance_ratio: 1.0,
      neighbor_count: 2,
    )

    ranked = Jedi::Tools::ScoringPreferenceAnalyzer.new(results, policy).analyze

    ranked.first.result.fitness.should eq(1.000)
    ranked.first.equivalence_tier.should eq(0)
  end

  it "uses the worst temporal period before the temporal median" do
    first = scoring_result("vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0.1", 1.000)
    second = scoring_result("vr:20%,np:3,nn:3,ki:10%,kb:1,kd:0.1", 0.990)
    analyzer = Jedi::Tools::ScoringPreferenceAnalyzer.new(
      [first, second],
      Jedi::Tools::ScoringPreferencePolicy.new(
        fitness_tolerance_ratio: 0.05,
        operations_tolerance: 1.0,
        investment_tolerance_ratio: 1.0,
      ),
    )
    preliminary = analyzer.analyze

    enriched = preliminary.map do |preference|
      metrics = if preference.result.fitness == 1.000
                  Jedi::Tools::ScoringTemporalMetrics.new(1.10, 0.40, 0.30, 0.20)
                else
                  Jedi::Tools::ScoringTemporalMetrics.new(0.95, 0.80, 0.05, 0.05)
                end
      preference.with_temporal(metrics)
    end

    analyzer.rank(enriched).first.result.fitness.should eq(0.990)
  end

  it "keeps the canonical covered representative of identical behavior" do
    common = {
      fitness:            1.0,
      operations:         1.0,
      investment:         1.5,
      behavior_signature: "same-operation-stream",
    }
    results = [
      scoring_result(
        "vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0.1",
        common[:fitness],
        common[:operations],
        common[:investment],
        Jedi::Tools::ScoringCoverage.new(3, 3, 2, 2),
        common[:behavior_signature],
      ),
      scoring_result(
        "vr:10%,np:4,nn:4,ki:10%,kb:1,kd:0.1",
        common[:fitness],
        common[:operations],
        common[:investment],
        Jedi::Tools::ScoringCoverage.new(4, 4, 2, 2),
        common[:behavior_signature],
      ),
      scoring_result(
        "vr:10%,np:5,nn:5,ki:10%,kb:1,kd:0.1",
        common[:fitness],
        common[:operations],
        common[:investment],
        Jedi::Tools::ScoringCoverage.new(5, 5, 2, 2),
        common[:behavior_signature],
      ),
    ]

    analyzer = Jedi::Tools::ScoringPreferenceAnalyzer.new(results)
    ranked = analyzer.analyze

    ranked.size.should eq(1)
    ranked.first.result.candidate.search_builder.should contain("np:3")
    ranked.first.behavior_group_size.should eq(3)
    analyzer.behaviorally_redundant_count.should eq(2)
  end

  it "removes a terminally inoperable scale before local ranking" do
    rejected = scoring_result(
      "vr:5%,np:2,nn:3,ki:0%,kb:1,kd:0.0",
      1.50,
      operability: Jedi::Tools::ScoringOperability.new(
        true,
        false,
        "degraded",
        1,
        900,
        ["directional order quantity below minimum"],
      ),
    )
    admissible = scoring_result(
      "vr:15%,np:3,nn:3,ki:15%,kb:1,kd:0.1",
      1.00,
      operability: Jedi::Tools::ScoringOperability.new(
        true,
        true,
        "normal",
        3,
        10,
      ),
    )

    analyzer = Jedi::Tools::ScoringPreferenceAnalyzer.new([rejected, admissible])
    ranked = analyzer.analyze

    ranked.size.should eq(1)
    ranked.first.result.candidate.key.should eq(admissible.candidate.key)
    ranked.first.raw_rank.should eq(2)
    analyzer.inoperable_count.should eq(1)
  end

  it "does not reject activity before one complete rolling window is available" do
    short_history = scoring_result(
      "vr:15%,np:3,nn:3,ki:15%,kb:1,kd:0.0",
      1.0,
      activity: Jedi::Tools::ScoringActivity.new(
        true, 0, 1, 0.0, 1, 0.0, 0.0, 0.0, 1.0, 1, 1.0,
      ),
    )

    analyzer = Jedi::Tools::ScoringPreferenceAnalyzer.new([short_history])
    ranked = analyzer.analyze

    ranked.size.should eq(1)
    analyzer.inactive_count.should eq(0)
  end

  it "removes a scale whose genuine scale activity is too low" do
    weak = scoring_result(
      "kc:2.44,1.95,0.75,0.56,0.42,ks:0.7,1.46,1.92,ki:0%,kb:1",
      1.27,
      activity: Jedi::Tools::ScoringActivity.new(
        true, 4, 80, 0.05, 12, 0.60, 1.10, 1.83, 0.70, 60, 0.75,
      ),
    )
    acceptable = scoring_result(
      "vr:10%,np:2,nn:5,ki:10%,kb:1,kd:0.0",
      1.243,
      activity: Jedi::Tools::ScoringActivity.new(
        true, 14, 80, 0.175, 12, 2.10, 0.70, 0.33, 0.05, 10, 0.125,
      ),
    )

    analyzer = Jedi::Tools::ScoringPreferenceAnalyzer.new([weak, acceptable])
    ranked = analyzer.analyze

    ranked.size.should eq(1)
    ranked.first.result.candidate.key.should eq(acceptable.candidate.key)
    ranked.first.raw_rank.should eq(2)
    analyzer.inactive_count.should eq(1)
  end

  it "removes activity concentrated in a short historical interval" do
    concentrated = scoring_result(
      "vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0.1",
      1.20,
      activity: Jedi::Tools::ScoringActivity.new(
        true, 16, 72, 0.222, 12, 2.67, 2.10, 0.79, 0.65, 42, 0.583,
      ),
    )
    distributed = scoring_result(
      "vr:15%,np:3,nn:3,ki:10%,kb:1,kd:0.1",
      1.19,
      activity: Jedi::Tools::ScoringActivity.new(
        true, 13, 72, 0.181, 12, 2.17, 0.65, 0.30, 0.04, 11, 0.153,
      ),
    )

    analyzer = Jedi::Tools::ScoringPreferenceAnalyzer.new([concentrated, distributed])
    ranked = analyzer.analyze

    ranked.size.should eq(1)
    ranked.first.result.candidate.key.should eq(distributed.candidate.key)
    analyzer.inactive_count.should eq(1)
  end

  it "prefers lower rolling activity dispersion inside one result tier" do
    irregular = scoring_result(
      "vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0.1",
      1.000,
      activity: Jedi::Tools::ScoringActivity.new(
        true, 15, 72, 0.208, 12, 2.50, 1.50, 0.60, 0.10, 12, 0.167,
      ),
    )
    regular = scoring_result(
      "vr:11%,np:3,nn:3,ki:10%,kb:1,kd:0.1",
      0.995,
      activity: Jedi::Tools::ScoringActivity.new(
        true, 15, 72, 0.208, 12, 2.50, 0.50, 0.20, 0.10, 12, 0.167,
      ),
    )
    policy = Jedi::Tools::ScoringPreferencePolicy.new(
      fitness_tolerance_ratio: 0.02,
      operations_tolerance: 1.0,
      investment_tolerance_ratio: 1.0,
    )

    ranked = Jedi::Tools::ScoringPreferenceAnalyzer.new(
      [irregular, regular],
      policy,
    ).analyze

    ranked.first.result.candidate.key.should eq(regular.candidate.key)
  end

  it "removes a scale with three unused outer steps per side" do
    oversized = scoring_result(
      "vr:10%,np:5,nn:5,ki:10%,kb:1,kd:0.1",
      1.0,
      coverage: Jedi::Tools::ScoringCoverage.new(5, 5, 2, 2),
      behavior_signature: "oversized",
    )
    significant = scoring_result(
      "vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0.1",
      0.9,
      coverage: Jedi::Tools::ScoringCoverage.new(3, 3, 2, 2),
      behavior_signature: "significant",
    )

    analyzer = Jedi::Tools::ScoringPreferenceAnalyzer.new(
      [oversized, significant],
    )
    ranked = analyzer.analyze

    ranked.size.should eq(1)
    ranked.first.result.candidate.key.should eq(significant.candidate.key)
    analyzer.insignificant_count.should eq(1)
  end
end
