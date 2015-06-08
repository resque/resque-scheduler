# vim:fileencoding=utf-8
require 'resque-scheduler'
require 'resque/server'
require 'json'

# Extend Resque::Server to add tabs
module Resque
  module Scheduler
    module Server
      unless defined?(::Resque::Scheduler::Server::VIEW_PATH)
        VIEW_PATH = File.join(File.dirname(__FILE__), 'server', 'views')
      end

      def self.included(base)
        base.class_eval do
          helpers { include HelperMethods }
          include ServerMethods

          get('/schedule') { schedule }
          post('/schedule/requeue') { schedule_requeue }
          post('/schedule/requeue_with_params') do
            schedule_requeue_with_params
          end
          delete('/schedule') { delete_schedule }
          get('/delayed') { delayed }
          get('/delayed/jobs/:klass') { delayed_jobs_klass }
          post('/delayed/search') { delayed_search }
          get('/delayed/:timestamp') { delayed_timestamp }
          post('/delayed/queue_now') { delayed_queue_now }
          post('/delayed/cancel_now') { delayed_cancel_now }
          post('/delayed/clear') { delayed_clear }
        end
      end

      module ServerMethods
        def schedule
          Resque.reload_schedule! if Resque::Scheduler.dynamic
          erb scheduler_template('scheduler')
        end

        def schedule_requeue
          @job_name = params['job_name'] || params[:job_name]
          config = Resque.schedule[@job_name]
          @parameters = config['parameters'] || config[:parameters]
          if @parameters
            erb scheduler_template('requeue-params')
          else
            Resque::Scheduler.enqueue_from_config(config)
            redirect u('/overview')
          end
        end

        def schedule_requeue_with_params
          job_name = params['job_name'] || params[:job_name]
          config = Resque.schedule[job_name]
          # Build args hash from post data (removing the job name)
          submitted_args = params.reject do |key, _value|
            key == 'job_name' || key == :job_name
          end

          # Merge constructed args hash with existing args hash for
          # the job, if it exists
          config_args = config['args'] || config[:args] || {}
          config_args = config_args.merge(submitted_args)

          # Insert the args hash into config and queue the resque job
          config = config.merge('args' => config_args)
          Resque::Scheduler.enqueue_from_config(config)
          redirect u('/overview')
        end

        def delete_schedule
          if Resque::Scheduler.dynamic
            job_name = params['job_name'] || params[:job_name]
            Resque.remove_schedule(job_name)
          end
          redirect u('/schedule')
        end

        def delayed
          erb scheduler_template('delayed')
        end

        def delayed_jobs_klass
          begin
            klass = Resque::Scheduler::Util.constantize(params[:klass])
            @args = JSON.load(URI.decode(params[:args]))
            @timestamps = Resque.scheduled_at(klass, *@args)
          rescue
            @timestamps = []
          end

          erb scheduler_template('delayed_schedules')
        end

        def delayed_search
          @jobs = find_job(params[:search])
          erb scheduler_template('search')
        end

        def delayed_timestamp
          erb scheduler_template('delayed_timestamp')
        end

        def delayed_queue_now
          timestamp = params['timestamp'].to_i
          if timestamp > 0
            Resque::Scheduler.enqueue_delayed_items_for_timestamp(timestamp)
          end
          redirect u('/overview')
        end

        def delayed_cancel_now
          klass = Resque::Scheduler::Util.constantize(params['klass'])
          timestamp = params['timestamp']
          args = Resque.decode params['args']
          Resque.remove_delayed_job_from_timestamp(timestamp, klass, *args)
          redirect u('/delayed')
        end

        def delayed_clear
          Resque.reset_delayed_queue
          redirect u('delayed')
        end
      end

      module HelperMethods
        def format_time(t)
          t.strftime('%Y-%m-%d %H:%M:%S %z')
        end

        def queue_from_class_name(class_name)
          Resque::Scheduler::Util.constantize(class_name).queue_name
        end

        # given an active_job_wrapper {
        #   "class"=>"ActiveJob::QueueAdapters::ResqueAdapter::JobWrapper",
        #   "args"=>[
        #     {
        #       "job_class"=>"SomeQuickJob",
        #       "job_id"=>"2b031483-09f6-45bc-98ea-cc15059fb464",
        #       "queue_name"=>"quick",
        #       "arguments"=>[]
        #     }
        #   ]
        # }
        # returns {
        #   "job_class"=>"SomeQuickJob",
        #   "job_id"=>"2b031483-09f6-45bc-98ea-cc15059fb464",
        #   "queue_name"=>"quick",
        #   "arguments"=>[]
        # }
        def deserialize_active_job(active_job_wrapper)
          active_job_wrapper["args"].first
        end

        # given an active_job_wrapper {
        # returns a mix of active_job/resque to ui compat
        def serialize_as_resque_job(active_job_wrapper)
          aj = deserialize_active_job(active_job_wrapper)

          {
            'queue' => aj['queue_name'],
            'args'  => aj['arguments'],
            'class' => aj['job_class']
          }.merge!(active_job_wrapper)
        end

        def find_job(worker)
          worker = worker.downcase
          results = working_jobs_for_worker(worker)

          dels = delayed_jobs_for_worker(worker)
          results += dels.select do |j|
            aj = deserialize_active_job(j)
            aj['job_class'].downcase.include?(worker) &&
            j.merge!('where_at' => 'delayed')
          end

          Resque.queues.each do |queue|
            queued = Resque.peek(queue, 0, Resque.size(queue))
            queued = [queued] unless queued.is_a?(Array)
            results += queued.select do |j|
              aj = deserialize_active_job(j)
              aj['job_class'].downcase.include?(worker) &&
              j.merge!('queue' => queue, 'where_at' => 'queued')
            end
          end

          results.map{|j| serialize_as_resque_job(j) }
        end

        def schedule_interval(config)
          if config['every']
            schedule_interval_every(config['every'])
          elsif config['cron']
            'cron: ' + config['cron'].to_s
          else
            'Not currently scheduled'
          end
        end

        def schedule_interval_every(every)
          every = [*every]
          s = 'every: ' << every.first

          return s unless every.length > 1

          s << ' ('
          meta = every.last.map do |key, value|
            "#{key.to_s.gsub(/_/, ' ')} #{value}"
          end
          s << meta.join(', ') << ')'
        end

        def schedule_class(config)
          if config['class'].nil? && !config['custom_job_class'].nil?
            config['custom_job_class']
          else
            config['class']
          end
        end

        def scheduler_template(name)
          File.read(
            File.expand_path("../server/views/#{name}.erb", __FILE__)
          )
        end

        def scheduled_in_this_env?(name)
          return true if Resque.schedule[name]['rails_env'].nil?
          rails_env(name).split(/[\s,]+/).include?(Resque::Scheduler.env)
        end

        def rails_env(name)
          Resque.schedule[name]['rails_env']
        end

        def scheduler_view(filename, options = {}, locals = {})
          source = File.read(File.join(VIEW_PATH, "#{filename}.erb"))
          erb source, options, locals
        end

        private

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
  end
end

Resque::Server.tabs << 'Schedule'
Resque::Server.tabs << 'Delayed'

Resque::Server.class_eval do
  include Resque::Scheduler::Server
end
