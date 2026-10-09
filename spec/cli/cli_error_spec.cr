require "../spec_helper"
require "../support/cli_spec_helper"

describe Jedi::Command, "CLI error routing" do
  it "rejects an unknown top-level command" do
    JediCliSpec.with_cli_db do |conn|
      JediCliSpec.expect_failure(conn,
        ["unknown-command"],
        "infra.unknown_command")
    end
  end

  it "rejects an unknown subcommand" do
    JediCliSpec.with_cli_db do |conn|
      JediCliSpec.expect_failure(conn,
        ["trade", "unknown-subcommand"],
        "infra.unknown_subcommand")
    end
  end

  it "rejects missing required create fields after CLI parsing" do
    JediCliSpec.with_cli_db do |conn|
      ex = JediCliSpec.expect_failure(conn,
        ["scale", "create", "--name=S_BAD", "--comment=missing definition"])

      ex.context[:field]?.should eq("builder")
    end
  end

  it "rejects invalid tick overrides in trade orders" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.seed_basic_trade(conn)

      JediCliSpec.expect_failure(conn,
        ["trade", "orders", "--tick-buy=invalid", "T_TEST"])
    end
  end
end
