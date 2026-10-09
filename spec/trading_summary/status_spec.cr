require "./support"

describe Jedi::TradingSystem::TradeStatus do
  it "returns no row when every started trade is closed" do
    JediPlaySpec.with_seeded_play(
      JediTradingSystemSpec::PARAMS,
      [] of String
    ) do |play|
      trade = JediTradingSystemSpec.reload_trade(play, play.mem_trade)
      first = trade.operations.first

      JediTradingSystemSpec.close_trade(
        play,
        trade,
        first.timestamp + 1.days,
        12.0
      )

      output = Jedi::TradingSystem::TradeStatus.new(play.conn_memory).list(
        regex: nil,
        option_update_now: false
      )

      output.should eq("")
    end
  end

  it "applies the filter before trying to update an open trade quotation" do
    JediPlaySpec.with_seeded_play(
      JediTradingSystemSpec::PARAMS,
      [] of String
    ) do |play|
      output = Jedi::TradingSystem::TradeStatus.new(play.conn_memory).list(
        regex: "NO_SUCH_TRADE_OR_SECURITY",
        option_update_now: false
      )

      output.should eq("")
    end
  end
end
