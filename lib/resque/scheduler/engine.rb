require 'resque_web'

module ResqueWeb::Plugins::ResqueScheduler
  class Engine < Rails::Engine
    isolate_namespace ResqueWeb::Plugins::ResqueScheduler
    paths["app"] << 'lib/resque/scheduler/engine/app'
    paths["app/helpers"] << 'lib/resque/scheduler/engine/app/helpers'
    paths["app/views"] << 'lib/resque/scheduler/engine/app/views'
    paths["app/controllers"] << 'lib/resque/scheduler/engine/app/controllers'
  end

  Engine.routes do
    resources :schedules, only: [:index, :destroy]
  end

  def self.engine_path
    "/scheduler"
  end

  def self.tabs
    [{'schedule' => Engine.app.url_helpers.schedules_path}]

  end
end