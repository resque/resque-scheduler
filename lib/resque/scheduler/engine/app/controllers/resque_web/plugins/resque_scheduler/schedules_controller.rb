module ResqueWeb::Plugins::ResqueScheduler

  class SchedulesController < ResqueWeb::ApplicationController

    def index
      Resque.reload_schedule! if Resque::Scheduler.dynamic
    end

    def destroy
      if Resque::Scheduler.dynamic
        job_name = params['job_name'] || params[:job_name]
        Resque.remove_schedule(job_name)
      end
      redirect schedules_path
    end

    def requeue
      @job_name = params['job_name'] || params[:job_name]
      config = Resque.schedule[@job_name]
      @parameters = config['parameters'] || config[:parameters]
      if @parameters
        render_template 'requeue-params'
      else
        Resque::Scheduler.enqueue_from_config(config)
        redirect overview_path
      end
    end

  end
end