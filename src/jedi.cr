require "tablo"
require "colorize"
require "sqlite3"
require "csv"
require "yaml"
require "json"
require "digest"
require "file_utils"
require "http/client"
require "uri"
require "option_parser"
require "cryplot"
require "process"
require "i18n"

require "./jedi/core.cr"
require "./jedi/app.cr"
require "./jedi/persistence.cr"
require "./jedi/journal.cr"
require "./jedi/exchange.cr"
require "./jedi/trading_rules.cr"
require "./jedi/trading_system.cr"
require "./jedi/trading_life.cr"
require "./jedi/market_data.cr"
require "./jedi/tools.cr"
require "./jedi/command.cr"

module Jedi
  GIT_COMMIT = {{ env("JEDI_GIT_COMMIT") || "unknown" }}
  VERSION    = {{ `shards version "#{__DIR__}"`.chomp.stringify }}
  Tablo::Config::Defaults.left_padding = 1
  Tablo::Config::Defaults.right_padding = 1

  CMDLINE = ARGV.join(" ")

  def self.parse_lang(lang_value : String)
    if ["C", "C.UTF-8", "POSIX"].includes?(lang_value)
      return {lang: "C", territory: nil, charset: nil, modifier: nil}
    end

    rx = /^(?<lang>[a-z]{2,3})(_(?<territory>[A-Z]{2}))?(\.(?<charset>[^@]+))?(@(?<modifier>.+))?$/
    match = lang_value.match(rx)

    if match
      {
        lang:      match.named_captures["lang"],
        territory: match.named_captures["territory"],
        charset:   match.named_captures["charset"],
        modifier:  match.named_captures["modifier"],
      }
    else
      raise LowLevelError.new(
        "invalid LANG format '#{lang_value}'",
        key: "infra.invalid_lang_format",
        context: {:lang => lang_value},
        kind: LowLevelError::Kind::UserInput,
        log_context: {:source => Core::Utils.source(__FILE__, __LINE__)})
    end
  end

  def self.logfile_label : String
    App.paths.try(&.log_file) || "<uninitialized>"
  end

  def self.exception_label(ex : Exception) : String
    ex.message || ex.class.name
  end

  def self.exception_label(ex : AppException) : String
    if ex.key == "app.invalid_environment"
      env = ENV["JEDI_ENV"]? || ""
      "Invalid JEDI_ENV: '#{env}'. Allowed values are: #{App::ENV_ALLOWED_VALUES}."
    else
      ex.message || ex.key
    end
  end

  def self.fallback_report_exception(ex : Exception, handling_ex : Exception? = nil) : Nil
    STDERR.puts "[ERROR] #{exception_label(ex)}"

    if handling_ex
      STDERR.puts "[ERROR] Error handling failed: #{exception_label(handling_ex)}"
    end
  end

  def self.safe_report_io_error(ex : IO::Error) : Int32
    begin
      App.error(key: "infra.io_error", params: {:ex_message => ex.message.to_s})
      App.info(key: "infra.see_logfile", params: {:logfile => logfile_label}, force: true)

      App.logger.exception(
        ex,
        "io_error",
        {:cmdline => CMDLINE}
      )

      App.logger.error(
        "command_failed",
        "",
        {:cmdline => CMDLINE, :reason => "io_error"}
      )

      App.flush_messages
    rescue handling_ex
      fallback_report_exception(ex, handling_ex)
    end

    1
  end

  def self.safe_report_app_exception(ex : AppException) : Int32
    begin
      if ex.key == "app.initialization.cancelled"
        STDERR.puts I18n.t(ex.key)
        return 0
      end
      # capture exception (see Helpers)
      App.exception(ex)

      App.logger.warn(
        "command_failed",
        "",
        {
          :cmdline => CMDLINE,
          :reason  => "app_exception",
          :key     => ex.key,
        }
      )
      if x = ex.help_key
        App.info(key: x, params: ex.context, force: true)
      end
      App.flush_messages
    rescue handling_ex
      fallback_report_exception(ex, handling_ex)
    end

    1
  end

  def self.safe_report_low_level_error(ex : LowLevelError) : Int32
    App.raise_from_low_level(ex)
  rescue app_ex : AppException
    safe_report_app_exception(app_ex)
  rescue handling_ex
    fallback_report_exception(ex, handling_ex)
    1
  end

  def self.safe_report_system_exception(ex : Exception) : Int32
    begin
      App.error(key: "infra.system_exception", params: {:ex_message => ex.message.to_s})
      App.info(key: "infra.see_logfile", params: {:logfile => logfile_label}, force: true)

      App.logger.exception(
        ex,
        "system_exception",
        {:cmdline => CMDLINE}
      )

      App.logger.error(
        "command_failed",
        "",
        {:cmdline => CMDLINE, :reason => "system_exception"}
      )

      App.flush_messages
    rescue handling_ex
      fallback_report_exception(ex, handling_ex)
    end

    1
  end

  @@i18n_initialized = false

  def self.init_i18n(forced_lang : String? = nil) : Nil
    lang =
      if forced_lang
        parse_lang(forced_lang)[:lang].as(String)
      elsif App.locale =~ /^system$/i
        parse_lang(ENV["LANG"]? || "en_US.UTF-8")[:lang].as(String)
      else
        parse_lang(App.locale)[:lang].as(String)
      end

    lang = "en" unless {"en", "fr"}.includes?(lang)

    unless @@i18n_initialized
      I18n.config.loaders = [
        I18n::Loader::YAML.embed("src/jedi/locales/en"),
        I18n::Loader::YAML.embed("src/jedi/locales/fr"),
      ] of I18n::Loader::Base

      I18n.config.fallbacks = I18n::Locale::Fallbacks.new(
        {"fr" => ["en"]},
        default: ["en"]
      )

      I18n.config.default_locale = lang
      I18n.init
      @@i18n_initialized = true
    end

    App.lang = lang
    I18n.locale = lang
  end

  def self.run_cli : Int32
    begin
      App.bootstrap
      App.init_stage1
      init_i18n
      App.init_stage2

      Tablo::Config::Defaults.border_definition = App.border

      if loggable = App.loggable_command?
        App.logger.info(
          "command_started",
          "",
          {:cmdline => CMDLINE}
        )
      end

      Command.new(App.conn_main).run
    rescue ex : IO::Error
      if ex.os_error == Errno::EPIPE
        return 0
      else
        return safe_report_io_error(ex)
      end
    rescue ex : LowLevelError
      return safe_report_low_level_error(ex)
    rescue ex : AppException
      return safe_report_app_exception(ex)
    rescue ex
      return safe_report_system_exception(ex)
    else
      if loggable
        App.logger.info(
          "command_completed",
          "",
          {:cmdline => CMDLINE}
        )
      end
      App.flush_messages
      return 0
    ensure
      App.conn_main.close unless App.conn_main?.nil?
      App.conn_memory.close unless App.conn_memory?.nil?
      STDERR.print "\033[?25h"
    end
  end
end
