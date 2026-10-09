module Jedi
  module Journal
    class NoteRepository
      def initialize(@conn_db : DB::Connection)
      end

      def insert!(state : NoteState) : PkId
        exec_result = @conn_db.exec("INSERT INTO note (date, summary, contents) " \
                                    "values(?, ?, ?)",
          state.date,
          state.summary,
          state.contents)
        exec_result.last_insert_id
      end
    end
  end
end
