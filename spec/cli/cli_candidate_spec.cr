require "../support/cli_spec_helper"

private def with_candidate_cli(&)
  JediCliSpec.with_cli_db do |conn|
    Jedi.init_i18n("en")
    previous_simulation = Jedi::App.simulation
    begin
      JediSpec.insert_scale(conn)
      yield conn
    ensure
      Jedi::App.simulation = previous_simulation
    end
  end
end

private def run_candidate_cli(conn : DB::Connection, options : Array(String)) : String
  JediCliSpec.run(conn, ["tools", "candidate", "FR4487601001", "--scale=S_TEST"] + options)
end

describe "KISS candidate CLI" do
  it "evaluates an external security without changing the production database" do
    with_candidate_cli do |conn|
      before = {"security", "scale", "trade", "settings", "operation"}.map do |table|
        JediCliSpec.table_count(conn, table)
      end

      output = run_candidate_cli(conn, ["--price=10", "--amount=1000", "--capital=3000"])

      output.should contain(I18n.t("tools.candidate.price_sources.explicit"))
      output.should contain("1000.00 €")
      output.should contain("vr:10%, ks:0.8,1.2, ki:0%, kb:0")
      output.should_not match(/LIT-\d+/)
      output.should_not contain("missing translation")
      after = {"security", "scale", "trade", "settings", "operation"}.map do |table|
        JediCliSpec.table_count(conn, table)
      end
      after.should eq(before)
    end
  end

  it "identifies a stored quotation and its date without refreshing it" do
    with_candidate_cli do |conn|
      date = Time.utc(2026, 10, 2, 16, 30)
      JediSpec.insert_security(conn, quotation_price: 12.5, quotation_date: date)

      output = run_candidate_cli(conn, ["--amount=1000"])

      output.should contain(I18n.t("tools.candidate.price_sources.stored"))
      output.should contain(date.to_local.to_s("%F %T %:z"))
      output.should contain("12.50 €")
      security = Jedi::Exchange::Security.new(conn, "FR4487601001")
      security.quotation_price.should eq(12.5)
      security.quotation_date.should eq(date)
    end
  end

  it "does not attribute a stored quotation date to an explicit override" do
    with_candidate_cli do |conn|
      JediSpec.insert_security(conn, quotation_price: 125.0, quotation_date: Time.utc(2020, 1, 2))

      output = run_candidate_cli(conn, ["--price=10", "--amount=1000", "--extended"])

      output.should contain(I18n.t("tools.candidate.price_sources.explicit"))
      output.should_not contain(I18n.t("tools.candidate.report.price_date"))
      output.should_not contain("2020-01")
      Jedi::Exchange::Security.new(conn, "FR4487601001").quotation_price.should eq(125.0)
    end
  end

  it "rejects non-finite prices amounts and capitals at the CLI boundary" do
    with_candidate_cli do |conn|
      {"price", "amount", "capital"}.each do |option|
        {"NaN", "inf"}.each do |value|
          JediCliSpec.expect_failure(
            conn, "tools", "candidate", "--#{option}=#{value}",
            key: "tools.candidate.invalid_#{option}",
          )
        end
      end
    end
  end

  it "reports unavailable funding when no portfolio capital is configured" do
    with_candidate_cli do |conn|
      Jedi::App.config = YAML.parse(Jedi::App::YAML_CONFIG.sub("capital: 20000", "capital: 0"))

      output = run_candidate_cli(conn, ["--price=10", "--amount=1000"])

      output.should contain(I18n.t("tools.candidate.funding.not_evaluated"))
      output.should_not contain(I18n.t("tools.candidate.report.margin_after_candidate"))
      output.should_not contain("missing translation")
    end
  end

  it "reports the candidate funding requirement in French" do
    with_candidate_cli do |conn|
      Jedi.init_i18n("fr")

      output = run_candidate_cli(conn, ["--price=10", "--amount=1000", "--capital=3000"])

      output.should contain("fourni par --price")
      output.should contain("Besoin maximal du candidat")
      output.should contain("Réserve du candidat calculée sur 3 échelons ; financement hors frais.")
      output.should_not contain("missing translation")
    end
  end
end
