require "./jedi_spec_helper"

module JediPlaySpec
  extend self

  def with_seeded_play(
    params : String,
    argv : Array(String),
    *,
    scale_name : String = "S_TEST",
    scale : Jedi::TradingRules::Scale::Operational = JediSpec.type_two_scale,
    &
  )
    JediSpec.with_db do |main_conn|
      JediSpec.insert_scale(main_conn, name: scale_name, scale: scale)

      JediSpec.with_db do |memory_conn|
        play = Jedi::Tools::Play.new(main_conn, memory_conn, params, argv)
        yield play
      end
    end
  end

  def operations(play : Jedi::Tools::Play) : Array(Jedi::TradingLife::Operation)
    Jedi::TradingLife::Operations.new(play.conn_memory).fetch.to_a
  end

  def settings_rows(play : Jedi::Tools::Play) : Array(Jedi::TradingSystem::Settings)
    ids = [] of Jedi::PkId
    play.conn_memory.query("SELECT id FROM settings ORDER BY id") do |rs|
      rs.each do
        ids << rs.read(Jedi::PkId)
      end
    end
    ids.map { |id| Jedi::TradingSystem::Settings.new(play.conn_memory, id) }
  end
end
