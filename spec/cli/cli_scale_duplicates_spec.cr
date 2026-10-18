require "../spec_helper"
require "../support/cli_spec_helper"

module JediScaleDuplicatesCliSpec
  extend self

  TYPE_ONE = "kc:1.4,1.2,0.8,0.6,ki:10%,kb:1,kd:0"
  TYPE_TWO = "vr:10%,np:3,nn:3,ki:10%,kb:1,kd:0"

  def create(conn, name, builder)
    JediCliSpec.run(conn, "scale", "create", "--name=#{name}",
      "--comment=Duplicate regression", "--builder=#{builder}")
  end
end

describe Jedi::Command, "unique scale definitions" do
  it "rejects another name for an identical builder" do
    JediCliSpec.with_cli_db do |conn|
      JediScaleDuplicatesCliSpec.create(conn, "B_kc_01", JediScaleDuplicatesCliSpec::TYPE_ONE)

      ex = JediCliSpec.expect_failure(conn,
        ["scale", "create", "--name=B_kc_02", "--comment=Copy",
         "--builder=#{JediScaleDuplicatesCliSpec::TYPE_ONE}"], "scale.definition_exists")

      ex.context[:ref].should contain("B_kc_01")
      JediCliSpec.table_count(conn, "scale").should eq(1)
    end
  end

  it "rejects different builders that produce the same operational definition" do
    JediCliSpec.with_cli_db do |conn|
      JediScaleDuplicatesCliSpec.create(conn, "B_kc_01", JediScaleDuplicatesCliSpec::TYPE_ONE)

      JediCliSpec.expect_failure(conn,
        ["scale", "create", "--name=B_kc_02", "--comment=Explicit equivalent",
         "--builder=kc:1.4,1.2,0.8,0.6,ks:0.89,1.25,ki:10%,kb:1"],
        "scale.definition_exists")

      JediCliSpec.table_count(conn, "scale").should eq(1)
    end
  end

  it "compares normalized values despite field order, spaces and percentage spelling" do
    JediCliSpec.with_cli_db do |conn|
      JediScaleDuplicatesCliSpec.create(conn, "B_kc_01", JediScaleDuplicatesCliSpec::TYPE_ONE)

      JediCliSpec.expect_failure(conn,
        ["scale", "create", "--name=B_kc_02", "--comment=Reformatted",
         "--builder= kd:0.0, kb:1, ki:0.10, kc:1.40,1.20,0.80,0.60 "],
        "scale.definition_exists")

      JediCliSpec.table_count(conn, "scale").should eq(1)
    end
  end

  it "rejects an update into another definition even with force and preserves the record" do
    JediCliSpec.with_cli_db do |conn|
      JediScaleDuplicatesCliSpec.create(conn, "B_vr_01", JediScaleDuplicatesCliSpec::TYPE_TWO)
      JediScaleDuplicatesCliSpec.create(conn, "B_vr_02",
        "vr:12%,np:3,nn:3,ki:10%,kb:1,kd:0")
      before = Jedi::TradingRules::Scale.new(conn, "B_vr_02").record

      JediCliSpec.expect_failure(conn,
        ["scale", "update", "B_vr_02", "--name=B_vr_03", "--comment=Changed",
         "--builder=#{JediScaleDuplicatesCliSpec::TYPE_TWO}", "--force"],
        "scale.definition_exists")

      Jedi::TradingRules::Scale.new(conn, "B_vr_02").record.should eq(before)
      JediCliSpec.table_count(conn, "scale").should eq(2)
    end
  end

  it "allows changing a scale's own name and comment" do
    JediCliSpec.with_cli_db do |conn|
      JediScaleDuplicatesCliSpec.create(conn, "B_vr_01", JediScaleDuplicatesCliSpec::TYPE_TWO)

      JediCliSpec.run(conn, "scale", "update", "B_vr_01", "--name=B_vr_02", "--comment=Renamed")

      scale = Jedi::TradingRules::Scale.new(conn, "B_vr_02")
      scale.id.should eq(1)
      scale.comment.should eq("Renamed")
      JediCliSpec.table_count(conn, "scale").should eq(1)
    end
  end

  it "keeps scales whose effective parameters differ" do
    JediCliSpec.with_cli_db do |conn|
      [
        "vr:10%,ks:0.8,1.2,ki:10%,kb:1",
        "vr:10%,ks:0.8,1.2,ki:15%,kb:1",
        "vr:10%,ks:0.8,1.2,ki:10%,kb:0",
        "vr:12%,ks:0.8,1.2,ki:10%,kb:1",
        "vr:10%,ks:0.7,1.3,ki:10%,kb:1",
      ].each_with_index do |builder, index|
        JediScaleDuplicatesCliSpec.create(conn, "B_vr_0#{index + 1}", builder)
      end

      JediCliSpec.table_count(conn, "scale").should eq(5)
    end
  end
end
