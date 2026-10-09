require "../market_data/spec_helper"

private def tools_command_fixture(name : String) : String
  File.expand_path(
    File.join("../fixtures/tools", name),
    __DIR__,
  )
end

private def seed_tools_market_database(
  source : String,
  universe : String,
) : Jedi::MarketData::Database
  database = Jedi::MarketData::Database.new(source, universe)
  Jedi::MarketData::MarketInitializer.new(database).run
  history = Jedi::MarketData::PreparedQuotesFileLoader.new(
    tools_command_fixture("backtest_quotes.csv")
  ).load

  database.with_connection do |conn|
    Jedi::MarketData::SecurityRepository.new(conn).insert(history.security)
    quotes = Jedi::MarketData::QuoteRepository.new(conn)
    history.quotes.each do |quote|
      quotes.insert(history.isin, quote)
    end
  end

  database
end

private def add_tools_market_group(
  database : Jedi::MarketData::Database,
  code : String,
  isins : Array(String),
) : Nil
  database.with_connection do |conn|
    repository = Jedi::MarketData::GroupRepository.new(conn)
    repository.upsert(code, "test", Time.utc(2026, 1, 1), "2026-01-01T00:00:00Z")
    repository.replace_members(code, isins)
  end
end

describe Jedi::ToolsSubCommand do
  it "uses the configured market universe when --universe is omitted" do
    JediMarketSpec.with_workspace do |_workspace|
      JediMarketSpec.initialize_i18n
      previous_config = Jedi::App.config

      begin
        Jedi::App.config = YAML.parse(
          Jedi::App::YAML_CONFIG.sub(
            "default_universe: france",
            "default_universe: europe",
          )
        )
        seed_tools_market_database("cli_tools", "europe")

        DB.open("sqlite3://%3Amemory%3A") do |db|
          db.using_connection do |conn|
            output = IO::Memory.new

            JediMarketSpec.with_argv([
              "stats",
              "--database=cli_tools",
              "--security=FR4487601001",
            ]) do
              Jedi::ToolsSubCommand.new(
                conn,
                output: output,
              ).parser_on_tools
            end

            output.to_s.should_not be_empty
          end
        end
      ensure
        Jedi::App.config = previous_config
      end
    end
  end

  it "uses the collection profile by default for a market selection" do
    JediMarketSpec.with_workspace do
      JediMarketSpec.initialize_i18n
      database = seed_tools_market_database("cli_profile", "france")
      add_tools_market_group(database, "PEA", ["FR4487601001"])

      DB.open("sqlite3://%3Amemory%3A") do |db|
        db.using_connection do |conn|
          output = IO::Memory.new

          JediMarketSpec.with_argv([
            "profile",
            "--database=cli_profile",
            "--group=PEA",
            "--rank-criteria=4",
          ]) do
            Jedi::ToolsSubCommand.new(
              conn,
              output: output,
            ).parser_on_tools
          end

          report = output.to_s
          report.should contain(I18n.t("tools.profile.collection.title"))
          report.should contain(
            I18n.t("tools.profile.collection.ranking_criteria_value", {:used => "4"})
          )
        end
      end
    end
  end
  it "rejects an invalid number of profile ranking criteria" do
    JediMarketSpec.initialize_i18n

    DB.open("sqlite3://%3Amemory%3A") do |db|
      db.using_connection do |conn|
        ["0", "8", "x"].each do |value|
          ex = expect_raises(Jedi::AppException) do
            JediMarketSpec.with_argv(["profile", "--rank-criteria=#{value}"]) do
              Jedi::ToolsSubCommand.new(
                conn,
                output: IO::Memory.new,
              ).parser_on_tools
            end
          end

          ex.key.should eq("tools.profile.collection.invalid_rank_criteria")
        end
      end
    end
  end

  it "rejects profile options removed from the public CLI" do
    JediMarketSpec.initialize_i18n

    removed_options = [
      "--walk-forward",
      "--momentum-study",
      "--selection-study",
      "--selection-rank",
      "--selection-holdout",
      "--signature=2026-02-19",
      "--signature-study",
      "--signature-validate",
      "--signature-learn",
      "--signature-rank",
      "--signature-holdout",
      "--extended",
    ]

    DB.open("sqlite3://%3Amemory%3A") do |db|
      db.using_connection do |conn|
        removed_options.each do |option|
          ex = expect_raises(Jedi::AppException) do
            JediMarketSpec.with_argv(["profile", option]) do
              Jedi::ToolsSubCommand.new(
                conn,
                output: IO::Memory.new,
              ).parser_on_tools
            end
          end

          ex.key.should eq("infra.invalid_option")
        end
      end
    end
  end

  it "interpolates the configured universe in tool option help" do
    JediMarketSpec.initialize_i18n
    previous_config = Jedi::App.config

    begin
      Jedi::App.config = YAML.parse(
        Jedi::App::YAML_CONFIG.sub(
          "default_universe: france",
          "default_universe: europe",
        )
      )

      text = I18n.t(
        "tools.backtest.option_universe",
        universe: Jedi::App.default_market_universe,
      )

      text.should contain("europe")
      text.should_not contain("%{universe}")
    ensure
      Jedi::App.config = previous_config
    end
  end
end
