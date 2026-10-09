require "../spec_helper"
require "../support/path_workspace"

module JediLaunchersSpec
  extend self

  ROOT = File.expand_path("../..", __DIR__)

  def prepare(root : String) : Nil
    binary = File.join(root, "internal jedi")
    File.write(binary, <<-BASH)
      #!/usr/bin/env bash
      printf '%s\\0' "$PWD" "${JEDI_ENV-}" "${JEDI_CONFIG_DIR-}" "${JEDI_LOG_DIR-}" "${JEDI_DATA_DIR-}" "${JEDI_DB_FILE-}" "${JEDI_MARKET_DIR-}"
      if [[ "$#" -gt 0 ]]; then
        printf '%s\\0' "$@"
      fi
      exit 17
      BASH
    File.chmod(binary, 0o755)

    %w(jedi jedidemo jedidev).each do |name|
      source = File.read(File.join(ROOT, "launchers", name))
      # Substitute the installation path in a private copy; never change HOME.
      source = source.gsub("$HOME/.local/libexec/jedi", binary)
      target = File.join(root, name)
      File.write(target, source)
      File.chmod(target, 0o755)
    end
  end

  def run(command : String, args : Array(String) = [] of String)
    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run(command, args, output: output, error: error)
    {status.exit_code, output.to_s, error.to_s}
  end

  def poison_paths : Nil
    ENV["JEDI_ENV"] = "dev"
    %w(JEDI_CONFIG_DIR JEDI_LOG_DIR JEDI_DATA_DIR JEDI_DB_FILE JEDI_MARKET_DIR).each do |key|
      ENV[key] = "/stale/#{key.downcase}"
    end
  end
end

