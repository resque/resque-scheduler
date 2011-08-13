require 'rubygems'
require 'daemons'
require 'optparse'
require 'logger'

module Resque
  # A wrapper designed to daemonize a Resque::Scheduler instance to keep in
  # running in the background.
  # Connects output to a custom logger, if available. Creates a pid file
  # suitable for monitoring with {monit}[http://mmonit.com/monit/].
  #
  # To use in a Rails app, <code>script/rails generate resque_scheduler</code>.
  class SchedulerDaemon

    def initialize(args)
      @options = {:environment => :development, :delay => 5}

      optparse = OptionParser.new do |opts|
        opts.banner = "Usage: #{File.basename($0)} [options] start|stop|restart|run"

        opts.on('-h', '--help', 'Show this message.') do
          puts opts
          exit 1
        end
        opts.on('-e', '--environment=NAME', 'Specifies the environment to run this resque-scheduler in ([development]/production).') do |e|
          @options[:environment] = e
        end
        opts.on('-v', '--verbose', "Turn on verbose mode.") do
          @options[:verbose] = true
        end
        opts.on('-q', '--quiet', "Turn off logging.") do
          @options[:quiet] = true
        end
        opts.on('-d', '--delay=D', "Delay between rounds of work (seconds).") do |d|
          @options[:delay] = d.to_i
        end
      end

      # If no arguments, give help screen
      @args = optparse.parse!(args.empty? ? ['-h'] : args)
    end

    def daemonize
      Daemons.run_proc("resque-scheduler", :dir => "#{::RAILS_ROOT}/tmp/pids", :dir_mode => :normal, :ARGV=> @args) do
        logger = Logger.new(File.join(::RAILS_ROOT, 'log', 'resque-scheduler.log'))
        Resque::Scheduler.logger = logger
        Resque::Scheduler.delay = @options[:delay]
        Resque::Scheduler.verbose = @options[:verbose]
        Resque::Scheduler.run
      end
    rescue => e
      STDERR.puts e.message
      logger.fatal(e) if logger && logger.respond_to?(:fatal)
      exit 1
    end

  end

end
