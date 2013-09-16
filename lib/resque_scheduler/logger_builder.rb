module ResqueScheduler
  # Just builds a logger, with specified verbosity and destination.
  # The simplest example:
  #
  #   ResqueScheduler::LoggerBuilder.new.build
  class LoggerBuilder
    # Initializes new instance of the builder
    #
    # Pass :opts Hash with
    #   - :mute if logger needs to be silent for all levels. Default - false
    #   - :verbose if there is a need in debug messages. Default - false
    #   - :log_dev to output logs into a desired file. Default - STDOUT
    #
    # Example:
    #
    #   LoggerBuilder.new(:mute => false, :verbose => true, :log_dev => 'log/sheduler.log')
    def initialize(opts={})
      @muted   = !!opts[:mute]
      @verbose = !!opts[:verbose]
      @log_dev = opts[:log_dev] || STDOUT
    end

    # Returns an instance of Logger
    def build
      logger = Logger.new(@log_dev)
      logger.level = level
      logger.datetime_format = "%Y-%m-%d %H:%M:%S"
      logger.formatter = formatter

      logger
    end

    private

    def level
      if @verbose && !@muted
        Logger::DEBUG
      elsif !@muted
        Logger::INFO
      else
        Logger::FATAL
      end
    end

    def formatter
      proc do |severity, datetime, progname, msg|
        "[#{severity}] #{datetime}: #{msg}\n"
      end
    end
  end
end
