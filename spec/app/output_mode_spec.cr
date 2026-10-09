require "../spec_helper"

describe "Jedi::App output mode" do
  before_each do
    JediSpec.configure_app
    Jedi::App.output_mode = Jedi::App::OutputMode::Normal
  end

  describe ".default_output_mode" do
    it "uses Normal mode for regular commands" do
      Jedi::App.default_output_mode(simulation: false).should eq(Jedi::App::OutputMode::Normal)
    end

    it "uses Simulation mode for simulation commands" do
      Jedi::App.default_output_mode(simulation: true).should eq(Jedi::App::OutputMode::Simulation)
    end
  end

  describe ".resolve_output_mode" do
    it "keeps regular commands in Normal mode by default" do
      mode = Jedi::App.resolve_output_mode(
        simulation: false,
        verbose: false
      )

      mode.should eq(Jedi::App::OutputMode::Normal)
    end

    it "keeps simulation commands in Simulation mode by default" do
      mode = Jedi::App.resolve_output_mode(
        simulation: true,
        verbose: false
      )

      mode.should eq(Jedi::App::OutputMode::Simulation)
    end

    it "forces Verbose mode for regular commands when --verbose is requested" do
      mode = Jedi::App.resolve_output_mode(
        simulation: false,
        verbose: true
      )

      mode.should eq(Jedi::App::OutputMode::Verbose)
    end

    it "forces Verbose mode for simulation commands when --verbose is requested" do
      mode = Jedi::App.resolve_output_mode(
        simulation: true,
        verbose: true
      )

      mode.should eq(Jedi::App::OutputMode::Verbose)
    end
  end

  describe ".apply_output_mode!" do
    it "stores Normal mode for regular commands by default" do
      Jedi::App.apply_output_mode!(
        simulation: false,
        verbose: false
      )

      Jedi::App.output_mode.should eq(Jedi::App::OutputMode::Normal)
    end

    it "stores Simulation mode for simulation commands by default" do
      Jedi::App.apply_output_mode!(
        simulation: true,
        verbose: false
      )

      Jedi::App.output_mode.should eq(Jedi::App::OutputMode::Simulation)
    end

    it "stores Verbose mode when --verbose is requested" do
      Jedi::App.apply_output_mode!(
        simulation: true,
        verbose: true
      )

      Jedi::App.output_mode.should eq(Jedi::App::OutputMode::Verbose)
    end
  end

  describe "message display policy" do
    it "displays info, warn and error messages in Normal mode" do
      mode = Jedi::App::OutputMode::Normal

      mode.display?(Jedi::App::Message::Level::Info).should be_true
      mode.display?(Jedi::App::Message::Level::Warn).should be_true
      mode.display?(Jedi::App::Message::Level::Error).should be_true
    end

    it "hides info messages but displays warn and error messages in Simulation mode" do
      mode = Jedi::App::OutputMode::Simulation

      mode.display?(Jedi::App::Message::Level::Info).should be_false
      mode.display?(Jedi::App::Message::Level::Warn).should be_true
      mode.display?(Jedi::App::Message::Level::Error).should be_true
    end

    it "displays info, warn and error messages in Verbose mode" do
      mode = Jedi::App::OutputMode::Verbose

      mode.display?(Jedi::App::Message::Level::Info).should be_true
      mode.display?(Jedi::App::Message::Level::Warn).should be_true
      mode.display?(Jedi::App::Message::Level::Error).should be_true
    end
  end

  describe ".with_output_mode" do
    it "restores the previous output mode after the block" do
      Jedi::App.output_mode = Jedi::App::OutputMode::Normal

      Jedi::App.with_output_mode(Jedi::App::OutputMode::Simulation) do
        Jedi::App.output_mode.should eq(Jedi::App::OutputMode::Simulation)
      end

      Jedi::App.output_mode.should eq(Jedi::App::OutputMode::Normal)
    end

    it "restores the previous output mode even if the block raises" do
      Jedi::App.output_mode = Jedi::App::OutputMode::Verbose

      expect_raises(Exception, "boom") do
        Jedi::App.with_output_mode(Jedi::App::OutputMode::Simulation) do
          raise "boom"
        end
      end

      Jedi::App.output_mode.should eq(Jedi::App::OutputMode::Verbose)
    end
  end
end
