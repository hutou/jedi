require "../spec_helper"

describe "Jedi exception boundary" do
  it "builds AppException only in App.raise_from_low_level" do
    root = File.expand_path("../..", __DIR__)
    helpers = File.join(root, "src/jedi/app/helpers.cr")
    offenders = [] of String

    Dir[File.join(root, "src/**/*.cr")].sort.each do |filename|
      next if filename == helpers

      line_number = 0
      File.each_line(filename) do |line|
        line_number += 1
        if line.includes?("AppException.new")
          offenders << "#{filename}:#{line_number}"
        end
      end
    end

    inside_conversion = false
    line_number = 0
    File.each_line(helpers) do |line|
      line_number += 1
      if line.includes?("def self.raise_from_low_level(")
        inside_conversion = true
      elsif line.includes?("private def self.log_exception(")
        inside_conversion = false
      elsif line.includes?("AppException.new") && !inside_conversion
        offenders << "#{helpers}:#{line_number}"
      end
    end

    offenders.should be_empty
  end

  it "catches AppException only at the top-level CLI boundary" do
    root = File.expand_path("../..", __DIR__)
    entrypoint = File.join(root, "src/jedi.cr")
    offenders = [] of String

    Dir[File.join(root, "src/**/*.cr")].sort.each do |filename|
      next if filename == entrypoint

      line_number = 0
      File.each_line(filename) do |line|
        line_number += 1
        if line.matches?(/rescue\s+\w+\s*:\s*AppException/)
          offenders << "#{filename}:#{line_number}"
        end
      end
    end

    offenders.should be_empty
  end

  it "converts a user-input error into a warning at the application boundary" do
    low_level = Jedi::LowLevelError.new(
      "invalid value",
      key: "infra.invalid_argument",
      context: {:arg => "bad"},
      kind: Jedi::LowLevelError::Kind::UserInput,
    )

    app_error = expect_raises(Jedi::AppException) do
      Jedi::App.raise_from_low_level(
        low_level,
        context: {:cmd => "jedi tools score --help"},
        help_key: "infra.jedi_help",
      )
    end

    app_error.level.should eq(Jedi::AppException::Level::Warn)
    app_error.key.should eq("infra.invalid_argument")
    app_error.context.should eq({
      :arg => "bad",
      :cmd => "jedi tools score --help",
    })
    app_error.help_key.should eq("infra.jedi_help")
    app_error.cause.should be(low_level)
  end

  it "converts invalid persistent data into an error with the logfile hint" do
    JediSpec.configure_app
    low_level = Jedi::LowLevelError.new(
      "invalid stored value",
      key: "infra.corrupted_data",
      context: {
        :field  => "value",
        :value  => "bad",
        :entity => "trade",
        :id     => "1",
      },
      kind: Jedi::LowLevelError::Kind::InvalidData,
    )

    app_error = expect_raises(Jedi::AppException) do
      Jedi::App.raise_from_low_level(low_level)
    end

    app_error.level.should eq(Jedi::AppException::Level::Error)
    app_error.key.should eq("infra.corrupted_data")
    app_error.context[:logfile].should eq(Jedi::App.log_file)
    app_error.help_key.should eq("infra.see_logfile")
    app_error.cause.should be(low_level)
  end
end
