# vim:fileencoding=utf-8

require 'optparse'

module ResqueScheduler
  class Cli
    BANNER = <<-EOF.gsub(/ {6}/, '')
      Usage: resque-scheduler [options]

      Runs a resque scheduler process directly (rather than via rake).

    EOF
    OPTIONS = [
      {
        args: ['-n', '--app-name [APP_NAME]', 'Application name for procline'],
        callback: ->(options) { ->(n) { options[:app_name] = n } }
      },
      {
        args: ['-B', '--background', 'Run in the background [BACKGROUND]'],
        callback: ->(options) { ->(b) { options[:background] = b  } }
      },
      {
        args: ['-D', '--dynamic-schedule',
               'Enable dynamic scheduling [DYNAMIC_SCHEDULE]'],
        callback: ->(options) { ->(d) { options[:dynamic] = d } }
      },
      {
        args: ['-E', '--environment [RAILS_ENV]', 'Environment name'],
        callback: ->(options) { ->(e) { options[:env] = e } }
      },
      {
        args: ['-I', '--initializer-path [INITIALIZER_PATH]',
               'Path to optional initializer ruby file'],
        callback: ->(options) { ->(i) { options[:initializer_path] = i } }
      },
      {
        args: ['-i', '--interval [RESQUE_SCHEDULER_INTERVAL]',
               'Interval for checking if a scheduled job must run'],
        callback: ->(options) { ->(i) { options[:poll_sleep_amount] = i } }
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
        args: ['-P', '--pidfile [PIDFILE]', 'PID file name'],
        callback: ->(options) { ->(p) { options[:pidfile] = p } }
      },
      {
        args: ['-q', '--quiet', 'Run with minimal output [QUIET] (or [MUTE])'],
        callback: ->(options) { ->(q) { options[:mute] = q } }
      },
      {
        args: ['-v', '--verbose', 'Run with verbose output [VERBOSE]'],
        callback: ->(options) { ->(v) { options[:verbose] = v } }
      }
    ].freeze

    def self.run!(argv = ARGV, env = ENV)
      new(argv, env).run!
    end

    def initialize(argv = ARGV, env = ENV)
      @argv = argv
      @env = env
    end

    def run!
      pre_run
      run_forever
    end

    def pre_run
      parse_options
      pre_setup
      setup_env
    end

    def parse_options
      OptionParser.new do |opts|
        opts.banner = BANNER
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

        c.app_name = options[:app_name]
        c.dynamic = !!options[:dynamic]
        c.env = options[:env]
        c.logfile = options[:logfile]
        c.logformat = options[:logformat]
        c.poll_sleep_amount = Float(options[:poll_sleep_amount] || '5')
        c.verbose = !!options[:verbose]
      end
    end

    def run_forever
      Resque::Scheduler.run
    end

    private

    attr_reader :argv, :env

    def options
      @options ||= {
        app_name: env['APP_NAME'],
        background: env['BACKGROUND'],
        dynamic: env['DYNAMIC_SCHEDULE'],
        env: env['RAILS_ENV'],
        initializer_path: env['INITIALIZER_PATH'],
        logfile: env['LOGFILE'],
        logformat: env['LOGFORMAT'],
        mute: env['MUTE'] || env['QUIET'],
        pidfile: env['PIDFILE'],
        poll_sleep_amount: env['RESQUE_SCHEDULER_INTERVAL'],
        verbose: env['VERBOSE']
      }
    end
  end
end
