require "../support/jedi_spec_helper"

module JediQuoteRefresherSpec
  extend self

  def insert_securities(conn : DB::Connection, count : Int32) : Nil
    count.times do |index|
      number = index + 1
      JediSpec.insert_security(
        conn,
        id: number.to_i64,
        isin: "FR448760100#{number}",
        name: "SPEC SECURITY #{number}",
        ticker: "SPEC#{number}",
      )
    end
  end

  def provider_failure : Jedi::LowLevelError
    Jedi::LowLevelError.new(
      "Quotation provider failed",
      kind: Jedi::LowLevelError::Kind::Technical,
    )
  end

  def message_keys : Array(String)
    Jedi::App.messages.map(&.key)
  end

  def prepare_log_directory : Nil
    # Other spec groups temporarily replace App.paths and may leave the cached
    # logger pointing at a directory removed by their cleanup.
    Dir.mkdir_p(File.dirname(Jedi::App.logger.filename))
  end
end

describe Jedi::Exchange::QuoteRefresher do
  it "reports no match without also reporting success" do
    JediSpec.with_db do |conn|
      output = IO::Memory.new

      Jedi::Exchange::QuoteRefresher.new(
        conn,
        output: output,
      ).call(option_force: true)

      JediQuoteRefresherSpec.message_keys.should eq(["infra.no_match"])
      output.to_s.should be_empty
    end
  end

  it "forwards the requested mode and reports complete success" do
    JediSpec.with_db do |conn|
      JediQuoteRefresherSpec.insert_securities(conn, 2)
      received_modes = [] of String?
      update_quote = ->(_security : Jedi::Exchange::Security, mode : String?) {
        received_modes << mode
        "eod"
      }

      Jedi::Exchange::QuoteRefresher.new(
        conn,
        output: IO::Memory.new,
        update_quote: update_quote,
      ).call(option_mode: "eod", option_force: true)

      received_modes.should eq(["eod", "eod"])
      JediQuoteRefresherSpec.message_keys.should eq(["quote.refresh.success"])
    end
  end

  it "keeps a partial refresh successful and reports the failed count" do
    JediSpec.with_db do |conn|
      JediQuoteRefresherSpec.prepare_log_directory
      JediQuoteRefresherSpec.insert_securities(conn, 2)
      update_quote = ->(security : Jedi::Exchange::Security, _mode : String?) {
        raise JediQuoteRefresherSpec.provider_failure if security.id == 2_i64
        "live"
      }

      Jedi::Exchange::QuoteRefresher.new(
        conn,
        output: IO::Memory.new,
        update_quote: update_quote,
      ).call(option_force: true)

      JediQuoteRefresherSpec.message_keys.should eq([
        "quote.refresh.failed_updates_count",
        "infra.see_logfile",
      ])
    end
  end

  it "raises a technical error when every selected update fails" do
    JediSpec.with_db do |conn|
      JediQuoteRefresherSpec.prepare_log_directory
      JediQuoteRefresherSpec.insert_securities(conn, 2)
      output = IO::Memory.new
      update_quote = ->(_security : Jedi::Exchange::Security, _mode : String?) {
        raise JediQuoteRefresherSpec.provider_failure
        "live"
      }

      ex = expect_raises(Jedi::LowLevelError) do
        Jedi::Exchange::QuoteRefresher.new(
          conn,
          output: output,
          update_quote: update_quote,
        ).call(option_force: true)
      end

      ex.key.should eq("quote.refresh.failed_updates")
      ex.kind.should eq(Jedi::LowLevelError::Kind::Technical)
      ex.context.should eq({
        :failures => "2",
        :selected => "2",
      })
      output.to_s.should end_with("\033[?25h")

      app_error = expect_raises(Jedi::AppException) do
        Jedi::App.raise_from_low_level(ex)
      end
      app_error.level.should eq(Jedi::AppException::Level::Error)
      app_error.key.should eq("quote.refresh.failed_updates")
    end
  end
end
