
# Extend Resque::Server to add tabs
module ResqueScheduler
  
  module Server

    def self.included(base)

      base.class_eval do

        helpers do
          def format_time(t)
            t.strftime("%Y-%m-%d %H:%M:%S")
          end

          def queue_from_class_name(class_name)
            Resque.queue_from_class(Resque.constantize(class_name))
          end
        end

        get "/schedule" do
          # Is there a better way to specify alternate template locations with sinatra?
          erb File.read(File.join(File.dirname(__FILE__), 'server/views/scheduler.erb'))
        end

        post "/schedule/requeue" do
          config = Resque.schedule[params['job_name']]
          Resque::Scheduler.enqueue_from_config(config)
          redirect u("/overview")
        end
        
        get "/delayed" do
          # Is there a better way to specify alternate template locations with sinatra?
          erb File.read(File.join(File.dirname(__FILE__), 'server/views/delayed.erb'))
        end

        get "/delayed/:timestamp" do
          # Is there a better way to specify alternate template locations with sinatra?
          erb File.read(File.join(File.dirname(__FILE__), 'server/views/delayed_timestamp.erb'))
        end
        
        post "/delayed/queue_now" do
          timestamp = params['timestamp']
          Resque::Scheduler.enqueue_delayed_items_for_timestamp(timestamp.to_i) if timestamp.to_i > 0
          redirect u("/overview")
        end

      end

    end

    Resque::Server.tabs << 'Schedule'
    Resque::Server.tabs << 'Delayed'

  end
  
end