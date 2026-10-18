require "../support/cli_spec_helper"

describe "Scale operational identity" do
  it "ignores different builders when their effective rules are identical" do
    constructed = Jedi::TradingRules::Scale::Decoder.new(
      "kc:1.4,1.2,0.8,0.6,ki:10%,kb:1,kd:0").decode
    explicit = Jedi::TradingRules::Scale::Decoder.new(
      "kc:1.4,1.2,0.8,0.6,ks:0.89,1.25,ki:10%,kb:1").decode

    constructed.builder.should_not eq(explicit.builder)
    constructed.same_definition?(explicit).should be_true
    explicit.same_definition?(constructed).should be_true
  end

  it "does not equate the two operational types" do
    fixed = Jedi::TradingRules::Scale::Decoder.new(
      "kc:1.21,1.1,0.9,0.81,ks:0.8,1.2,ki:0%,kb:0").decode
    relative = Jedi::TradingRules::Scale::Decoder.new(
      "vr:10%,ks:0.8,1.2,ki:0%,kb:0").decode

    fixed.ks_values.should eq(relative.ks_values)
    fixed.same_definition?(relative).should be_false
  end

  it "includes boundaries even when presentation text is identical" do
    original = Jedi::TradingRules::Scale::Decoder.new(
      "vr:10%,ks:0.8,1.2,ki:0%,kb:0").decode
    different_boundary = Jedi::TradingRules::Scale::Operational.new(
      type: original.type, definition: original.definition, builder: original.builder,
      ks_values: original.ks_values, emax: original.emax + 1, emin: original.emin,
      ki: original.ki, kb: original.kb, vr_value: original.vr_value)

    original.same_definition?(different_boundary).should be_false
  end

  it "keeps legacy duplicates and permits metadata changes without rewriting references" do
    JediSpec.with_db do |conn|
      builder = "vr:10%,ks:0.8,1.2,ki:0%,kb:0"
      first_id = Jedi::TradingRules::ScaleCreator.new(conn).restore(
        name: "Legacy_first", comment: "Historical", builder: builder)
      second_id = Jedi::TradingRules::ScaleCreator.new(conn).restore(
        name: "Legacy_second", comment: "Historical duplicate", builder: builder)
      JediSpec.insert_security(conn)
      JediSpec.insert_trade(conn)
      JediSpec.insert_settings(conn, scale_id: first_id)
      JediSpec.insert_operation(conn)

      Jedi::TradingRules::ScaleUpdater.new(Jedi::TradingRules::Scale.new(conn, first_id))
        .call(comment: "Corrected context").should eq(1)

      Jedi::TradingRules::Scale.new(conn, first_id).name.should eq("Legacy_first")
      Jedi::TradingRules::Scale.new(conn, second_id).name.should eq("Legacy_second")
      JediSpec.trade(conn).last_settings.not_nil!.scale.id.should eq(first_id)
      conn.scalar("SELECT COUNT(*) FROM scale").should eq(2_i64)
    end
  end

  it "uses savepoints within an outer transaction without consuming rejected names" do
    JediSpec.with_db do |conn|
      conn.transaction do |transaction|
        creator = Jedi::TradingRules::ScaleCreator.new(transaction)
        creator.call(comment: "First", builder: "vr:10%,ks:0.8,1.2,ki:0%,kb:0")
        ex = expect_raises(Jedi::LowLevelError) do
          creator.call(comment: "Duplicate", builder: "vr:10%,ks:0.8,1.2,ki:0%,kb:0")
        end
        ex.key.should eq("scale.definition_exists")
        creator.call(comment: "Second", builder: "vr:12%,ks:0.8,1.2,ki:0%,kb:0")
      end
      conn.query_all("SELECT name FROM scale ORDER BY id", as: String).should eq(["B_vr_01", "B_vr_02"])
    end
  end

  it "reuses an equivalent literal in a simulation database" do
    JediCliSpec.with_cli_db do |conn|
      memory = Jedi::App.conn_memory
      JediSpec.create_schema(memory)
      first = Jedi::Tools::Helpers.scale(conn, memory,
        "kc:1.4,1.2,0.8,0.6,ki:10%,kb:1,kd:0", announce: false)
      equivalent = Jedi::Tools::Helpers.scale(conn, memory,
        "kc:1.4,1.2,0.8,0.6,ks:0.89,1.25,ki:10%,kb:1", announce: false)

      equivalent.id.should eq(first.id)
      memory.scalar("SELECT COUNT(*) FROM scale").should eq(1_i64)
    end
  end

  it "reuses equivalent historical names when copying them into a simulation" do
    JediCliSpec.with_cli_db do |conn|
      memory = Jedi::App.conn_memory
      JediSpec.create_schema(memory)
      creator = Jedi::TradingRules::ScaleCreator.new(conn)
      creator.restore(name: "Legacy_a", comment: "First", builder: "vr:10%,ks:0.8,1.2,ki:0%,kb:0")
      creator.restore(name: "Legacy_b", comment: "Second", builder: "vr:10%,ks:0.8,1.2,ki:0%,kb:0")

      first = Jedi::Tools::Helpers.scale(conn, memory, "Legacy_a", announce: false)
      second = Jedi::Tools::Helpers.scale(conn, memory, "Legacy_b", announce: false)

      second.id.should eq(first.id)
      conn.scalar("SELECT COUNT(*) FROM scale").should eq(2_i64)
      memory.scalar("SELECT COUNT(*) FROM scale").should eq(1_i64)
    end
  end
end
