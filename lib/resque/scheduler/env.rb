# vim:fileencoding=utf-8

require 'English' # $PROCESS_ID

module Resque
  module Scheduler
    class Env
      def initialize(options)
        @options = options
        @pidfile_path = nil
      end

      def setup
        require 'resque'
        require 'resque/scheduler'

        setup_backgrounding
        setup_pid_file
        setup_scheduler_configuration
      end

      def cleanup
        cleanup_pid_file
      end

      private

      attr_reader :options, :pidfile_path

      def setup_backgrounding
        return unless options[:background]

        # Need to set this here for conditional Process.daemon redirect of
        # stderr/stdout to /dev/null
        Resque::Scheduler.quiet = !!options[:quiet]

        unless Process.respond_to?('daemon')
          abort 'background option is set, which requires ruby >= 1.9'
        end

        Process.daemon(true, !Resque::Scheduler.quiet)
        Resque.redis.client.reconnect
      end

      def setup_pid_file
        return unless options[:pidfile]

        @pidfile_path = File.expand_path(options[:pidfile])

        File.open(pidfile_path, 'w') do |f|
          f.puts $PROCESS_ID
        end

        at_exit { cleanup_pid_file }
      end

      def setup_scheduler_configuration
        Resque::Scheduler.configure do |c|
          [:app_name, :env, :logfile, :logformat].each do |sym|
            if (v = options[sym]) && !v.nil?
              c.public_send "#{sym}=", v
            end
          end

          if (dynamic = options[:dynamic]) && !dynamic.nil?
            c.dynamic = !!dynamic
          end

          if (psleep = options[:poll_sleep_amount]) && !psleep.nil?
            c.poll_sleep_amount = Float(psleep)
          end

          if (verbose = options[:verbose]) && !verbose.nil?
            c.verbose = !!verbose
          end
        end
      end

      def cleanup_pid_file
        return unless pidfile_path

        File.delete(pidfile_path) if File.exist?(pidfile_path)
        @pidfile_path = nil
      end
    end
  end
end
