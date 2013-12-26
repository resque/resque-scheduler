# vim:fileencoding=utf-8

require 'optparse'

module ResqueScheduler
  class Cli
    OPTIONS = [
      {
        args: ['-v', '--verbose', 'Run with verbose output'],
        callback: ->(options) { ->(v) { options[:verbose] = v } }
      },
      {
        args: ['-B', '--background', 'Run in the background'],
        callback: ->(options) { ->(b) { options[:background] = b  } }
      },
      {
        args: ['-P', '--pidfile [PIDFILE]', 'PID file name'],
        callback: ->(options) { ->(p) { options[:pidfile] = p } }
      },
      {
        args: ['-E', '--environment [RAILS_ENV]', 'Environment name'],
        callback: ->(options) { ->(e) { options[:env] = e } }
      },
      {
        args: ['-q', '--quiet', 'Run with minimal output'],
        callback: ->(options) { ->(q) { options[:mute] = q } }
      },
      {
        args: ['-l', '--logfile [LOGFILE]', 'Log file name'],
        callback: ->(options) { ->(l) { options[:logfile] = l } }
      },
      {
        args: ['-F', '--logformat [LOGFORMAT]', 'Log output format'],
        callback: ->(options) { ->(f) { options[:logformat] = f } }
      },
      {
        args: ['-D', '--dynamic-schedule', 'Enable dynamic scheduling'],
        callback: ->(options) { ->(d) { options[:dynamic] = d } }
      },
      {
        args: ['-n', '--app-name [APP_NAME]', 'Application name for procline'],
        callback: ->(options) { ->(n) { options[:app_name] = n } }
      },
    ].freeze

    def self.run!(argv = ARGV, env = ENV)
      new(argv, env).run!
    end

    def initialize(argv = ARGV, env = ENV)
      @argv = argv
      @env = env
    end

    def run!
      parse_options
      pre_setup
      setup_env
      run_forever
    end

    def parse_options
      OptionParser.new do |opts|
        opts.banner = 'Usage: resque-scheduler [options]'
        OPTIONS.each do |opt|
          opts.on(*opt[:args], &(opt[:callback].call(options)))
        end
      end.parse!(argv.dup)
    end

    def pre_setup
      if options[:initializer_path]
        load options[:initializer_path].to_s.strip
      else
        false
      end
    end

    def setup_env
      require 'resque'
      require 'resque/scheduler'

      # Need to set this here for conditional Process.daemon redirect of
      # stderr/stdout to /dev/null
      Resque::Scheduler.mute = !!options[:mute]

      if options[:background]
        unless Process.respond_to?('daemon')
          abort 'background option is set, which requires ruby >= 1.9'
        end

        Process.daemon(true, !Resque::Scheduler.mute)
        Resque.redis.client.reconnect
      end

      File.open(options[:pidfile], 'w') do |f|
        f.puts $PROCESS_ID
      end if options[:pidfile]

      Resque::Scheduler.configure do |c|
        # These settings are somewhat redundant given the defaults present
        # in the attr reader methods.  They are left here for clarity and
        # to serve as an example of how to use `.configure`.

        c.dynamic = !!options[:dynamic]
        c.verbose = !!options[:verbose]
        c.logfile = options[:logfile]
        c.poll_sleep_amount = Float(options[:poll_sleep_amount] || '5')
        c.app_name = options[:app_name]
      end
    end

    def run_forever
      Resque::Scheduler.run
    end

    private

    attr_reader :argv, :env

    def options
      @options ||= {
        verbose: env['VERBOSE'],
        background: env['BACKGROUND'],
        pidfile: env['PIDFILE'],
        env: env['RAILS_ENV'],
        mute: env['MUTE'] || env['QUIET'],
        logfile: env['LOGFILE'],
        logformat: env['LOGFORMAT'],
        dynamic: env['DYNAMIC_SCHEDULE'],
        app_name: env['APP_NAME'],
        poll_sleep_amount: env['RESQUE_SCHEDULER_INTERVAL'],
        initializer_path: env['INITIALIZER_PATH'],
      }
    end
  end
end
