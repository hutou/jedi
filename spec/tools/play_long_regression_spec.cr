require "../support/play_spec_helper"

module JediPlayLongSpec
  extend self

  def assert_operation_chain_is_consistent(operations : Array(Jedi::TradingLife::Operation)) : Nil
    operations.each_with_index do |operation, index|
      operation.quantity.should be > 0
      operation.price.should be > 0.0
      operation.stock.should be >= 0

      next if index.zero?

      previous = operations[index - 1]

      # A structural settings change, especially split, may alter the stock
      # reference before the next operation is executed. In that case the
      # plain previous.stock +/- quantity invariant is not valid across the
      # settings boundary; it remains valid again inside the new settings row.
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
  it "keeps the operation chain coherent over a mixed deterministic sequence" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["1", "1", "-1", "-1", "1"]
    ) do |play|
      operations = JediPlaySpec.operations(play)
      operations.size.should eq(6)
      play.new_operations_count.should eq(5)
      play.simulation_stopped?.should be_false

      play.context.running_orders.map { |running| running.key }.should eq([
        :up,
        :up,
        :down,
        :down,
        :up,
      ])

      operations.map { |operation| operation.position }.should eq([
        Jedi::TradingRules::Position.new("0:0:0"),
        Jedi::TradingRules::Position.new("0:0:+1"),
        Jedi::TradingRules::Position.new("1:0:0"),
        Jedi::TradingRules::Position.new("1:0:-1"),
        Jedi::TradingRules::Position.new("1:1:0"),
        Jedi::TradingRules::Position.new("1:1:+1"),
      ])

      JediPlayLongSpec.assert_operation_chain_is_consistent(operations)
      play.context.current_operation.id.should eq(operations.last.id)
    end
  end

  it "executes every reachable upward order until an upward target price is reached" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["13.50"]
    ) do |play|
      operations = JediPlaySpec.operations(play)

      operations.size.should eq(4)
      play.new_operations_count.should eq(3)
      play.context.running_orders.map { |running| running.key }.should eq([
        :up,
        :up,
        :up,
      ])

      selected_prices = play.context.running_orders.map do |running|
        running.orders[running.key].price
      end
      selected_prices.each { |price| price.should be <= 13.50 }
      selected_prices.should eq(selected_prices.sort)

      operations.last.type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      operations.last.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      operations.last.position.should eq(Jedi::TradingRules::Position.new("1:0:+1"))

      JediPlayLongSpec.assert_operation_chain_is_consistent(operations)
    end
  end

  it "executes every reachable downward order until a downward target price is reached" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["7.00"]
    ) do |play|
      operations = JediPlaySpec.operations(play)

      operations.size.should eq(4)
      play.new_operations_count.should eq(3)
      play.context.running_orders.map { |running| running.key }.should eq([
        :down,
        :down,
        :down,
      ])

      selected_prices = play.context.running_orders.map do |running|
        running.orders[running.key].price
      end
      selected_prices.each { |price| price.should be >= 7.00 }
      selected_prices.should eq(selected_prices.sort.reverse)

      operations.last.type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      operations.last.mode.should eq(Jedi::TradingLife::Operation::Mode::Limit)
      operations.last.position.should eq(Jedi::TradingRules::Position.new("0:1:-1"))

      JediPlayLongSpec.assert_operation_chain_is_consistent(operations)
    end
  end

  it "keeps settings and operations coherent across a split followed by opposite steps" do
    JediPlaySpec.with_seeded_play(
      "scale=S_TEST,q0=100,c0=10,tick=0.01",
      ["split=2:1", "1", "-1"]
    ) do |play|
      settings_rows = JediPlaySpec.settings_rows(play)
      operations = JediPlaySpec.operations(play)

      settings_rows.size.should eq(2)
      operations.size.should eq(3)
      play.new_operations_count.should eq(2)

      split_settings = settings_rows.last
      split_settings.split.not_nil!.to_s.should eq("2:1")
      split_settings.q0.should be_close(200.0, JediSpec::EPSILON)
      split_settings.c0.should be_close(5.0, JediSpec::EPSILON)
      split_settings.position.should eq(Jedi::TradingRules::Position.new("0:0:0"))

      operations[1].type.should eq(Jedi::TradingLife::Operation::Type::Sell)
      operations[1].quantity.should eq(40)
      operations[1].price.should be_close(5.5, JediSpec::EPSILON)
      operations[1].stock.should eq(160)
      operations[1].position.should eq(Jedi::TradingRules::Position.new("0:0:+1"))
      operations[1].settings.id.should eq(split_settings.id)

      operations[2].type.should eq(Jedi::TradingLife::Operation::Type::Buy)
      operations[2].quantity.should eq(40)
      operations[2].stock.should eq(200)
      operations[2].position.should eq(Jedi::TradingRules::Position.new("0:0:0"))
      operations[2].settings.id.should eq(split_settings.id)

      JediPlayLongSpec.assert_operation_chain_is_consistent(operations)
    end
  end
end
