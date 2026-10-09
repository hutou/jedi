require "../spec_helper"
require "../support/cli_spec_helper"

describe Jedi::Command, "CLI tools play" do
  it "runs tools play from a scale name and stores the simulation in the memory database" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.insert_scale(conn, name: "S_TEST", scale: JediSpec.type_two_scale)

      JediCliSpec.run(conn,
        "tools", "play",
        # "--command=o", "--",
        "--",
        "scale=S_TEST,q0=100,c0=10,tick=0.01",
        "1",
        "-1")

      count = JediCliSpec.table_count(Jedi::App.conn_memory, "operation")
      count.should eq(3)

      operations = Jedi::TradingLife::Operations.new(Jedi::App.conn_memory).fetch.to_a
      operations[0].position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      operations[1].position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
      operations[2].position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
    end
  end

  it "rejects invalid tools play command letters at CLI level" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.insert_scale(conn, name: "S_TEST", scale: JediSpec.type_two_scale)

      JediCliSpec.expect_failure(conn,
        ["tools", "play",
         "--command=z",
         "scale=S_TEST,q0=100,c0=10,tick=0.01",
         "1"])
    end
  end
  it "accepts play operation arguments starting with '-' after --" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.insert_scale(conn, name: "S_TEST", scale: JediSpec.type_two_scale)
      JediCliSpec.run(conn, ["tools", "play",
      # "--command=o",
                             "--",
                             "scale=S_TEST,q0=100,c0=10,tick=0.01",
                             "-1"])
    end
  end
  it "rejects an operation argument starting with '-' without --" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.insert_scale(conn, name: "S_TEST", scale: JediSpec.type_two_scale)
      JediCliSpec.expect_failure(conn, ["tools", "play",
                                        "scale=S_TEST,q0=100,c0=10,tick=0.01",
                                        "--command=o",
                                        "-10@50.0",
      ])
    end
  end
end
