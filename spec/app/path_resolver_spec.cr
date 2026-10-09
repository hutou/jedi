require "../spec_helper"
require "../support/path_workspace"

describe Jedi::App::PathResolver do
  it "keeps production in XDG regardless of the current directory" do
    JediPathsSpec.with_workspace do |root|
      paths = Jedi::App::PathResolver.resolve(Jedi::App::Env::Prod)
      paths.config_file.should eq(File.join(root, "xdg/config/jedi/jedi.conf"))
      paths.log_file.should eq(File.join(root, "xdg/state/jedi/jedi.log"))
      paths.db_file.should eq(File.join(root, "xdg/data/jedi/jedi.db"))
      paths.market_dir.should eq(File.join(root, "xdg/data/jedi/market"))

      other = File.join(root, "other workspace")
      Dir.mkdir_p(other)
      Dir.cd(other) do
        Jedi::App::PathResolver.resolve(Jedi::App::Env::Prod).should eq(paths)
      end
    end
  end

  it "isolates all test and development paths in the current workspace" do
    JediPathsSpec.with_workspace do |root|
      {Jedi::App::Env::Test => "test", Jedi::App::Env::Dev => "dev"}.each do |env, name|
        base = File.join(root, "jedi/env_#{name}")
        paths = Jedi::App::PathResolver.resolve(env)

        paths.config_file.should eq(File.join(base, "conf/jedi_#{name}.conf"))
        paths.log_file.should eq(File.join(base, "log/jedi_#{name}.log"))
        paths.db_file.should eq(File.join(base, "data/jedi_#{name}.db"))
        paths.market_dir.should eq(File.join(base, "market"))
      end
    end
  end

  it "creates distinct default database and market paths for each test directory" do
    JediPathsSpec.with_workspace do |root|
      first = Jedi::App::PathResolver.resolve(Jedi::App::Env::Test)
      other = File.join(root, "second test")
      Dir.mkdir_p(other)
      Dir.cd(other) do
        second = Jedi::App::PathResolver.resolve(Jedi::App::Env::Test)
        second.db_file.should eq(File.join(other, "jedi/env_test/data/jedi_test.db"))
        second.db_file.should_not eq(first.db_file)
        second.market_dir.should eq(File.join(other, "jedi/env_test/market"))
        second.market_dir.should_not eq(first.market_dir)
      end
    end
  end

  it "does not duplicate the jedi directory in a project named jedi" do
    JediPathsSpec.with_workspace do |root|
      project = File.join(root, "jedi")
      Dir.mkdir_p(project)
      Dir.cd(project) do
        {Jedi::App::Env::Test => "test", Jedi::App::Env::Dev => "dev"}.each do |env, name|
          paths = Jedi::App::PathResolver.resolve(env)
          paths.db_file.should eq(File.join(project, "env_#{name}/data/jedi_#{name}.db"))
          paths.market_dir.should eq(File.join(project, "env_#{name}/market"))
        end
      end
    end
  end

  it "keeps explicit market overrides ahead of environment and default paths" do
    JediPathsSpec.with_workspace do |root|
      ENV["JEDI_MARKET_DIR"] = "shared market/"
      Jedi::App::PathResolver.resolve(Jedi::App::Env::Test).market_dir
        .should eq(File.join(root, "shared market"))

      overrides = Jedi::App::PathOverrides.new(market_dir: "explicit market/")
      Jedi::App::PathResolver.resolve(Jedi::App::Env::Dev, overrides).market_dir
        .should eq(File.join(root, "explicit market"))

      ENV["JEDI_MARKET_DIR"] = " "
      Jedi::App::PathResolver.resolve(Jedi::App::Env::Test).market_dir
        .should eq(File.join(root, "jedi/env_test/market"))
    end
  end
end

describe "Jedi environment selection" do
  it "defaults to production even for a binary built with -DDEV" do
    JediPathsSpec.with_workspace do
      Jedi::App.default_env.should eq(Jedi::App::Env::Prod)
      Jedi::App.parse_env(nil).should eq(Jedi::App::Env::Prod)
      Jedi::App.parse_env("").should eq(Jedi::App::Env::Prod)
    end
  end

  it "keeps explicit test and development selection available" do
    JediPathsSpec.with_workspace do
      ENV["JEDI_ENV"] = "test"
      Jedi::App.parse_env(nil).should eq(Jedi::App::Env::Test)
      ENV["JEDI_ENV"] = "dev"
      Jedi::App.parse_env(nil).should eq(Jedi::App::Env::Dev)
      Jedi::App.parse_env("prod").should eq(Jedi::App::Env::Prod)
    end
  end
end
