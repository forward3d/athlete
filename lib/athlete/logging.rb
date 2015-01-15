module Athlete
  module Logging
    
    @@logger = Logger.new(STDOUT)
    @@logger.formatter = proc do |severity, datetime, progname, msg|
      "#{datetime} [#{severity}]: #{msg.to_s.chomp}\n"
    end
    
    def loglevel(level)
      @@logger.level = level
    end
    
    def get_loglevel
      @@logger.level
    end
    
    def info(msg)
      @@logger.info(msg)
    end
    
    def warn(msg)
      @@logger.warn(msg)
    end
    
    def fatal(msg)
      @@logger.fatal(msg)
    end
    
    def debug(msg)
      @@logger.debug(msg)
    end
    
  end
end