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

    def search
      @jobs = find_job(params[:search])
    end

    protected

    def find_job(worker)
      worker = worker.downcase
      results = working_jobs_for_worker(worker)

      dels = delayed_jobs_for_worker(worker)
      results += dels.select do |j|
        j['class'].downcase.include?(worker) &&
            j.merge!('where_at' => 'delayed')
      end

      Resque.queues.each do |queue|
        queued = Resque.peek(queue, 0, Resque.size(queue))
        queued = [queued] unless queued.is_a?(Array)
        results += queued.select do |j|
          j['class'].downcase.include?(worker) &&
              j.merge!('queue' => queue, 'where_at' => 'queued')
        end
      end

      results
    end


    def working_jobs_for_worker(worker)
      [].tap do |results|
        working = [*Resque.working]
        work = working.select do |w|
          w.job && w.job['payload'] &&
              w.job['payload']['class'].downcase.include?(worker)
        end
        work.each do |w|
          results += [
              w.job['payload'].merge(
                  'queue' => w.job['queue'], 'where_at' => 'working'
              )
          ]
        end
      end
    end

    def delayed_jobs_for_worker(_worker)
      [].tap do |dels|
        schedule_size = Resque.delayed_queue_schedule_size
        Resque.delayed_queue_peek(0, schedule_size).each do |d|
          Resque.delayed_timestamp_peek(
              d, 0, Resque.delayed_timestamp_size(d)).each do |j|
            dels << j.merge!('timestamp' => d)
          end
        end
      end
    end
  end
end