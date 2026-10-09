module Jedi
  module Journal
    struct NoteState
      getter date : Time
      getter summary : String
      getter contents : String

      def initialize(
        @date : Time,
        @summary : String,
        @contents : String,
      )
      end
    end
  end
end
