require "../spec_helper"
require "../support/cli_spec_helper"

module JediQuoteCommandSpec
  extend self

  def with_argv(args : Array(String), & : ->) : Nil
    previous = ARGV.dup
    ARGV.clear
    ARGV.concat(args)

    begin
      yield
    ensure
      ARGV.clear
      ARGV.concat(previous)
    end
  end
end

describe Jedi::QuoteSubCommand do
  it "forwards the requested mode when updating one security" do
    JediCliSpec.with_cli_db do |conn|
      JediSpec.insert_security(conn)
      received = [] of Tuple(Jedi::PkId, String?)
      update_quote = ->(security : Jedi::Exchange::Security, mode : String?) {
        received << {security.id, mode}
        "eod"
      }

      JediQuoteCommandSpec.with_argv([
        "update", "FR4487601001", "--mode=eod",
      ]) do
        Jedi::QuoteSubCommand.new(
          conn,
          output: IO::Memory.new,
          update_quote: update_quote,
        ).parser_on_quote
      end

      received.should eq([{1_i64, "eod"}])
    end
  end

  it "rejects a twelve-character identifier with an invalid ISIN checksum" do
    JediCliSpec.with_cli_db do |conn|
      ex = expect_raises(Jedi::AppException) do
        JediQuoteCommandSpec.with_argv(["get", "FR0000000001"]) do
          Jedi::QuoteSubCommand.new(conn).parser_on_quote
        end
      end

      ex.key.should eq("quote.get.invalid_isin")
      ex.level.should eq(Jedi::AppException::Level::Warn)
    end
  end
end
