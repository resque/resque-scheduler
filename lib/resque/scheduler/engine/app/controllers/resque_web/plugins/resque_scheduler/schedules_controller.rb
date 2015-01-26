module ResqueWeb
  module Plugins
    module ResqueScheduler
      class SchedulesController < ResqueWeb::ApplicationController
        def index
          Resque.reload_schedule! if Resque::Scheduler.dynamic
        end

        def destroy
          if Resque::Scheduler.dynamic
            job_name = params['job_name'] || params[:job_name]
            Resque.remove_schedule(job_name)
          end
          redirect_to Engine.app.url_helpers.schedules_path
        end

        def requeue
          @job_name = params['job_name'] || params[:job_name]
          config = Resque.schedule[@job_name]
          @parameters = config['parameters'] || config[:parameters]
          if @parameters
            render 'requeue-params'
          else
            Resque::Scheduler.enqueue_from_config(config)
            redirect_to ResqueWeb::Engine.app.url_helpers.overview_path
          end
        end

        def requeue_with_params
          job_name = params['job_name'] || params[:job_name]
          config = Resque.schedule[job_name]
          # Build args hash from post data (removing the job name)
          submitted_args = params.reject do |key, _value|
            %w(job_name action controller).include?(key)
          end

          # Merge constructed args hash with existing args hash for
          # the job, if it exists
          config_args = config['args'] || config[:args] || {}
          config_args = config_args.merge(submitted_args)

          # Insert the args hash into config and queue the resque job
          config = config.merge('args' => config_args)
          Resque::Scheduler.enqueue_from_config(config)
          redirect_to ResqueWeb::Engine.app.url_helpers.overview_path
        end
      end
    end
  end
end
