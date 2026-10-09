require "./support"

describe Jedi::TradingSystem::TradeResults do
  it "returns an empty result when there is no operation" do
    JediPlaySpec.with_seeded_play(
      JediTradingSystemSpec::PARAMS,
      [] of String
    ) do |play|
      play.conn_memory.exec("DELETE FROM operation")

      output = Jedi::TradingSystem::TradeResults.new(play.conn_memory).list(
        option_update_now: false
      )

      output.should eq("")
    end
  end

  it "uses the chronological global capital peak for the summary" do
    JediPlaySpec.with_seeded_play(
      JediTradingSystemSpec::PARAMS,
      [] of String
    ) do |play|
      first_trade = JediTradingSystemSpec.reload_trade(play, play.mem_trade)
      initial_timestamp = first_trade.operations.first.timestamp

      first_trade = JediTradingSystemSpec.close_trade(
        play,
        first_trade,
        initial_timestamp + 1.days,
        12.0
      )

      second_trade = JediTradingSystemSpec.create_trade(
        play,
        name: "Second",
        timestamp: initial_timestamp + 2.days,
        quantity: 200,
        price: 10.0
      )
      JediTradingSystemSpec.close_trade(
        play,
        second_trade,
        initial_timestamp + 3.days,
        11.0
      )

      base = Time.local - 365.days
      JediTradingSystemSpec.set_operation_schedule(
        play.conn_memory,
        base,
        [0, 120, 180, 360]
      )

      operations = Jedi::TradingLife::Operations.new(play.conn_memory).fetch
      global_maximum = JediTradingSystemSpec.global_maximum_investment(operations)
      global_maximum.should eq(180_000)

      trades = Jedi::TradingSystem::Trades.new(play.conn_memory).fetch
      metrics = [] of Jedi::TradingSystem::TradeMetrics::Data
      trades.each do |trade|
        if rec = Jedi::TradingSystem::TradeMetrics.new(trade).calculate
          metrics << rec
        end
      end

      metrics.sum { |rec| rec.maximum_investment }.should eq(300_000)
      sum_gains = metrics.sum { |rec| rec.sells - rec.buys }
      sum_fees = metrics.sum { |rec| rec.fees }
      sum_gains.should eq(40_000)

      summary_days = (Time.local - operations.first.timestamp).total_days.to_i
      gross_return = JediTradingSystemSpec.annualized_return(
        sum_gains,
        global_maximum,
        summary_days
      )
      net_return = JediTradingSystemSpec.annualized_return(
        sum_gains - sum_fees,
        global_maximum,
        summary_days
      )

      output = Jedi::TradingSystem::TradeResults.new(play.conn_memory).list(
        option_update_now: false
      )

      output.downcase.should_not contain("nan%")
      output.should contain("1800.00")
      output.should contain("%.1f%%" % gross_return)
      output.should contain("%.1f%%" % net_return)
    end
  end
end
