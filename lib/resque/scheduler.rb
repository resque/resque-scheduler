# vim:fileencoding=utf-8

require 'redis/errors'
require 'rufus/scheduler'
require_relative 'scheduler/configuration'
require_relative 'scheduler/locking'
require_relative 'scheduler/logger_builder'
require_relative 'scheduler/signal_handling'
require_relative 'scheduler/failure_handler'

module Resque
  module Scheduler
    autoload :Cli, 'resque/scheduler/cli'
    autoload :Extension, 'resque/scheduler/extension'
    autoload :Util, 'resque/scheduler/util'
    autoload :VERSION, 'resque/scheduler/version'
    INTERMITTENT_ERRORS = [
      Errno::EAGAIN, Errno::ECONNRESET, Redis::CannotConnectError, Redis::TimeoutError
    ].freeze

    private

    extend Resque::Scheduler::Locking
    extend Resque::Scheduler::Configuration
    extend Resque::Scheduler::SignalHandling

    public

    class << self
      attr_writer :logger

      # the Rufus::Scheduler jobs that are scheduled
      attr_reader :scheduled_jobs

      # allow user to set an additional failure handler
      attr_writer :failure_handler

      # Schedule all jobs and continually look for delayed jobs (never returns)
      def run
        procline 'Starting'

        # trap signals
        register_signal_handlers

        # Quote from the resque/worker.
        # Fix buffering so we can `rake resque:scheduler > scheduler.log` and
        # get output from the child in there.
        $stdout.sync = true
        $stderr.sync = true

        was_master = nil

        begin
          @th = Thread.current

          # Now start the scheduling part of the loop.
          loop do
            begin
              # Check on changes to master/child
              @am_master = master?
              if am_master != was_master
                procline am_master ? 'Master scheduler' : 'Child scheduler'

                # Load schedule because changed
                reload_schedule!
              end

              if am_master
                handle_delayed_items
                update_schedule if dynamic
              end
              was_master = am_master
            rescue *INTERMITTENT_ERRORS => e
              log! e.message
              release_master_lock
            end
            poll_sleep
          end

        rescue Interrupt
          log 'Exiting'
        end
      end

      def print_schedule
        if rufus_scheduler
          log! "Scheduling Info\tLast Run"
          scheduler_jobs = rufus_scheduler.jobs
          scheduler_jobs.each do |_k, v|
            log! "#{v.t}\t#{v.last}\t"
          end
        end
      end

      # Pulls the schedule from Resque.schedule and loads it into the
      # rufus scheduler instance
      def load_schedule!
        procline 'Loading Schedule'

        # Need to load the schedule from redis for the first time if dynamic
        Resque.reload_schedule! if dynamic

        log! 'Schedule empty! Set Resque.schedule' if Resque.schedule.empty?

        @scheduled_jobs = {}

        Resque.schedule.each do |name, config|
          load_schedule_job(name, config)
        end
        Resque.redis.del(:schedules_changed) if am_master && dynamic
        procline 'Schedules Loaded'
      end

      # modify interval type value to value with options if options available
      def optionizate_interval_value(value)
        args = value
        if args.is_a?(::Array)
          return args.first if args.size > 2 || !args.last.is_a?(::Hash)
          # symbolize keys of hash for options
          args[2] = args[1].reduce({}) do |m, i|
            key, value = i
            m[(key.respond_to?(:to_sym) ? key.to_sym : key) || key] = value
            m
          end

          args[2][:job] = true
          args[1] = nil
        end
        args
      end

      # Loads a job schedule into the Rufus::Scheduler and stores it
      # in @scheduled_jobs
      def load_schedule_job(name, config)
        # If `rails_env` or `env` is set in the config, load jobs only if they
        # are meant to be loaded in `Resque::Scheduler.env`.  If `rails_env` or
        # `env` is missing, the job should be scheduled regardless of the value
        # of `Resque::Scheduler.env`.

        configured_env = config['rails_env'] || config['env']

        if configured_env.nil? || env_matches?(configured_env)
          log! "Scheduling #{name} "
          interval_defined = false
          interval_types = %w(cron every)
          interval_types.each do |interval_type|
            next unless !config[interval_type].nil? && !config[interval_type].empty?
            args = optionizate_interval_value(config[interval_type])
            args = [args, nil, job: true] if args.is_a?(::String)

            job = rufus_scheduler.send(interval_type, *args) do
              enqueue_recurring(name, config)
            end
            @scheduled_jobs[name] = job
            interval_defined = true
            break
          end
          unless interval_defined
            log! "no #{interval_types.join(' / ')} found for " \
                 "#{config['class']} (#{name}) - skipping"
          end
        else
          log "Skipping schedule of #{name} because configured " \
              "env #{configured_env.inspect} does not match current " \
              "env #{env.inspect}"
        end
      end

      # Returns true if the given schedule config hash matches the current env
      def rails_env_matches?(config)
        warn '`Resque::Scheduler.rails_env_matches?` is deprecated. ' \
             'Please use `Resque::Scheduler.env_matches?` instead.'
        config['rails_env'] && env &&
          config['rails_env'].split(/[\s,]+/).include?(env)
      end

      # Returns true if the current env is non-nil and the configured env
      # (which is a comma-split string) includes the current env.
      def env_matches?(configured_env)
        env && configured_env.split(/[\s,]+/).include?(env)
      end

      # Handles queueing delayed items
      # at_time - Time to start scheduling items (default: now).
      def handle_delayed_items(at_time = nil)
        timestamp = Resque.next_delayed_timestamp(at_time)
        if timestamp
          procline 'Processing Delayed Items'
          until timestamp.nil?
            enqueue_delayed_items_for_timestamp(timestamp)
            timestamp = Resque.next_delayed_timestamp(at_time)
          end
        end
      end

      def enqueue_next_item(timestamp)
        item = Resque.next_item_for_timestamp(timestamp)

        if item
          log "queuing #{item['class']} [delayed]"
          enqueue(item)
        end

        item
      end

      # Enqueues all delayed jobs for a timestamp
      def enqueue_delayed_items_for_timestamp(timestamp)
        count = 0
        batch_size = delayed_requeue_batch_size
        actual_batch_size = nil

        log "Processing delayed items for timestamp #{timestamp}, in batches of #{batch_size}"

        loop do
          handle_shutdown do
            # Continually check that it is still the master
            if am_master
              actual_batch_size = enqueue_items_in_batch_for_timestamp(timestamp,
                                                                       batch_size)
            end
          end

          count += actual_batch_size
          log "queued #{count} jobs" if actual_batch_size != -1

          # continue processing until there are no more items in this
          # timestamp. If we don't have a full batch, this is the last one.
          # This also breaks us in the event of a redis transaction failure
          # i.e. enqueue_items_in_batch_for_timestamp returned -1
          break if actual_batch_size < batch_size
        end

        log "finished queueing #{count} total jobs for timestamp #{timestamp}" if count != -1
      end

      def timestamp_key(timestamp)
        "delayed:#{timestamp.to_i}"
      end

      def enqueue_items_in_batch_for_timestamp(timestamp, batch_size)
        timestamp_bucket_key = timestamp_key(timestamp)

        encoded_jobs_to_requeue = Resque.redis.lrange(timestamp_bucket_key, 0, batch_size - 1)

        # Watch is used to ensure that the timestamp bucket we are operating on
        # is not altered by any other clients between the watch call and when we call exec
        # (to execute the multi block). We should error catch on the redis.exec return value
        # as that will indicate if the entire transaction was aborted or not. Though we should
        # be safe as our ltrim is inside the multi block and therefore also would have been
        # aborted. So nothing would have been queued, but also nothing lost from the bucket.
        watch_result = Resque.redis.watch(timestamp_bucket_key) do
          Resque.redis.multi do |pipeline|
            encoded_jobs_to_requeue.each do |encoded_job|
              pipeline.srem("timestamps:#{encoded_job}", timestamp_bucket_key)

              decoded_job = Resque.decode(encoded_job)
              enqueue(decoded_job)
            end

            pipeline.ltrim(timestamp_bucket_key, batch_size, -1)
          end
        end

        # Did the multi block successfully remove from this timestamp and enqueue the jobs?
        success = !watch_result.nil?

        # If this was the last batch in this timestamp bucket, clean up
        if success && encoded_jobs_to_requeue.count < batch_size
          Resque.clean_up_timestamp(timestamp_bucket_key, timestamp)
        end

        unless success
          # Our batched transaction failed in Redis due to the timestamp_bucket_key value
          # being modified while we built our multi block. We return -1 to ensure we break
          # out of the loop iterating on this timestamp so it can be re-processed via the
          # loop in handle_delayed_items.
          return -1
        end

        # will return 0 if none were left to batch
        encoded_jobs_to_requeue.count
      end

      def enqueue(config)
        enqueue_from_config(config)
      rescue => e
        Resque::Scheduler.failure_handler.on_enqueue_failure(config, e)
      end

      def handle_shutdown
        exit if @shutdown
        yield
        exit if @shutdown
      end

      # Enqueues a job based on a config hash
      def enqueue_from_config(job_config)
        args = job_config['args'] || job_config[:args]

        klass_name = job_config['class'] || job_config[:class]
        begin
          klass = Resque::Scheduler::Util.constantize(klass_name)
        rescue NameError
          klass = klass_name
        end

        params = args.is_a?(Hash) ? [args] : Array(args)
        queue = job_config['queue'] ||
                job_config[:queue] ||
                Resque.queue_from_class(klass)
        # Support custom job classes like those that inherit from
        # Resque::JobWithStatus (resque-status)
        job_klass = job_config['custom_job_class']
        if job_klass && job_klass != 'Resque::Job'
          # The custom job class API must offer a static "scheduled" method. If
          # the custom job class can not be constantized (via a requeue call
          # from the web perhaps), fall back to enqueuing normally via
          # Resque::Job.create.
          begin
            Resque::Scheduler::Util.constantize(job_klass).scheduled(
              queue, klass_name, *params
            )
          rescue NameError
            # Note that the custom job class (job_config['custom_job_class'])
            # is the one enqueued
            Resque::Job.create(queue, job_klass, *params)
          end
        else
          # Hack to avoid havoc for people shoving stuff into queues
          # for non-existent classes (for example: running scheduler in
          # one app that schedules for another.
          if Class === klass
            Resque::Scheduler::Plugin.run_before_delayed_enqueue_hooks(
              klass, *params
            )

            # If the class is a custom job class, call self#scheduled on it.
            # This allows you to do things like Resque.enqueue_at(timestamp,
            # CustomJobClass). Otherwise, pass off to Resque.
            if klass.respond_to?(:scheduled)
              klass.scheduled(queue, klass_name, *params)
            else
              Resque.enqueue_to(queue, klass, *params)
            end
          else
            # This will not run the before_hooks in rescue, but will at least
            # queue the job.
            Resque::Job.create(queue, klass, *params)
          end
        end
      end

      def rufus_scheduler
        @rufus_scheduler ||= Rufus::Scheduler.new
      end

      # Stops old rufus scheduler and creates a new one.  Returns the new
      # rufus scheduler
      def clear_schedule!
        rufus_scheduler.stop
        @rufus_scheduler = nil
        @scheduled_jobs = {}
        rufus_scheduler
      end

      def reload_schedule!
        procline 'Reloading Schedule'
        clear_schedule!
        load_schedule!
      end

      def update_schedule
        if Resque.redis.scard(:schedules_changed) > 0
          procline 'Updating schedule'
          loop do
            schedule_name = Resque.redis.spop(:schedules_changed)
            break unless schedule_name
            Resque.reload_schedule!
            if Resque.schedule.keys.include?(schedule_name)
              unschedule_job(schedule_name)
              load_schedule_job(schedule_name, Resque.schedule[schedule_name])
            else
              unschedule_job(schedule_name)
            end
          end
          procline 'Schedules Loaded'
        end
      end

      def unschedule_job(name)
        if scheduled_jobs[name]
          log "Removing schedule #{name}"
          scheduled_jobs[name].unschedule
          @scheduled_jobs.delete(name)
        end
      end

      # Sleeps and returns true
      def poll_sleep
        handle_shutdown do
          begin
            poll_sleep_loop
          ensure
            @sleeping = false
          end
        end
        true
      end

      def poll_sleep_loop
        @sleeping = true
        if poll_sleep_amount > 0
          start = Time.now
          loop do
            elapsed_sleep = (Time.now - start)
            remaining_sleep = poll_sleep_amount - elapsed_sleep
            @do_break = false
            if remaining_sleep <= 0
              @do_break = true
            else
              @do_break = handle_signals_with_operation do
                sleep(remaining_sleep)
              end
            end
            break if @do_break
          end
        else
          handle_signals_with_operation
        end
      end

      def handle_signals_with_operation
        yield if block_given?
        handle_signals
        false
      rescue Interrupt
        before_shutdown if @shutdown
        true
      end

      def stop_rufus_scheduler
        rufus_scheduler.shutdown(:wait)
      end

      def before_shutdown
        stop_rufus_scheduler
        release_master_lock
      end

      # Sets the shutdown flag, clean schedules and exits if sleeping
      def shutdown
        return if @shutdown
        @shutdown = true
        log!('Shutting down')
        @th.raise Interrupt if @sleeping
      end

      def log!(msg)
        logger.info { msg }
      end

      def log_error(msg)
        logger.error { msg }
      end

      def log(msg)
        logger.debug { msg }
      end

      def procline(string)
        log! string
        argv0 = build_procline(string)
        log "Setting procline #{argv0.inspect}"
        $0 = argv0
      end

      def failure_handler
        @failure_handler ||= Resque::Scheduler::FailureHandler
      end

      def logger
        @logger ||= Resque::Scheduler::LoggerBuilder.new(
          quiet: quiet,
          verbose: verbose,
          log_dev: logfile,
          format: logformat
        ).build
      end

      private

      def enqueue_recurring(name, config)
        if am_master
          log! "queueing #{config['class']} (#{name})"
          enqueue(config)
          Resque.last_enqueued_at(name, Time.now.to_s)
        end
      end

      def app_str
        app_name ? "[#{app_name}]" : ''
      end

      def env_str
        env ? "[#{env}]" : ''
      end

      def build_procline(string)
        "#{internal_name}#{app_str}#{env_str}: #{string}"
      end

      def internal_name
        "resque-scheduler-#{Resque::Scheduler::VERSION}"
      end

      def am_master
        @am_master = master? unless defined?(@am_master)
        @am_master
      end
    end
  end
end
