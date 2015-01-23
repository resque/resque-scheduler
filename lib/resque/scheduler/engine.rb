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

    get 'schedule', to: 'schedules#index', as: 'schedules'
    post 'schedule/requeue', to: 'schedules#requeue', as: 'requeue'
    post 'schedule/requeue_with_params', to: 'schedules#requeue_with_params', as: 'requeue_with_params'
    delete 'schedule', to: 'schedules#destroy', as: 'schedule'

    get 'delayed', to: 'delayed#index', as: 'delayed'
    get 'delayed/jobs/:klass', to: 'delayed#jobs_klass', as: 'delayed_job_class'
    post 'delayed/search', to: 'delayed#search', as: 'delayed_search'
    get 'delayed/:timestamp', to: 'delayed#timestamp', as: 'timestamp'
    post 'delayed/queue_now', to: 'delayed#queue_now', as: 'queue_now'
    post 'delayed/cancel_now', to: 'delayed#cancel_now', as: 'cancel_now'
    post '/delayed/clear', to: 'delayed#clear', as: 'clear'

  end

  def self.engine_path
    "/scheduler"
  end

  def self.tabs
    [{'schedule' => Engine.app.url_helpers.schedules_path,
      'delayed' => Engine.app.url_helpers.delayed_path}]
  end

end