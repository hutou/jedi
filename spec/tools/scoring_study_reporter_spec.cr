require "../spec_helper"

describe Jedi::Tools::ScoringStudyReporter do
  it "reports economic and activity diagnostics without changing score ordering" do
    candidate = Jedi::Tools::ScoringCandidate.new(
      "scale:test",
      "vr:15%,np:3,nn:3,ki:15%,kb:1,kd:0.0",
      "vr:15%,np:3,nn:3,ki:15%,kb:1,kd:0.0",
      family: Jedi::Tools::ScoringSearchFamily::RegularGeometric,
      scale_type: 2,
    )
    performance = Jedi::Tools::ScoringPerformance.new(
      known: true,
      net_fitness: 0.210,
      net_return_on_maximum_investment: 8.40,
      net_annualized_return: 1.25,
      maximum_investment_cents: 245_000,
      total_fees_cents: 1_230,
      operation_count: 24,
      scale_operation_count: 18,
      scale_operations_per_year: 3.60,
    )
    result = Jedi::Tools::ScoringResult.new(
      "FR4487601001",
      candidate,
      0.250,
      0.30,
      2.45,
      performance: performance,
    )

    report = Jedi::Tools::ScoringStudyReporter.new(
      [result],
      "tools.score.study.title",
    ).render

    report.should contain(I18n.t("tools.score.study.title"))
    report.should contain("0.250")
    report.should contain("0.210")
    report.should contain("8.40")
    report.should contain("1.25")
    report.should contain("3.60")
    report.should contain("2450")
    report.should contain("12")
    report.should contain("15.0")
    report.should contain("P2")
  end
end
