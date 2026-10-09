require "../spec_helper"

private def adaptive_candidate(
  vr : Int32,
  np : Int32,
  ki : Int32,
  suffix : String,
) : Jedi::Tools::ScoringCandidate
  builder = "vr:#{vr}%,np:#{np},nn:3,ki:#{ki}%,kb:1,kd:0.1"
  Jedi::Tools::ScoringCandidate.new(
    "scale-#{suffix}",
    builder,
    builder,
  )
end

private def adaptive_result(
  candidate : Jedi::Tools::ScoringCandidate,
  fitness : Float64,
) : Jedi::Tools::ScoringResult
  Jedi::Tools::ScoringResult.new(
    "FR4487601001",
    candidate,
    fitness,
    1.0,
    1.5,
  )
end

describe Jedi::Tools::ScoringAdaptiveSearch do
  it "keeps the evaluation count inside the requested budget" do
    candidates = [] of Jedi::Tools::ScoringCandidate
    index = 0
    [5, 10, 15, 20, 25, 30].each do |vr|
      [2, 3, 4, 5].each do |np|
        [0, 10, 20, 30].each do |ki|
          index += 1
          candidates << adaptive_candidate(vr, np, ki, index.to_s)
        end
      end
    end

    policy = Jedi::Tools::ScoringSearchPolicy.new(
      minimum_exploration: 20,
      elite_count: 5,
    )
    search = Jedi::Tools::ScoringAdaptiveSearch.new(candidates, 50, policy)
    exploration = search.exploration_candidates

    exploration.size.should eq(20)
    exploration.map(&.key).uniq.size.should eq(exploration.size)

    results = exploration.map_with_index do |candidate, rank|
      adaptive_result(candidate, 1.0 - rank.to_f / 1000.0)
    end
    refinement = search.refinement_candidates(
      results,
      Jedi::Tools::ScoringObjective.new(1),
    )

    refinement.size.should eq(30)
    refinement_keys = refinement.map(&.key)
    exploration.each do |candidate|
      refinement_keys.includes?(candidate.key).should be_false
    end
    (exploration.size + refinement.size).should eq(50)
  end

  it "covers discrete search values during exploration" do
    candidates = [] of Jedi::Tools::ScoringCandidate
    index = 0
    [5, 10, 15, 20].each do |vr|
      [2, 3].each do |np|
        [0, 10].each do |ki|
          index += 1
          candidates << adaptive_candidate(vr, np, ki, index.to_s)
        end
      end
    end

    policy = Jedi::Tools::ScoringSearchPolicy.new(
      exploration_ratio: 1.0,
      minimum_exploration: 8,
    )
    exploration = Jedi::Tools::ScoringAdaptiveSearch.new(
      candidates,
      8,
      policy,
    ).exploration_candidates

    vr_values = [] of Float64
    np_values = [] of Float64
    exploration.each do |candidate|
      if value = candidate.features["vr"]?
        vr_values << value unless vr_values.includes?(value)
      end
      if value = candidate.features["np"]?
        np_values << value unless np_values.includes?(value)
      end
    end
    vr_values.sort!
    np_values.sort!

    vr_values.should eq([0.05, 0.10, 0.15, 0.20])
    np_values.should eq([2.0, 3.0])
  end
end

describe Jedi::Tools::ScoringImpactAnalyzer do
  it "identifies the feature whose levels move median fitness most" do
    results = [] of Jedi::Tools::ScoringResult
    index = 0

    [5, 10, 20, 30].each do |vr|
      [0, 10].each do |ki|
        2.times do
          index += 1
          candidate = adaptive_candidate(vr, 3, ki, index.to_s)
          fitness = vr.to_f / 10.0 + ki.to_f / 1000.0
          results << adaptive_result(candidate, fitness)
        end
      end
    end

    impacts = Jedi::Tools::ScoringImpactAnalyzer.new(results).analyze

    impacts.empty?.should be_false
    impacts.first.feature.should eq("vr")
    impacts.first.impact_ratio.should be > 0.5
  end
end
