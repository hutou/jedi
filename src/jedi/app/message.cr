module Jedi
  module App
    struct Message
      enum Level
        Info
        Warn
        Error
      end

      getter level : Level
      getter key : String
      getter params : Hash(Symbol, String)
      getter force : Bool

      def initialize(
        @level : Level,
        @key : String,
        @params : Hash(Symbol, String) = Hash(Symbol, String).new,
        @force : Bool = false,
      )
      end

      def self.i18n(
        level : Level,
        key : String,
        params : Hash(Symbol, String) = Hash(Symbol, String).new,
        *,
        force : Bool = false,
      ) : self
        new(level, key, params, force)
      end

      def text : String
        if key
          I18n.t(key.not_nil!, params)
        else
          ""
        end
      end
    end

    enum OutputMode
      Normal
      Simulation
      Verbose

      def display?(level : Message::Level) : Bool
        case self
        in .normal?, .verbose?
          true
        in .simulation?
          !level.info?
        end
      end
    end

    def self.with_output_mode(mode : OutputMode, &) : Nil
      previous = output_mode
      begin
        self.output_mode = mode
        yield
      ensure
        self.output_mode = previous
      end
    end
  end
end
