require "../spec_helper"

module BuildContractSpec
  extend self

  ROOT = File.expand_path("../..", __DIR__)

  def manifest : YAML::Any
    YAML.parse(File.read(File.join(ROOT, "shard.yml")))
  end

  def lockfile : YAML::Any
    YAML.parse(File.read(File.join(ROOT, "shard.lock")))
  end
end

describe "Jedi build contract" do
  it "builds the published CLI from the jedi target" do
    target = BuildContractSpec.manifest["targets"]["jedi"]

    target["main"].as_s.should eq("src/jedi_cli.cr")
    BuildContractSpec.manifest["targets"].as_h
      .has_key?(YAML::Any.new("jedi_dev")).should be_false

    entrypoint = File.read(
      File.join(BuildContractSpec::ROOT, target["main"].as_s)
    )
    entrypoint.should contain("exit Jedi.run_cli")
  end

  it "declares the Crystal versions validated for Jedi 1.0" do
    BuildContractSpec.manifest["crystal"].as_s
      .should eq(">= 1.21.0, < 2.0")
  end

  it "pins Ameba to the compatible 1.7.0 release" do
    ameba = BuildContractSpec.manifest["development_dependencies"]["ameba"]

    ameba["version"].as_s.should eq("1.7.0")
    ameba.as_h.has_key?(YAML::Any.new("branch")).should be_false
    BuildContractSpec.lockfile["shards"]["ameba"]["version"].as_s
      .should eq("1.7.0")
  end

  it "keeps debug as a development-only dependency" do
    manifest = BuildContractSpec.manifest
    debug = manifest["development_dependencies"]["debug"]
    source = File.read(File.join(BuildContractSpec::ROOT, "src/jedi.cr"))

    debug["version"].as_s.should eq("2.0.4")
    BuildContractSpec.lockfile["shards"]["debug"]["version"].as_s
      .should eq("2.0.4")
    source.should_not contain(%(require "debug"))
  end

  it "allows builds from source archives without Git metadata" do
    source = File.read(File.join(BuildContractSpec::ROOT, "src/jedi.cr"))

    source.should contain(%(env("JEDI_GIT_COMMIT") || "unknown"))
    source.should_not contain("git rev-parse")
  end

  it "does not contain duplicate top-level requires" do
    source = File.read(File.join(BuildContractSpec::ROOT, "src/jedi.cr"))
    requires = source.lines
      .select(&.starts_with?("require \""))
      .map(&.strip)

    requires.should eq(requires.uniq)
  end
end
