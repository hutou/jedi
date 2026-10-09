require "../support/jedi_spec_helper"

module DatabaseLoadNoteRollbackSpec
  extend self

  US = "\x1f"

  def with_dump_file(contents : String, &)
    file = File.tempfile("jedi-database-", ".dump")
    path = file.path
    begin
      file.print(contents)
      file.flush
      yield path
    ensure
      file.close
      File.delete(path) if File.exists?(path)
    end
  end

  def line(*fields) : String
    fields.join(US)
  end
end

describe Jedi::Database::Main do
  it "rolls the complete load back when note contents is empty" do
    dump_text = [
      DatabaseLoadNoteRollbackSpec.line(
        "jedi", "security", "create", "FR4487601001", "ROLLBACK", "RBK",
        "0.01", "0.01", "0.0"),
      DatabaseLoadNoteRollbackSpec.line(
        "jedi", "note", "create", "2026-09-27", "Invalid note", ""),
    ].join("\n") + "\n"

    DatabaseLoadNoteRollbackSpec.with_dump_file(dump_text) do |filename|
      JediSpec.with_db do |target|
        Jedi::App.simulation = Jedi::SimulationMode::None

        expect_raises(Jedi::LowLevelError) do
          Jedi::Database::Main.new(target).load(filename, IO::Memory.new)
        end

        Jedi::App.simulation.should eq(Jedi::SimulationMode::None)
        %w(security scale trade settings operation note).each do |table|
          target.scalar("SELECT COUNT(*) FROM #{table}").as(Int64).should eq(0_i64)
        end
      end
    end
  end
end
