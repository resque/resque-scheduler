require 'resque/scheduler/server'

module Resque
  module Scheduler
    class Railtie < Rails::Railtie
      rake_tasks do
        require 'resque/scheduler/tasks'
      end
    end
  end
end
