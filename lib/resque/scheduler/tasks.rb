# vim:fileencoding=utf-8

require 'resque/tasks'
require 'resque-scheduler'

namespace :resque do
  task :setup

  def scheduler_cli
    @scheduler_cli ||= Resque::Scheduler::Cli.new(
      %W(#{ENV['RESQUE_SCHEDULER_OPTIONS']})
    )
  end

  desc 'Start Resque Scheduler'
  task scheduler: :scheduler_setup do
    scheduler_cli.setup_env
    scheduler_cli.run_forever
  end

  task :scheduler_setup do
    scheduler_cli.parse_options
    Rake::Task['resque:setup'].invoke unless scheduler_cli.pre_setup
  end

  desc 'A maintenance task for migrating scheduler tasks from one redis DB to another.'
  task :migrate_scheduler, [:from_redis, :to_redis] do |_t, args|
    Rake::Task['environment'].invoke if Rake::Task['environment']
    from_redis = args[:from_redis]
    to_redis = args[:to_redis]
    message = 'Missing URL. Usage: rake resque:migrate_scheduler[from_redis_url, to_redis_url]'
    raise message unless from_redis && to_redis
    puts "Migrating scheduled jobs from #{from_redis} to #{to_redis}"
    Resque::Scheduler::ScheduledJobMigrator.new(from_redis, to_redis).migrate!
  end
end
