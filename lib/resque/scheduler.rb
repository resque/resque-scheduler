require 'rufus/scheduler'
require 'thwait'

module Resque

  class Scheduler

    extend Resque::Helpers

    class << self

      # If true, logs more stuff...
      attr_accessor :verbose

      # If set, produces no output
      attr_accessor :mute

      # If set, will try to update the schulde in the loop
      attr_accessor :dynamic

      # the Rufus::Scheduler jobs that are scheduled
      def scheduled_jobs
        @@scheduled_jobs
      end

      # Schedule all jobs and continually look for delayed jobs (never returns)
      def run
        $0 = "resque-scheduler: Starting"
        # trap signals
        register_signal_handlers

        # Load the schedule into rufus
        # If dynamic is set, load that schedule otherwise use normal load
        if dynamic
          reload_schedule!
        else
          load_schedule!
        end

        # Now start the scheduling part of the loop.
        loop do
          begin
            handle_delayed_items
            update_schedule if dynamic
          rescue Errno::EAGAIN, Errno::ECONNRESET => e
            warn e.message
          end
          poll_sleep
        end

        # never gets here.
      end

      # For all signals, set the shutdown flag and wait for current
      # poll/enqueing to finish (should be almost istant).  In the
      # case of sleeping, exit immediately.
      def register_signal_handlers
        trap("TERM") { shutdown }
        trap("INT") { shutdown }

        begin
          trap('QUIT') { shutdown   }
          trap('USR1') { print_schedule }
          trap('USR2') { reload_schedule! }
        rescue ArgumentError
          warn "Signals QUIT and USR1 and USR2 not supported."
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

      # Loads a job schedule into the Rufus::Scheduler and stores it in @@scheduled_jobs
      def load_schedule_job(name, config)
        # If rails_env is set in the config, enforce ENV['RAILS_ENV'] as
        # required for the jobs to be scheduled.  If rails_env is missing, the
        # job should be scheduled regardless of what ENV['RAILS_ENV'] is set
        # to.
        if config['rails_env'].nil? || rails_env_matches?(config)
          log! "Scheduling #{name} "
          interval_defined = false
          interval_types = %w{cron every}
          interval_types.each do |interval_type|
            if !config[interval_type].nil? && config[interval_type].length > 0
              begin
                @@scheduled_jobs[name] = rufus_scheduler.send(interval_type, config[interval_type]) do
                  log! "queueing #{config['class']} (#{name})"
                  enqueue_from_config(config)
                end
              rescue Exception => e
                log! "#{e.class.name}: #{e.message}"
              end
              interval_defined = true
              break
            end
          end
          unless interval_defined
            log! "no #{interval_types.join(' / ')} found for #{config['class']} (#{name}) - skipping"
          end
        end
      end

      # Returns true if the given schedule config hash matches the current
      # ENV['RAILS_ENV']
      def rails_env_matches?(config)
        config['rails_env'] && ENV['RAILS_ENV'] && config['rails_env'].gsub(/\s/,'').split(',').include?(ENV['RAILS_ENV'])
      end

      # Handles queueing delayed items
      # at_time - Time to start scheduling items (default: now).
      def handle_delayed_items(at_time=nil)
        item = nil
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
            if item = Resque.next_item_for_timestamp(timestamp)
              log "queuing #{item['class']} [delayed]"
              enqueue_from_config(item)
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

      # Enqueues a job based on a config hash
      def enqueue_from_config(job_config)
        args = job_config['args'] || job_config[:args]

        klass_name = job_config['class'] || job_config[:class]
        klass = constantize(klass_name) rescue klass_name

        params = args.is_a?(Hash) ? [args] : Array(args)
        queue = job_config['queue'] || job_config[:queue] || Resque.queue_from_class(klass)
        # Support custom job classes like those that inherit from Resque::JobWithStatus (resque-status)
        if (job_klass = job_config['custom_job_class']) && (job_klass != 'Resque::Job')
          # The custom job class API must offer a static "scheduled" method. If the custom
          # job class can not be constantized (via a requeue call from the web perhaps), fall
          # back to enqueing normally via Resque::Job.create.
          begin
            constantize(job_klass).scheduled(queue, klass_name, *params)
          rescue NameError
            # Note that the custom job class (job_config['custom_job_class']) is the one enqueued
            Resque::Job.create(queue, job_klass, *params)
          end
        else
          # hack to avoid havoc for people shoving stuff into queues
          # for non-existent classes (for example: running scheduler in
          # one app that schedules for another
          if Class === klass
            Resque.enqueue(klass, *params)
          else
            Resque::Job.create(queue, klass, *params)
          end
        end
      rescue
        log! "Failed to enqueue #{klass_name}:\n #{$!}"
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
        @sleeping = true
        handle_shutdown { sleep 5 }
        @sleeping = false
        true
      end

      # Sets the shutdown flag, exits if sleeping
      def shutdown
        @shutdown = true
        exit if @sleeping
      end

      def log!(msg)
        puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} #{msg}" unless mute
      end

      def log(msg)
        # add "verbose" logic later
        log!(msg) if verbose
      end

      def procline(string)
        log! string
        $0 = "resque-scheduler-#{ResqueScheduler::Version}: #{string}"
      end

    end

  end

end
