require "../support/play_spec_helper"

module JediPlayRobustnessSpec
  extend self

  def assert_operation_chain_is_safe(operations : Array(Jedi::TradingLife::Operation)) : Nil
    operations.each_with_index do |operation, index|
      operation.quantity.should be > 0
      operation.price.should be > 0.0
      operation.stock.should be >= 0

      next if index.zero?

      previous = operations[index - 1]

      # Across a settings boundary, especially after a split, the stock
      # reference may be structurally adjusted before the next operation.
      # The simple previous.stock +/- quantity invariant only applies inside
      # the same settings row.
      next unless operation.settings.id == previous.settings.id

      case operation.type
      when Jedi::TradingLife::Operation::Type::Buy
        operation.stock.should eq(previous.stock + operation.quantity)
      when Jedi::TradingLife::Operation::Type::Sell
        operation.stock.should eq(previous.stock - operation.quantity)
      end
    end
  end
end

describe Jedi::Tools::Play do
  it "runs many alternating upward and downward actions without state drift" do
    actions = [] of String
    60.times do
      actions << "1"
      actions << "-1"
    end

    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      actions
    ) do |play|
      operations = JediPlaySpec.operations(play)

      operations.size.should eq(actions.size + 1)
      play.new_operations_count.should eq(actions.size)
      play.simulation_stopped?.should be_false

      JediPlayRobustnessSpec.assert_operation_chain_is_safe(operations)

      play.context.current_operation.stock.should eq(100)
      play.context.current_operation.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      play.context.running_orders.map { |running| running.key }.uniq.sort_by(&.to_s).should eq([:down, :up])
    end
  end

  it "keeps repeated narrow target-price probes bounded and safe" do
    actions = [] of String
    30.times do
      # A target price is not an instruction to execute exactly one operation.
      # It executes every reachable order up to the target, and may execute no
      # operation if the current next order is not reached. This spec therefore
      # checks robustness and boundedness, not a synthetic 1 target = 1 operation
      # rule.
      actions << "11.05"
      actions << "9.95"
    end

    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      actions
    ) do |play|
      operations = JediPlaySpec.operations(play)

      operations.size.should be >= 1
      operations.size.should be <= actions.size + 1
      play.new_operations_count.should eq(operations.size - 1)
      play.simulation_stopped?.should be_false

      JediPlayRobustnessSpec.assert_operation_chain_is_safe(operations)

      play.context.current_operation.id.should eq(operations.last.id)
      play.context.current_operation.stock.should be >= 0
      play.context.current_operation.position.should be_a(Jedi::TradingRules::Position)
      play.context.running_orders.size.should be > 0
    end
  end

  it "keeps repeated split cycles coherent over several settings rows" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["split=2:1", "1", "-1", "split=2:1", "1", "-1"]
    ) do |play|
      settings_rows = JediPlaySpec.settings_rows(play)
      operations = JediPlaySpec.operations(play)

      settings_rows.size.should eq(3)
      operations.size.should eq(5)
      play.new_operations_count.should eq(4)
      play.simulation_stopped?.should be_false

      first_split = settings_rows[1]
      first_split.split.not_nil!.to_s.should eq("2:1")
      first_split.q0.should be_close(200.0, JediSpec::EPSILON)
      first_split.c0.should be_close(5.0, JediSpec::EPSILON)
      first_split.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))

      second_split = settings_rows[2]
      second_split.split.not_nil!.to_s.should eq("2:1")
      second_split.q0.should be_close(400.0, JediSpec::EPSILON)
      second_split.c0.should be_close(2.5, JediSpec::EPSILON)
      second_split.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))

      operations.last.stock.should eq(400)
      operations.last.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      operations.last.settings.id.should eq(second_split.id)

      JediPlayRobustnessSpec.assert_operation_chain_is_safe(operations)
    end
  end

  it "stops a long script immediately after a complete stoploss exit" do
    tail = [] of String
    50.times do
      tail << "1"
      tail << "-1"
    end
    actions = ["-1", "-1"] + tail

    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01,money=r:1.5%,o:2,n:2,loss=active",
      actions
    ) do |play|
      operations = JediPlaySpec.operations(play)

      operations.size.should eq(3)
      play.new_operations_count.should eq(2)
      play.context.running_orders.size.should eq(2)
      play.simulation_stopped?.should be_true

      play.context.running_orders[0].key.should eq(:down)
      play.context.running_orders[1].key.should eq(:loss)

      operations.last.mode.should eq(Jedi::TradingLife::Operation::Mode::StopLoss)
      operations.last.stock.should eq(0)
      play.context.current_operation.id.should eq(operations.last.id)
    end
  end
end
