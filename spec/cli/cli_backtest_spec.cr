require "../support/cli_spec_helper"

private def with_compact_backtest_cli(&)
  JediCliSpec.with_cli_db do |conn|
    previous_capital = Jedi::App.capital
    previous_distance = Jedi::App.distance
    previous_risk_rate = Jedi::App.risk_rate
    previous_initial_investment = Jedi::App.initial_investment
    previous_simulation = Jedi::App.simulation

    begin
      Jedi.init_i18n("en")
      Jedi::App.capital = 20_000
      Jedi::App.distance = 0.20
      Jedi::App.risk_rate = 0.015
      yield conn
    ensure
      Jedi::App.capital = previous_capital
      Jedi::App.distance = previous_distance
      Jedi::App.risk_rate = previous_risk_rate
      Jedi::App.initial_investment = previous_initial_investment
      Jedi::App.simulation = previous_simulation
    end
  end
end

private def run_compact_backtest_cli(conn : DB::Connection, options : Array(String) = [] of String) : String
  filename = File.expand_path("../fixtures/tools/backtest_quotes.csv", __DIR__)
  JediCliSpec.run(conn, [
    "tools", "backtest", filename,
    "--scale=vr:15%,np:4,nn:4,ki:15%,kb:1,kd:0.0",
  ] + options)
end

describe "KISS backtest CLI" do
  it "shows only the compact economic summary by default" do
    with_compact_backtest_cli do |conn|
      output = run_compact_backtest_cli(conn)

      output.should contain(I18n.t("tools.backtest.compact.net_gain", {:value => "54.75"}))
      output.should_not contain("Correlation coefficient")
      output.should_not contain(I18n.t("trade.results.list.table.title.one"))
      output.should_not contain("missing translation")
    end
  end

  it "restores the full summary and per-trade results with technical display" do
    with_compact_backtest_cli do |conn|
      output = run_compact_backtest_cli(conn, ["--display=TECHNICAL"])

      output.should contain("Correlation coefficient")
      output.should contain(I18n.t("trade.results.list.table.title.one"))
      output.should_not contain("missing translation")
    end
  end

  it "honors explicit section selection in compact and technical modes" do
    with_compact_backtest_cli do |conn|
      financial = run_compact_backtest_cli(conn, ["-c", "f"])
      financial.should contain(I18n.t("trade.results.list.table.title.one"))
      financial.should_not contain(I18n.t("tools.backtest.table.title"))

      technical = run_compact_backtest_cli(conn, ["--display=technical", "-c", "r"])
      technical.should contain("Correlation coefficient")
      technical.should_not contain(I18n.t("trade.results.list.table.title.one"))
    end
  end

  it "rejects unsupported display modes" do
    with_compact_backtest_cli do |conn|
      JediCliSpec.expect_failure(
        conn, "tools", "backtest", "--display=study",
        key: "tools.backtest.display.invalid_mode",
      )
    end
  end

  it "reports invalid backtest capital with the backtest error key" do
    with_compact_backtest_cli do |conn|
      ["-1", "NaN", "inf"].each do |value|
        JediCliSpec.expect_failure(
          conn, "tools", "backtest", "--capital=#{value}",
          key: "tools.backtest.invalid_capital",
        )
      end
    end
  end

  it "renders the compact summary in French as well as English" do
    with_compact_backtest_cli do |conn|
      Jedi.init_i18n("fr")
      output = run_compact_backtest_cli(conn)

      output.should contain("Gain net cumulé : 54.75 €")
      output.should contain("Titres détenus en fin de test : 150 ; valeur 1560.00 €")
      output.should_not contain("missing translation")
    end
  end
end
