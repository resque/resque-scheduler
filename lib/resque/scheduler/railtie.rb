require 'resque/scheduler/server'

module Resque
  class Railtie < Rails::Railtie
    rake_tasks do
      require 'resque/scheduler/tasks'
    end
  end
end
