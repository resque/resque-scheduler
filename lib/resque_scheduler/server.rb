require 'resque_scheduler'
require 'resque/server'

# Extend Resque::Server to add tabs
module ResqueScheduler

  module Server

    def self.included(base)

      base.class_eval do

        helpers do
          def format_time(t)
            t.strftime("%Y-%m-%d %H:%M:%S %z")
          end

          def queue_from_class_name(class_name)
            Resque.queue_from_class(Resque.constantize(class_name))
          end
        end

        get "/schedule" do
          Resque.reload_schedule! if Resque::Scheduler.dynamic
          # Is there a better way to specify alternate template locations with sinatra?
          erb File.read(File.join(File.dirname(__FILE__), 'server/views/scheduler.erb'))
        end

        post "/schedule/requeue" do
          @job_name = params['job_name'] || params[:job_name]
          config = Resque.schedule[@job_name]
          @parameters = config['parameters'] || config[:parameters]
          if @parameters
            erb File.read(File.join(File.dirname(__FILE__), 'server/views/requeue-params.erb'))
          else
            Resque::Scheduler.enqueue_from_config(config)
            redirect u("/overview")
          end
        end

        post "/schedule/requeue_with_params" do
          job_name = params['job_name'] || params[:job_name]
          config = Resque.schedule[job_name]
          # Build args hash from post data (removing the job name)
          submitted_args = params.reject {|key, value| key == 'job_name' || key == :job_name}

          # Merge constructed args hash with existing args hash for
          # the job, if it exists
          config_args = config['args'] || config[:args] || {}
          config_args = config_args.merge(submitted_args)

          # Insert the args hash into config and queue the resque job
          config = config.merge({'args' => config_args})
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

        post "/delayed/clear" do
          Resque.reset_delayed_queue
          redirect u('delayed')
        end

      end

    end

    Resque::Server.tabs << 'Schedule'
    Resque::Server.tabs << 'Delayed'

  end

end

Resque::Server.class_eval do
  include ResqueScheduler::Server
end
