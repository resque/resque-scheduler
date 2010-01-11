
# Extend Resque::Server to add tabs
module ResqueScheduler
  
  module Server

    def self.included(base)

      base.class_eval do

        helpers do
          def format_time(t)
            t.strftime("%Y-%m-%d %H:%M:%S")
          end
        end

        get "/schedule" do
          # Is there a better way to specify alternate template locations with sinatra?
          erb File.read(File.join(File.dirname(__FILE__), 'server/views/scheduler.erb'))
        end

        post "/schedule/requeue" do
          config = Resque.schedule[params['job_name']]
          Resque::Scheduler.enqueue_from_config(config)
          redirect url("/queues")
        end
        
        get "/delayed" do
          # Is there a better way to specify alternate template locations with sinatra?
          erb File.read(File.join(File.dirname(__FILE__), 'server/views/delayed.erb'))
        end

        get "/delayed/:timestamp" do
          # Is there a better way to specify alternate template locations with sinatra?
          erb File.read(File.join(File.dirname(__FILE__), 'server/views/delayed_timestamp.erb'))
        end

      end

    end

    Resque::Server.tabs << 'Schedule'
    Resque::Server.tabs << 'Delayed'

  end
  
end