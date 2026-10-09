require "file_utils"

module JediPathsSpec
  extend self

  ENV_KEYS = %w(
    JEDI_ENV JEDI_CONFIG_DIR JEDI_LOG_DIR JEDI_DATA_DIR JEDI_DB_FILE JEDI_MARKET_DIR
    JEDI_DEMO_DIR JEDI_DEMO_MARKET_DIR JEDI_DEV_DIR JEDI_DEV_MARKET_DIR JEDI_DEV_BINARY
    XDG_CONFIG_HOME XDG_STATE_HOME XDG_DATA_HOME CDPATH
  )

  def with_workspace(& : String ->) : Nil
    root = File.join("/tmp", "jedi paths #{Process.pid}-#{Time.utc.to_unix_ns}")
    previous = {} of String => String?
    ENV_KEYS.each do |key|
      previous[key] = ENV[key]?
      ENV.delete(key)
    end

    Dir.mkdir_p(root)
    ENV["XDG_CONFIG_HOME"] = File.join(root, "xdg/config")
    ENV["XDG_STATE_HOME"] = File.join(root, "xdg/state")
    ENV["XDG_DATA_HOME"] = File.join(root, "xdg/data")

    begin
      Dir.cd(root) { yield root }
    ensure
      previous.each do |key, value|
        if value
          ENV[key] = value
        else
          ENV.delete(key)
        end
      end
      FileUtils.rm_rf(root)
    end
  end
end