describe "Jedi launchers" do
  it "forces production and clears inherited Jedi paths while preserving arguments and status" do
    JediPathsSpec.with_workspace do |root|
      JediLaunchersSpec.prepare(root)
      JediLaunchersSpec.poison_paths
      args = ["note", "texte avec espaces et accents é", "ligne 1\nligne 2", ""]
      code, output, error = JediLaunchersSpec.run(File.join(root, "jedi"), args)
      fields = output.split('\0')

      code.should eq(17)
      error.should be_empty
      fields[0, 2].should eq([root, "prod"])
      fields[2, 5].should eq(Array.new(5, ""))
      fields[7, args.size].should eq(args)
    end
  end

  it "selects the demo directory and leaves market resolution to the test defaults" do
    JediPathsSpec.with_workspace do |root|
      JediLaunchersSpec.prepare(root)
      JediLaunchersSpec.poison_paths
      demo = File.join(root, "demo with spaces")
      Dir.mkdir_p(demo)
      ENV["JEDI_DEMO_DIR"] = demo
      ENV["CDPATH"] = "/tmp"
      code, output, error = JediLaunchersSpec.run(File.join(root, "jedidemo"))
      fields = output.split('\0')

      code.should eq(17)
      error.should be_empty
      fields[0, 2].should eq([demo, "test"])
      fields[2, 5].should eq(Array.new(5, ""))
    end
  end

  it "allows a deliberately selected market directory for demo and development" do
    JediPathsSpec.with_workspace do |root|
      JediLaunchersSpec.prepare(root)
      JediLaunchersSpec.poison_paths
      ENV["JEDI_DEMO_DIR"] = root
      ENV["JEDI_DEMO_MARKET_DIR"] = "demo market"
      ENV["JEDI_DEV_MARKET_DIR"] = File.join(root, "shared market")

      {"jedidemo" => "demo market", "jedidev" => File.join(root, "shared market")}.each do |name, market|
        code, output, error = JediLaunchersSpec.run(File.join(root, name))
        fields = output.split('\0')
        code.should eq(17)
        error.should be_empty
        fields[2, 4].should eq(Array.new(4, ""))
        fields[6].should eq(market)
      end
    end
  end

  it "uses the current project directory for development unless explicitly selected" do
    JediPathsSpec.with_workspace do |root|
      JediLaunchersSpec.prepare(root)
      JediLaunchersSpec.poison_paths
      code, output, error = JediLaunchersSpec.run(File.join(root, "jedidev"))
      code.should eq(17)
      error.should be_empty
      output.split('\0')[0, 7].should eq([root, "dev", "", "", "", "", ""])

      project = File.join(root, "another project")
      Dir.mkdir_p(project)
      ENV["JEDI_DEV_DIR"] = project
      _, output, _ = JediLaunchersSpec.run(File.join(root, "jedidev"))
      output.split('\0')[0, 2].should eq([project, "dev"])
    end
  end

  it "runs a contributor's selected binary from the project directory" do
    JediPathsSpec.with_workspace do |root|
      JediLaunchersSpec.prepare(root)
      binary = File.join(root, "compiled core")
      File.write(binary, "#!/usr/bin/env bash\nprintf '%s' \"$JEDI_ENV\"\nexit 23\n")
      File.chmod(binary, 0o755)
      ENV["JEDI_DEV_BINARY"] = "./compiled core"

      code, output, error = JediLaunchersSpec.run(File.join(root, "jedidev"))
      code.should eq(23)
      output.should eq("dev")
      error.should be_empty
    end
  end

  it "fails before running the binary if a demo or development directory is missing" do
    JediPathsSpec.with_workspace do |root|
      JediLaunchersSpec.prepare(root)
      ENV["JEDI_DEMO_DIR"] = File.join(root, "missing demo")
      ENV["JEDI_DEV_DIR"] = File.join(root, "missing project")
      %w(jedidemo jedidev).each do |name|
        code, output, error = JediLaunchersSpec.run(File.join(root, name))
        code.should eq(1)
        output.should be_empty
        error.should_not be_empty
      end
    end
  end

  it "reports a missing internal binary without searching PATH for jedi" do
    JediPathsSpec.with_workspace do |root|
      JediLaunchersSpec.prepare(root)
      ENV["JEDI_DEMO_DIR"] = root
      File.delete(File.join(root, "internal jedi"))
      %w(jedi jedidemo jedidev).each do |name|
        code, output, error = JediLaunchersSpec.run(File.join(root, name))
        code.should eq(127)
        output.should be_empty
        error.should contain("Jedi binary missing or not executable")
      end
    end
  end

  it "rejects sourcing before changing the caller's directory or environment" do
    JediPathsSpec.with_workspace do |root|
      JediLaunchersSpec.prepare(root)
      ENV["JEDI_ENV"] = "prod"
      %w(jedi jedidemo jedidev).each do |name|
        command = <<-BASH
          before="$PWD"
          source "$1"
          status=$?
          [[ "$status" == 1 && "$PWD" == "$before" && "$JEDI_ENV" == prod ]] || exit 99
          BASH
        code, output, error = JediLaunchersSpec.run("bash", ["-c", command, "source-test", File.join(root, name)])
        code.should eq(0)
        output.should be_empty
        error.should contain("do not source")
      end
    end
  end

  it "preserves the parent shell's directory and environment on normal execution" do
    JediPathsSpec.with_workspace do |root|
      JediLaunchersSpec.prepare(root)
      ENV["JEDI_ENV"] = "prod"
      ENV["JEDI_DEMO_DIR"] = root
      %w(jedidemo jedidev).each do |name|
        command = <<-BASH
          before="$PWD"
          "$1" >/dev/null
          status=$?
          [[ "$status" == 17 && "$PWD" == "$before" && "$JEDI_ENV" == prod ]] || exit 99
          BASH
        code, output, error = JediLaunchersSpec.run("bash", ["-c", command, "parent-test", File.join(root, name)])
        code.should eq(0)
        output.should be_empty
        error.should be_empty
      end
    end
  end
end
