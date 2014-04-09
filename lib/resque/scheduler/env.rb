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
        Resque::Scheduler.quiet = !options[:quiet].nil?

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
        end if options[:pidfile]
      end

      def setup_scheduler_configuration
        Resque::Scheduler.configure do |c|
          # These settings are somewhat redundant given the defaults present
          # in the attr reader methods.  They are left here for clarity and
          # to serve as an example of how to use `.configure`.

          c.app_name = options[:app_name]
          c.dynamic = !options[:dynamic].nil?
          c.env = options[:env]
          c.logfile = options[:logfile]
          c.logformat = options[:logformat]
          c.poll_sleep_amount = Float(options[:poll_sleep_amount] || '5')
          c.verbose = !options[:verbose].nil?
        end
      end
    end
  end
end
