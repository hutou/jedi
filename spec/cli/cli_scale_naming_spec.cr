require "../spec_helper"
require "../support/cli_spec_helper"

describe Jedi::Command, "automatic scale naming" do
  it "numbers the two operational types independently across all builder families" do
    JediCliSpec.with_cli_db do |conn|
      builders = [
        "kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1",
        "vr:10%,ks:0.8,1.2,ki:0%,kb:0",
        "kc:1.4,1.2,0.8,0.6,ki:10%,kb:1,kd:0",
        "vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0",
        "vr:10%,np:3,sr:50%,nn:3,mi:120%,ki:10%,kb:1",
      ]
      builders.each do |builder|
        JediCliSpec.run(conn, "scale", "create", "--comment=Automatic", "--builder=#{builder}")
      end

      conn.query_all("SELECT name FROM scale ORDER BY id", as: String).should eq(
        ["B_kc_01", "B_vr_01", "B_kc_02", "B_vr_02", "B_vr_03"])
      Jedi::TradingRules::Scale.new(conn, "B_vr_03").operational.type.should eq(
        Jedi::TradingRules::Scale::Operational::Type::Two)
    end
  end

  it "supports the positional form without a name" do
    JediCliSpec.with_cli_db do |conn|
      JediCliSpec.run(conn, "scale", "create", "Positional automatic",
        "vr:10%,ks:0.8,1.2,ki:0%,kb:0")
      Jedi::TradingRules::Scale.new(conn, "B_vr_01").comment.should eq("Positional automatic")
    end
  end

  it "uses the highest existing number and continues beyond two digits" do
    JediCliSpec.with_cli_db do |conn|
      JediCliSpec.run(conn, "scale", "create", "--name=b_vr_98", "--comment=Explicit",
        "--builder=vr:10%,ks:0.8,1.2,ki:0%,kb:0")
      ["12%", "20%"].each do |vr|
        JediCliSpec.run(conn, "scale", "create", "--comment=Next",
          "--builder=vr:#{vr},ks:0.8,1.2,ki:0%,kb:0")
      end
      conn.query_all("SELECT name FROM scale ORDER BY id", as: String).should eq(
        ["B_vr_98", "B_vr_99", "B_vr_100"])
    end
  end

  it "rejects explicit names inconsistent with the builder type or number format" do
    JediCliSpec.with_cli_db do |conn|
      ["B_kc_01", "Custom", "B_vr_00", "B_vr_1", "B_vr_9223372036854775808"].each do |name|
        JediCliSpec.expect_failure(conn,
          ["scale", "create", "--name=#{name}", "--comment=Invalid",
           "--builder=vr:10%,ks:0.8,1.2,ki:0%,kb:0"], "scale.name_type_mismatch")
      end
      JediCliSpec.table_count(conn, "scale").should eq(0)
    end
  end

  it "does not consume a number when an equivalent definition is rejected" do
    JediCliSpec.with_cli_db do |conn|
      builder = "vr:10%,ks:0.8,1.2,ki:0%,kb:0"
      JediCliSpec.run(conn, "scale", "create", "--comment=First", "--builder=#{builder}")
      JediCliSpec.expect_failure(conn,
        ["scale", "create", "--comment=Duplicate", "--builder=#{builder}"], "scale.definition_exists")
      JediCliSpec.run(conn, "scale", "create", "--comment=Second",
        "--builder=vr:12%,ks:0.8,1.2,ki:0%,kb:0")
      conn.query_all("SELECT name FROM scale ORDER BY id", as: String).should eq(["B_vr_01", "B_vr_02"])
    end
  end

  it "renames an unused numbered scale when an update changes its type" do
    JediCliSpec.with_cli_db do |conn|
      JediCliSpec.run(conn, "scale", "create", "--comment=Type I",
        "--builder=kc:1.4,1.2,0.8,0.6,ks:0.8,1.2,ki:10%,kb:1")
      JediCliSpec.run(conn, "scale", "create", "--comment=Type II",
        "--builder=vr:10%,ks:0.8,1.2,ki:0%,kb:0")
      JediCliSpec.run(conn, "scale", "update", "B_kc_01",
        "--builder=vr:12%,ks:0.8,1.2,ki:0%,kb:0")

      renamed = Jedi::TradingRules::Scale.new(conn, "B_vr_02")
      renamed.id.should eq(1)
      renamed.operational.type.should eq(Jedi::TradingRules::Scale::Operational::Type::Two)
      JediCliSpec.table_count(conn, "scale").should eq(2)
    end
  end

  it "rejects a rename to the wrong family without changing the record" do
    JediCliSpec.with_cli_db do |conn|
      JediCliSpec.run(conn, "scale", "create", "--comment=Type II",
        "--builder=vr:10%,ks:0.8,1.2,ki:0%,kb:0")
      before = Jedi::TradingRules::Scale.new(conn, "B_vr_01").record
      JediCliSpec.expect_failure(conn,
        ["scale", "update", "B_vr_01", "--name=B_kc_01"], "scale.name_type_mismatch")
      Jedi::TradingRules::Scale.new(conn, "B_vr_01").record.should eq(before)
    end
  end

  it "normalizes explicit padding and prevents another record using the same number" do
    JediCliSpec.with_cli_db do |conn|
      JediCliSpec.run(conn, "scale", "create", "--name=b_vr_0007", "--comment=Explicit",
        "--builder=vr:10%,ks:0.8,1.2,ki:0%,kb:0")
      Jedi::TradingRules::Scale.new(conn, "B_vr_07").id.should eq(1)
      JediCliSpec.expect_failure(conn,
        ["scale", "create", "--name=B_vr_007", "--comment=Collision",
         "--builder=vr:12%,ks:0.8,1.2,ki:0%,kb:0"], "scale.create.name_exists")
      JediCliSpec.table_count(conn, "scale").should eq(1)
    end
  end

  it "reserves numbers found under a historical padding convention" do
    JediCliSpec.with_cli_db do |conn|
      Jedi::TradingRules::ScaleCreator.new(conn).restore(
        name: "B_vr_001", comment: "Historical", builder: "vr:10%,ks:0.8,1.2,ki:0%,kb:0")
      JediCliSpec.expect_failure(conn,
        ["scale", "create", "--name=B_vr_01", "--comment=Collision",
         "--builder=vr:12%,ks:0.8,1.2,ki:0%,kb:0"], "scale.create.name_exists")
      JediCliSpec.run(conn, "scale", "create", "--comment=Next",
        "--builder=vr:12%,ks:0.8,1.2,ki:0%,kb:0")
      Jedi::TradingRules::Scale.new(conn, "B_vr_02").id.should eq(2)
    end
  end
end
