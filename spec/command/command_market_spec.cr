require "../market_data/spec_helper"

describe Jedi::MarketSubCommand do
  it "routes market init and market info" do
    JediMarketSpec.with_workspace do |_workspace|
      JediMarketSpec.initialize_i18n

      DB.open("sqlite3://%3Amemory%3A") do |db|
        db.using_connection do |conn|
          init_output = IO::Memory.new

          JediMarketSpec.with_argv(["init", "cli_spec"]) do
            Jedi::MarketSubCommand.new(
              conn,
              output: init_output
            ).parser_on_market
          end

          File.file?(
            Jedi::App.market_db_file("cli_spec")
          ).should be_true
          default_database = "cli_spec_#{Jedi::App.default_market_universe}.db"
          init_output.to_s.should contain(default_database)

          info_output = IO::Memory.new
          JediMarketSpec.with_argv(["info", "cli_spec"]) do
            Jedi::MarketSubCommand.new(
              conn,
              output: info_output
            ).parser_on_market
          end

          info_output.to_s.should contain("Version du schéma")
          info_output.to_s.should contain(default_database)
        end
      end
    end
  end

  it "uses the configured default universe and allows init to override it" do
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

        DB.open("sqlite3://%3Amemory%3A") do |db|
          db.using_connection do |conn|
            output = IO::Memory.new
            JediMarketSpec.with_argv(["init", "cli_default"]) do
              Jedi::MarketSubCommand.new(conn, output: output).parser_on_market
            end

            Jedi::App.default_market_universe.should eq("europe")
            File.file?(Jedi::App.market_db_file("cli_default")).should be_true
            output.to_s.should contain("cli_default_europe.db")

            override_output = IO::Memory.new
            JediMarketSpec.with_argv([
              "init", "cli_override", "--universe=belgium",
            ]) do
              Jedi::MarketSubCommand.new(
                conn,
                output: override_output,
              ).parser_on_market
            end

            File.file?(
              Jedi::App.market_db_file("cli_override", "belgium")
            ).should be_true
            override_output.to_s.should contain("cli_override_belgium.db")
          end
        end
      ensure
        Jedi::App.config = previous_config
      end
    end
  end

  it "exposes dataset update subcommand" do
    JediMarketSpec.with_workspace do |_workspace|
      JediMarketSpec.initialize_i18n

      DB.open("sqlite3://%3Amemory%3A") do |db|
        db.using_connection do |conn|
          output = IO::Memory.new

          JediMarketSpec.with_argv([] of String) do
            Jedi::MarketSubCommand.new(
              conn,
              output: output
            ).parser_on_market
          end

          text = output.to_s
          text.should contain("update")
          text.should_not contain("update-security")
        end
      end
    end
  end
  it "routes market list with regex and dataset selection" do
    JediMarketSpec.with_workspace do |_workspace|
      JediMarketSpec.initialize_i18n
      database = JediMarketSpec.initialized_database("cli_list")

      Jedi::MarketData::MarketImporter.new(
        database,
        "dataset_a",
        JediMarketSpec.fixture("quotes_dataset_a.csv"),
        JediMarketSpec.fixture("labels.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run
      Jedi::MarketData::MarketImporter.new(
        database,
        "dataset_b",
        JediMarketSpec.fixture("quotes_dataset_b.csv"),
        JediMarketSpec.fixture("labels.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      DB.open("sqlite3://%3Amemory%3A") do |db|
        db.using_connection do |conn|
          output = IO::Memory.new

          JediMarketSpec.with_argv(["list", "cli_list", "ticker=^AL"]) do
            Jedi::MarketSubCommand.new(
              conn,
              output: output
            ).parser_on_market
          end

          text = output.to_s
          text.should contain("FR4487601001")
          text.should contain("Alpha")
          text.should_not contain("Beta")

          dataset_output = IO::Memory.new
          JediMarketSpec.with_argv(["list", "cli_list", "--dataset=dataset_b"]) do
            Jedi::MarketSubCommand.new(
              conn,
              output: dataset_output
            ).parser_on_market
          end

          dataset_text = dataset_output.to_s
          dataset_text.should contain("Alpha")
          dataset_text.should_not contain("Dataset(s)")
          dataset_text.should_not contain("dataset_a, dataset_b")
          dataset_text.should_not contain("Beta")
        end
      end
    end
  end

  it "routes market quote with date and record selections" do
    JediMarketSpec.with_workspace do |_workspace|
      JediMarketSpec.initialize_i18n
      database = JediMarketSpec.initialized_database("cli_quote")

      Jedi::MarketData::MarketImporter.new(
        database,
        "dataset_b",
        JediMarketSpec.fixture("quotes_dataset_b.csv"),
        JediMarketSpec.fixture("labels.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      DB.open("sqlite3://%3Amemory%3A") do |db|
        db.using_connection do |conn|
          output = IO::Memory.new

          JediMarketSpec.with_argv([
            "quote",
            "cli_quote",
            "FR4487601001",
            "--date=ge:2020-01-02",
            "--select=l1",
          ]) do
            Jedi::MarketSubCommand.new(
              conn,
              output: output
            ).parser_on_market
          end

          text = output.to_s
          text.should_not contain("2020-01-02")
          text.should contain("2020-01-03")
          text.should contain("Volume")
        end
      end
    end
  end

  it "routes named-group synchronization and manual membership updates" do
    JediMarketSpec.with_workspace do |_workspace|
      JediMarketSpec.initialize_i18n
      database = JediMarketSpec.initialized_database("cli_pea")

      Jedi::MarketData::MarketImporter.new(
        database,
        "dataset_a",
        JediMarketSpec.fixture("quotes_dataset_a.csv"),
        JediMarketSpec.fixture("labels.csv"),
        date_order: Jedi::MarketData::DateOrder::Ymd
      ).run

      DB.open("sqlite3://%3Amemory%3A") do |db|
        db.using_connection do |conn|
          sync_output = IO::Memory.new
          JediMarketSpec.with_argv([
            "sync-group", "cli_pea", "PEA",
            JediMarketSpec.fixture("pea_references.txt"),
            "--reference-source=prorealtime",
          ]) do
            Jedi::MarketSubCommand.new(conn, output: sync_output).parser_on_market
          end
          sync_output.to_s.should contain("PEA")

          group_output = IO::Memory.new
          JediMarketSpec.with_argv([
            "group", "cli_pea", "PEA", "FR4487601001", "--remove",
          ]) do
            Jedi::MarketSubCommand.new(conn, output: group_output).parser_on_market
          end
        end
      end

      JediMarketSpec.count(
        database,
        "SELECT COUNT(*) FROM security_groups " \
        "WHERE group_code = 'PEA' AND isin = 'FR4487601001'"
      ).should eq(0_i64)
    end
  end
  it "interpolates the configured universe in market option help" do
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
        "market.options.universe",
        universe: Jedi::App.default_market_universe,
      )

      text.should contain("europe")
      text.should_not contain("%{universe}")
    ensure
      Jedi::App.config = previous_config
    end
  end
end
