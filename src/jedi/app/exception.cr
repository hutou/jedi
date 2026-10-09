module Jedi
  alias LogContext = Hash(Symbol, String)
  alias Context = Hash(Symbol, String)
  alias LogCode = String | Symbol

  # Error raised below the application boundary.
  #
  # It is never displayed directly to the user. The command boundary (or the
  # top-level CLI boundary during initialization) passes it to
  # `App.raise_from_low_level`, which alone builds an `AppException` and keeps
  # this error as its cause. `log_backtrace` controls whether the detailed
  # backtrace is written to the log; source and other context remain available.

  class LowLevelError < Exception
    enum Kind
      # Non défini initialement (défaut)
      Unclassified

      # Erreur de syntaxe ou de contenu fourni par l'utilisateur.
      # La page d'aide de la commande peut être pertinente.
      UserInput

      # Erreur métier connue : élément absent, déjà utilisé, conflit, etc.
      # Message utilisateur précis, mais pas nécessairement d'aide CLI.
      Domain

      # Donnée persistante invalide ou corrompue.
      # L'utilisateur ne peut généralement pas la corriger avec Jedi.
      InvalidData

      # Erreur technique non qualifiée.
      Technical
    end

    getter key : String?
    getter context : Context
    getter kind : Kind
    getter log_context : LogContext
    getter log_backtrace : Bool

    @key : String?

    # Erreur disposant d'un véritable message technique.
    def initialize(
      message : String,
      *,
      key : String? = nil,
      context : Context = Context.new,
      kind : Kind = Kind::Unclassified,
      log_context : LogContext = LogContext.new,
      log_backtrace : Bool = false,
      cause : Exception? = nil,
    )
      @key = key
      @context = context
      @kind = kind
      @log_context = log_context
      @log_backtrace = log_backtrace

      super(message, cause)
    end

    # Erreur connue dont la clé constitue à elle seule
    # un identifiant technique suffisant.
    def initialize(
      *,
      key : String,
      context : Context = Context.new,
      kind : Kind = Kind::Domain,
      log_context : LogContext = LogContext.new,
      log_backtrace : Bool = false,
      cause : Exception? = nil,
    )
      @key = key
      @context = context
      @kind = kind
      @log_context = log_context
      @log_backtrace = log_backtrace

      super(key, cause)
    end
  end

  # High-level exception carrying the localized message key and the
  # information required by the application output and logging layers.
  # Instances are created exclusively by `App.raise_from_low_level`.
  class AppException < Exception
    enum Level
      Info
      Warn
      Error
    end

    getter level : Level
    getter key : String
    getter context : LogContext
    getter help_key : String?
    getter log_message : String?
    getter log_context : LogContext

    def initialize(
      *,
      @key : String,
      @level : Level = Level::Warn,
      @context : LogContext = LogContext.new,
      @help_key : String? = nil,
      @log_message : String? = nil,
      @log_context : LogContext = LogContext.new,
      cause : Exception? = nil,
    )
      super(@log_message || @key, cause)
    end
  end
end
