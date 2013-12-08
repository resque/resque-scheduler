# vim:fileencoding=utf-8

require 'English'
require 'resque/tasks'

namespace :resque do
  task :setup

  desc 'Start Resque Scheduler'
  task :scheduler => :scheduler_setup do
    require 'resque'
    require 'resque_scheduler'

    # Need to set this here for conditional Process.daemon redirect of
    # stderr/stdout to /dev/null
    Resque::Scheduler.mute = !!ENV['MUTE']

    if ENV['BACKGROUND']
      unless Process.respond_to?('daemon')
        abort 'env var BACKGROUND is set, which requires ruby >= 1.9'
      end

      Process.daemon(true, !Resque::Scheduler.mute)
      Resque.redis.client.reconnect
    end

    File.open(ENV['PIDFILE'], 'w') { |f| f.puts $PROCESS_ID } if ENV['PIDFILE']

    Resque::Scheduler.configure do |c|
      # These settings are somewhat redundant given the defaults present
      # in the attr reader methods.  They are left here for clarity and
      # to serve as an example of how to use `.configure`.

      c.dynamic = !!ENV['DYNAMIC_SCHEDULE']
      c.verbose = !!ENV['VERBOSE']
      c.logfile = ENV['LOGFILE']
      c.poll_sleep_amount = Float(ENV.fetch('RESQUE_SCHEDULER_INTERVAL', '5'))
      c.app_name = ENV['APP_NAME']
    end

    Resque::Scheduler.run
  end

  task :scheduler_setup do
    if ENV['INITIALIZER_PATH']
      load ENV['INITIALIZER_PATH'].to_s.strip
    else
      Rake::Task['resque:setup'].invoke
    end
  end
end
