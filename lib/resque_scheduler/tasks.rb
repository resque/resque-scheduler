# require 'resque/tasks'
# will give you the resque tasks

namespace :resque do
  task :setup

  desc "Start Resque Scheduler"
  task :scheduler => :scheduler_setup do |t,args|
    require 'resque'
    require 'resque_scheduler'

    Resque::Scheduler.verbose = true if ENV['VERBOSE']
    Resque::Scheduler.run
  end

  # task :scheduler_setup => :setup
  task :scheduler_setup do
    path = ENV['load_path']
    load path.to_s.strip if path
  end

end