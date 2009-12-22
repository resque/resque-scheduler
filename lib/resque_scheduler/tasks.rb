# require 'resque/tasks'
# will give you the resque tasks

namespace :resque do
  task :setup

  desc "Start Resque Scheduler"
  task :scheduler => :setup do
    require 'resque'
    require 'resque_scheduler'

    Resque::Scheduler.run
  end

end