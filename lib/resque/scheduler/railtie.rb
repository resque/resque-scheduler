require 'resque/scheduler/server'

module Resque
  class Railtie < Rails::Railtie
    rake_tasks do
      require 'resque/scheduler/tasks'
    end

    initializer 'resque-scheulder.railtie.initializer' do
      Resque.schedule = YAML.load_file('config/resque_schedule.yml')
    end
  end
end


