
# Extend Resque::Server to add tabs
module ResqueScheduler
  
  module Server

    def self.included(base)

      base.class_eval do

        get "/schedule" do
          # Is there a better way to specify alternate template locations with sinatra?
          erb File.read(File.join(File.dirname(__FILE__), 'server/views/scheduler.erb'))
        end

        post "/schedule/requeue" do
          config = Resque.schedule[params['job_name']]
          Resque::Scheduler.enqueue_from_config(config)
          redirect url("/queues")
        end
        
      end

    end

    Resque::Server.tabs << 'Schedule'

  end
  
end