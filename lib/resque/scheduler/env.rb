# vim:fileencoding=utf-8

require 'English' # $PROCESS_ID

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

      def cleanup
        cleanup_pid_file
      end

      private

      # Returns a proc, that when called will attempt to delete the given file.
      # This is because implementing ObjectSpace.define_finalizer is tricky.
      # Hat-Tip to @mperham for describing in detail:
      # http://www.mikeperham.com/2010/02/24/the-trouble-with-ruby-finalizers/
      def self.pidfile_deleter(pidfile_path)
        proc do
          File.delete(pidfile_path) if File.exist?(pidfile_path)
        end
      end

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
        if options[:pidfile]
          @pidfile_path = File.expand_path(options[:pidfile])

          File.open(@pidfile_path, 'w') do |f|
            f.puts $PROCESS_ID
          end

          ObjectSpace.define_finalizer(self,
                                       Env.pidfile_deleter(@pidfile_path))
        end
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

      def cleanup_pid_file
        if @pidfile_path
          ObjectSpace.undefine_finalizer(self)
          Env.pidfile_deleter(@pidfile_path).call
          @pidfile_path = nil
        end
      end
    end
  end
end
