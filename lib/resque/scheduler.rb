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

        # trap signals
        register_signal_handlers

        # Load the schedule into rufus
        load_schedule!

        # Now start the scheduling part of the loop.
        loop do
          handle_delayed_items
          update_schedule if dynamic
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
          trap('USR1') { kill_child }
          trap('USR2') { reload_schedule! }
        rescue ArgumentError
          warn "Signals QUIT and USR1 and USR2 not supported."
        end
      end

      # Pulls the schedule from Resque.schedule and loads it into the
      # rufus scheduler instance
      def load_schedule!
        log! "Schedule empty! Set Resque.schedule" if Resque.schedule.empty?
        
        @@scheduled_jobs = {}
        
        Resque.schedule.each do |name, config|
          load_schedule_job(name, config)
        end
      end
      
      # Loads a job schedule into the Rufus::Scheduler and stores it in @@scheduled_jobs
      def load_schedule_job(name, config)
        # If rails_env is set in the config, enforce ENV['RAILS_ENV'] as
        # required for the jobs to be scheduled.  If rails_env is missing, the
        # job should be scheduled regardless of what ENV['RAILS_ENV'] is set
        # to.
        if config['rails_env'].nil? || rails_env_matches?(config)
          log! "Scheduling #{name} "
          if !config['cron'].nil? && config['cron'].length > 0
            begin
              @@scheduled_jobs[name] = rufus_scheduler.cron config['cron'] do
                log! "queuing #{config['class']} (#{name})"
                enqueue_from_config(config)
              end
            rescue Exception => e
              log! "#{e.class.name}: #{e.message}"
            end
          else
            log! "no cron found for #{config['class']} (#{name}) - skipping"
          end
        end
      end

      # Returns true if the given schedule config hash matches the current
      # ENV['RAILS_ENV']
      def rails_env_matches?(config)
        config['rails_env'] && ENV['RAILS_ENV'] && config['rails_env'].gsub(/\s/,'').split(',').include?(ENV['RAILS_ENV'])
      end

      # Handles queueing delayed items
      def handle_delayed_items
        item = nil
        begin
          if timestamp = Resque.next_delayed_timestamp
            enqueue_delayed_items_for_timestamp(timestamp)
          end
        # continue processing until there are no more ready timestamps
        end while !timestamp.nil?
      end
      
      # Enqueues all delayed jobs for a timestamp
      def enqueue_delayed_items_for_timestamp(timestamp)
        item = nil
        begin
          handle_shutdown do
            if item = Resque.next_item_for_timestamp(timestamp)
              log "queuing #{item['class']} [delayed]"
              queue = item['queue'] || Resque.queue_from_class(constantize(item['class']))
              # Support custom job classes like job with status
              if (job_klass = item['custom_job_class']) && (job_klass != 'Resque::Job')
                # custom job classes not supporting the same API calls must implement the #schedule method
                constantize(job_klass).scheduled(queue, item['class'], *item['args'])
              else
                Resque::Job.create(queue, item['class'], *item['args'])
              end
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
      def enqueue_from_config(config)
        args = config['args'] || config[:args]
        klass_name = config['class'] || config[:class]
        params = args.nil? ? [] : Array(args)
        queue = config['queue'] || config[:queue] || Resque.queue_from_class(constantize(klass_name))
        # Support custom job classes like job with status
        if (job_klass = config['custom_job_class']) && (job_klass != 'Resque::Job')
          # custom job classes not supporting the same API calls must implement the #schedule method
          constantize(job_klass).scheduled(queue, klass_name, *params)
        else
          Resque::Job.create(queue, klass_name, *params)
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
        log! "Reloading Schedule..."
        clear_schedule!
        Resque.reload_schedule!
        load_schedule!
      end
      
      def update_schedule
        schedule_from_redis = Resque.get_schedules
        if !schedule_from_redis.nil? && schedule_from_redis != Resque.schedule
          log "Updating schedule..."
          # unload schedules that no longer exist
          (Resque.schedule.keys - schedule_from_redis.keys).each do |name|
            unschedule_job(name)
          end
          
          # find changes and stop and reload or add new
          schedule_from_redis.each do |name, config|
            if (Resque.schedule[name].nil? || Resque.schedule[name].empty?) || (config != Resque.schedule[name])
              unschedule_job(name)
              load_schedule_job(name, config)
            end
          end
          
          # load new schedule into Resque.schedule
          Resque.schedule = schedule_from_redis
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

    end

  end

end
