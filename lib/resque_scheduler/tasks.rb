# vim:fileencoding=utf-8

require 'English'
require 'resque/tasks'
require 'resque_scheduler'

namespace :resque do
  task :setup

  def scheduler_cli
    @scheduler_cli ||= ResqueScheduler::Cli.new(
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
    unless scheduler_cli.pre_setup
      Rake::Task['resque:setup'].invoke
    end
  end
end
