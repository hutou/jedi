require "./support"

describe Jedi::TradingSystem::TradeMetrics do
  it "returns nil for a trade without operations" do
    JediPlaySpec.with_seeded_play(
      JediTradingSystemSpec::PARAMS,
      [] of String
    ) do |play|
      trade = JediTradingSystemSpec.create_empty_trade(
        play,
        name: "Empty"
      )

      Jedi::TradingSystem::TradeMetrics.new(trade).calculate.should be_nil
    end
  end

  it "calculates current and maximum investment and uses now for an open trade" do
    JediPlaySpec.with_seeded_play(
      JediTradingSystemSpec::PARAMS,
      [] of String
    ) do |play|
      trade = JediTradingSystemSpec.reload_trade(play, play.mem_trade)
      first = trade.operations.first

      JediTradingSystemSpec.add_operation(
        play,
        trade,
        first.timestamp + 3.days,
        Jedi::TradingLife::Operation::Type::Sell,
        50,
        30.0
      )

      trade = JediTradingSystemSpec.reload_trade(play, trade)
      operations = trade.operations
      now = first.timestamp + 10.days
      rec = Jedi::TradingSystem::TradeMetrics.new(trade, now).calculate.not_nil!

      rec.buys.should eq(100_000)
      rec.sells.should eq(150_000)
      rec.fees.should eq(operations.sum { |operation| operation.fees })
      rec.maximum_investment.should eq(100_000)
      rec.current_investment.should eq(-50_000)
      rec.stock.should eq(50)
      rec.operation_count.should eq(2)
      rec.q0.should eq(100.0)
      rec.c0.should eq(10.0)
      rec.position.should eq(operations.last.position)
      rec.duration.should eq(10)
    end
  end

  it "uses the last operation timestamp for a closed trade" do
    JediPlaySpec.with_seeded_play(
      JediTradingSystemSpec::PARAMS,
      [] of String
    ) do |play|
      trade = JediTradingSystemSpec.reload_trade(play, play.mem_trade)
      first = trade.operations.first

      trade = JediTradingSystemSpec.close_trade(
        play,
        trade,
        first.timestamp + 7.days,
        12.0
      )

      rec = Jedi::TradingSystem::TradeMetrics.new(
        trade,
        first.timestamp + 30.days
      ).calculate.not_nil!

      rec.buys.should eq(100_000)
      rec.sells.should eq(120_000)
      rec.maximum_investment.should eq(100_000)
      rec.current_investment.should eq(-20_000)
      rec.stock.should eq(0)
      rec.operation_count.should eq(2)
      rec.duration.should eq(7)
    end
  end

  it "uses the effective split stock before the first operation under new settings" do
    JediPlaySpec.with_seeded_play(
      JediTradingSystemSpec::PARAMS,
      [] of String
    ) do |play|
      trade = JediTradingSystemSpec.reload_trade(play, play.mem_trade)
      first = trade.operations.first
      scale_id = trade.settings_chain.last.scale.id

      Jedi::TradingSystem::SettingsCreator.new(play.conn_memory).call(
        trade_ident: trade.id,
        scale_ident: scale_id,
        timestamp: first.timestamp + 1.days,
        option_split: Jedi::Exchange::Security::Split.new("2:1")
      )

      trade = JediTradingSystemSpec.reload_trade(play, trade)
      metrics = Jedi::TradingSystem::TradeMetrics.new(trade).calculate.not_nil!

      metrics.stock.should eq(200)
      metrics.q0.should be_close(200.0, JediSpec::EPSILON)
      metrics.c0.should be_close(5.0, JediSpec::EPSILON)

      JediTradingSystemSpec.add_operation(
        play,
        trade,
        first.timestamp + 2.days,
        Jedi::TradingLife::Operation::Type::Sell,
        50,
        6.0
      )

      trade = JediTradingSystemSpec.reload_trade(play, trade)
      metrics = Jedi::TradingSystem::TradeMetrics.new(trade).calculate.not_nil!

      metrics.stock.should eq(150)
    end
  end
end
