require 'resque/tasks'
# will give you the resque tasks

namespace :resque do
  task :setup

  desc "Start Resque Scheduler"
  task :scheduler => :scheduler_setup do
    require 'resque'
    require 'resque_scheduler'

    # Need to set this here for conditional Process.daemon redirect of stderr/stdout to /dev/null
    Resque::Scheduler.mute = true if ENV['MUTE']

    if ENV['BACKGROUND']
      unless Process.respond_to?('daemon')
        abort "env var BACKGROUND is set, which requires ruby >= 1.9"
      end
      Process.daemon(true, !Resque::Scheduler.mute)
      Resque.redis.client.reconnect
    end

    File.open(ENV['PIDFILE'], 'w') { |f| f << Process.pid.to_s } if ENV['PIDFILE']

    Resque::Scheduler.dynamic           = true if ENV['DYNAMIC_SCHEDULE']
    Resque::Scheduler.verbose           = true if ENV['VERBOSE']
    Resque::Scheduler.logfile           = ENV['LOGFILE'] if ENV['LOGFILE']
    Resque::Scheduler.poll_sleep_amount = Integer(ENV['INTERVAL']) if ENV['INTERVAL']
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
