require 'rufus/scheduler'
require 'resque/scheduler_locking'
require 'resque_scheduler/logger_builder'

module Resque
  class Scheduler
    extend Resque::SchedulerLocking

    class << self
      # Allows for block-style configuration
      def configure
        yield self
      end

      attr_writer :signal_queue

      def signal_queue
        @signal_queue ||= []
      end

      # Used in `#load_schedule_job`
      attr_writer :env

      def env
        return @env if @env
        @env ||= Rails.env if defined?(Rails)
        @env ||= ENV['RAILS_ENV']
        @env
      end

      # If true, logs more stuff...
      attr_writer :verbose

      def verbose
        @verbose ||= !!ENV['VERBOSE']
      end

      # If set, produces no output
      attr_writer :mute

      def mute
        @mute ||= !!ENV['MUTE']
      end

      # If set, will write messages to the file
      attr_writer :logfile

      def logfile
        @logfile ||= ENV['LOGFILE']
      end

      # Sets whether to log in 'text' or 'json'
      attr_writer :logformat

      def logformat
        @logformat ||= ENV['LOGFORMAT']
      end

      # If set, will try to update the schedule in the loop
      attr_writer :dynamic

      def dynamic
        @dynamic ||= !!ENV['DYNAMIC_SCHEDULE']
      end

      # If set, will append the app name to procline
      attr_writer :app_name

      def app_name
        @app_name ||= ENV['APP_NAME']
      end

      # Amount of time in seconds to sleep between polls of the delayed
      # queue.  Defaults to 5
      attr_writer :poll_sleep_amount

      def poll_sleep_amount
        @poll_sleep_amount ||=
          Float(ENV.fetch('RESQUE_SCHEDULER_INTERVAL', '5'))
      end

      attr_writer :logger

      def logger
        @logger ||= ResqueScheduler::LoggerBuilder.new(
          :mute => mute,
          :verbose => verbose,
          :log_dev => logfile,
          :format => logformat
        ).build
      end

      # the Rufus::Scheduler jobs that are scheduled
      def scheduled_jobs
        @@scheduled_jobs
      end

      # Schedule all jobs and continually look for delayed jobs (never returns)
      def run
        $0 = "resque-scheduler: Starting"

        # trap signals
        register_signal_handlers

        # Quote from the resque/worker.
        # Fix buffering so we can `rake resque:scheduler > scheduler.log` and
        # get output from the child in there.
        $stdout.sync = true
        $stderr.sync = true

        # Load the schedule into rufus
        # If dynamic is set, load that schedule otherwise use normal load
        if dynamic
          reload_schedule!
        else
          load_schedule!
        end

        begin
          @th = Thread.current

          # Now start the scheduling part of the loop.
          loop do
            if is_master?
              begin
                handle_delayed_items
                update_schedule if dynamic
              rescue Errno::EAGAIN, Errno::ECONNRESET => e
                log! e.message
              end
            end
            handle_signals
            poll_sleep
          end

        rescue Interrupt
          log 'Exiting'
        end
      end

      # For all signals, set the shutdown flag and wait for current
      # poll/enqueing to finish (should be almost instant).  In the
      # case of sleeping, exit immediately.
      def register_signal_handlers
        %w(INT TERM USR1 USR2 QUIT).each do |sig|
          trap(sig) { signal_queue << sig }
        end
      end

      def handle_signals
        loop do
          sig = signal_queue.shift
          break unless sig
          log! "Got #{sig} signal"
          case sig
          when 'INT', 'TERM', 'QUIT' then shutdown
          when 'USR1' then print_schedule
          when 'USR2' then reload_schedule!
          end
        end
      end

      def print_schedule
        if rufus_scheduler
          log! "Scheduling Info\tLast Run"
          scheduler_jobs = rufus_scheduler.all_jobs
          scheduler_jobs.each do |k, v|
            log! "#{v.t}\t#{v.last}\t"
          end
        end
      end

      # Pulls the schedule from Resque.schedule and loads it into the
      # rufus scheduler instance
      def load_schedule!
        procline "Loading Schedule"

        # Need to load the schedule from redis for the first time if dynamic
        Resque.reload_schedule! if dynamic

        log! "Schedule empty! Set Resque.schedule" if Resque.schedule.empty?

        @@scheduled_jobs = {}

        Resque.schedule.each do |name, config|
          load_schedule_job(name, config)
        end
        Resque.redis.del(:schedules_changed)
        procline "Schedules Loaded"
      end

      # modify interval type value to value with options if options available
      def optionizate_interval_value(value)
        args = value
        if args.is_a?(::Array)
          return args.first if args.size > 2 || !args.last.is_a?(::Hash)
          # symbolize keys of hash for options
          args[1] = args[1].inject({}) do |m, i|
            key, value = i
            m[(key.to_sym rescue key) || key] = value
            m
          end
        end
        args
      end

      # Loads a job schedule into the Rufus::Scheduler and stores it in
      # @@scheduled_jobs
      def load_schedule_job(name, config)
        # If `rails_env` or `env` is set in the config, load jobs only if they
        # are meant to be loaded in `Resque::Scheduler.env`.  If `rails_env` or
        # `env` is missing, the job should be scheduled regardless of the value
        # of `Resque::Scheduler.env`.

        configured_env = config['rails_env'] || config['env']

        if configured_env.nil? || env_matches?(configured_env)
          log! "Scheduling #{name} "
          interval_defined = false
          interval_types = %w{cron every}
          interval_types.each do |interval_type|
            if !config[interval_type].nil? && config[interval_type].length > 0
              args = optionizate_interval_value(config[interval_type])
              @@scheduled_jobs[name] = rufus_scheduler.send(interval_type, *args) do
                if is_master?
                  log! "queueing #{config['class']} (#{name})"
                  handle_errors { enqueue_from_config(config) }
                end
              end
              interval_defined = true
              break
            end
          end
          unless interval_defined
            log! "no #{interval_types.join(' / ')} found for #{config['class']} (#{name}) - skipping"
          end
        else
          log "Skipping schedule of #{name} because configured " <<
              "env #{configured_env.inspect} does not match current " <<
              "env #{env.inspect}"
        end
      end

      # Returns true if the given schedule config hash matches the current env
      def rails_env_matches?(config)
        warn '`Resque::Scheduler.rails_env_matches?` is deprecated. ' <<
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
      def handle_delayed_items(at_time=nil)
        if timestamp = Resque.next_delayed_timestamp(at_time)
          procline "Processing Delayed Items"
          while !timestamp.nil?
            enqueue_delayed_items_for_timestamp(timestamp)
            timestamp = Resque.next_delayed_timestamp(at_time)
          end
        end
      end

      # Enqueues all delayed jobs for a timestamp
      def enqueue_delayed_items_for_timestamp(timestamp)
        item = nil
        begin
          handle_shutdown do
            # Continually check that it is still the master
            if is_master? && item = Resque.next_item_for_timestamp(timestamp)
              log "queuing #{item['class']} [delayed]"
              handle_errors { enqueue_from_config(item) }
            end
          end
        # continue processing until there are no more ready items in this timestamp
        end while !item.nil?
      end

      def handle_shutdown
        exit if @shutdown
        yield
        exit if @shutdown
      end

      def handle_errors
        begin
          yield
        rescue Exception => e
          log_error "#{e.class.name}: #{e.message}"
        end
      end

      # Enqueues a job based on a config hash
      def enqueue_from_config(job_config)
        args = job_config['args'] || job_config[:args]

        klass_name = job_config['class'] || job_config[:class]
        klass = ResqueScheduler::Util.constantize(klass_name) rescue klass_name

        params = args.is_a?(Hash) ? [args] : Array(args)
        queue = job_config['queue'] || job_config[:queue] || Resque.queue_from_class(klass)
        # Support custom job classes like those that inherit from Resque::JobWithStatus (resque-status)
        if (job_klass = job_config['custom_job_class']) && (job_klass != 'Resque::Job')
          # The custom job class API must offer a static "scheduled" method. If the custom
          # job class can not be constantized (via a requeue call from the web perhaps), fall
          # back to enqueing normally via Resque::Job.create.
          begin
            ResqueScheduler::Util.constantize(job_klass).scheduled(queue, klass_name, *params)
          rescue NameError
            # Note that the custom job class (job_config['custom_job_class']) is the one enqueued
            Resque::Job.create(queue, job_klass, *params)
          end
        else
          # hack to avoid havoc for people shoving stuff into queues
          # for non-existent classes (for example: running scheduler in
          # one app that schedules for another
          if Class === klass
            ResqueScheduler::Plugin.run_before_delayed_enqueue_hooks(klass, *params)

            # If the class is a custom job class, call self#scheduled on it. This allows you to do things like
            # Resque.enqueue_at(timestamp, CustomJobClass). Otherwise, pass off to Resque.
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
        @rufus_scheduler ||= Rufus::Scheduler.start_new
      end

      # Stops old rufus scheduler and creates a new one.  Returns the new
      # rufus scheduler
      def clear_schedule!
        rufus_scheduler.stop
        @rufus_scheduler = nil
        @@scheduled_jobs = {}
        rufus_scheduler
      end

      def reload_schedule!
        procline "Reloading Schedule"
        clear_schedule!
        load_schedule!
      end

      def update_schedule
        if Resque.redis.scard(:schedules_changed) > 0
          procline "Updating schedule"
          Resque.reload_schedule!
          while schedule_name = Resque.redis.spop(:schedules_changed)
            if Resque.schedule.keys.include?(schedule_name)
              unschedule_job(schedule_name)
              load_schedule_job(schedule_name, Resque.schedule[schedule_name])
            else
              unschedule_job(schedule_name)
            end
          end
          procline "Schedules Loaded"
        end
      end

      def unschedule_job(name)
        if scheduled_jobs[name]
          log "Removing schedule #{name}"
          scheduled_jobs[name].unschedule
          @@scheduled_jobs.delete(name)
        end
      end

      # Sleeps and returns true
      def poll_sleep
        handle_shutdown do
          begin
            begin
              @sleeping = true
              sleep poll_sleep_amount
              @sleeping = false
            rescue Interrupt
              if @shutdown
                Resque.clean_schedules
                release_master_lock!
              end
            end
          ensure
            @sleeping = false
          end
        end
        true
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

      private

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
        "resque-scheduler-#{ResqueScheduler::VERSION}"
      end
    end
  end
end
