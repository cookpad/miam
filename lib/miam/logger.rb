class Miam::Logger < ::Logger
  include Singleton

  def initialize
    super($stdout)

    self.formatter = proc do |severity, datetime, progname, msg|
      "#{msg}\n"
    end

    self.level = Logger::INFO
  end

  def set_debug(value)
    self.level = value ? Logger::DEBUG : Logger::INFO
  end

  module Helper
    def log(level, message, options = {})
      options = (@options || {}).merge(options)
      message = "[#{level.to_s.upcase}] #{message}" unless level == :info
      message << ' (dry-run)' if options[:dry_run]
      message = message.send(options[:color]) if options[:color]
      logger = options[:logger] || Miam::Logger.instance
      logger.send(level, message)
    end
  end
end
