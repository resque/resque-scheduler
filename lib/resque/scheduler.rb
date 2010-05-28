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

      # Schedule all jobs and continually look for delayed jobs (never returns)
      def run

        # trap signals
        register_signal_handlers

        # Load the schedule into rufus
        load_schedule!

        # Now start the scheduling part of the loop.
        loop do
          handle_delayed_items
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
        trap('QUIT') { shutdown } unless defined? JRUBY_VERSION
      end

      # Pulls the schedule from Resque.schedule and loads it into the
      # rufus scheduler instance
      def load_schedule!
        log! "Schedule empty! Set Resque.schedule" if Resque.schedule.empty?

        Resque.schedule.each do |name, config|
          # If rails_env is set in the config, enforce ENV['RAILS_ENV'] as
          # required for the jobs to be scheduled.  If rails_env is missing, the
          # job should be scheduled regardless of what ENV['RAILS_ENV'] is set
          # to.
          if config['rails_env'].nil? || rails_env_matches?(config)
            log! "Scheduling #{name} "
            if !config['cron'].nil? && config['cron'].length > 0
              rufus_scheduler.cron config['cron'] do
                log! "queuing #{config['class']} (#{name})"
                enqueue_from_config(config)
              end
            else
              log! "no cron found for #{config['class']} (#{name}) - skipping"
            end
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
              Job.create(queue, item['class'], *item['args'])
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
        Resque::Job.create(queue, klass_name, *params)
      end

      def rufus_scheduler
        @rufus_scheduler ||= Rufus::Scheduler.start_new
      end

      # Stops old rufus scheduler and creates a new one.  Returns the new
      # rufus scheduler
      def clear_schedule!
        rufus_scheduler.stop
        @rufus_scheduler = nil
        rufus_scheduler
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
