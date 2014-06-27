# vim:fileencoding=utf-8

module Resque
  module Scheduler
    class Env
      def initialize(options)
        @options = options
      end

      def setup
        require 'resque'
        require 'resque/scheduler'

        setup_backgrounding
        setup_pid_file
        setup_scheduler_configuration
      end

      private

      attr_reader :options

      def setup_backgrounding
        # Need to set this here for conditional Process.daemon redirect of
        # stderr/stdout to /dev/null
        Resque::Scheduler.quiet = !!options[:quiet]

        if options[:background]
          unless Process.respond_to?('daemon')
            abort 'background option is set, which requires ruby >= 1.9'
          end

          Process.daemon(true, !Resque::Scheduler.quiet)
          Resque.redis.client.reconnect
        end
      end

      def setup_pid_file
        File.open(options[:pidfile], 'w') do |f|
          f.puts $PROCESS_ID
          at_exit do
            File.delete f
          end
        end if options[:pidfile]
      end

      def setup_scheduler_configuration
        Resque::Scheduler.configure do |c|
          if options.key?(:app_name)
            c.app_name = options[:app_name]
          end

          if options.key?(:dynamic)
            c.dynamic = !!options[:dynamic]
          end

          if options.key(:env)
            c.env = options[:env]
          end

          if options.key?(:logfile)
            c.logfile = options[:logfile]
          end

          if options.key?(:logformat)
            c.logformat = options[:logformat]
          end

          if psleep = options[:poll_sleep_amount] && !psleep.nil?
            c.poll_sleep_amount = Float(psleep)
          end

          if options.key?(:verbose)
            c.verbose = !!options[:verbose]
          end
        end
      end
    end
  end
end
