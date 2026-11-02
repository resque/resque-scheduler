module Resque
  module Scheduler
    class Railtie < Rails::Railtie
      config.after_initialize do
        require 'resque/scheduler/server'
      end

      rake_tasks do
        require 'resque/scheduler/tasks'
      end
    end
  end
end
