module ResqueWeb::Plugins::ResqueScheduler

  class DelayedController < ResqueWeb::ApplicationController

    def index
    end

    def jobs_klass
      begin
        klass = Resque::Scheduler::Util.constantize(params[:klass])
        @args = JSON.load(URI.decode(params[:args]))
        @timestamps = Resque.scheduled_at(klass, *@args)
      rescue
        @timestamps = []
      end
    end
  end
end