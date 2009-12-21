require 'rufus-scheduler'
require 'rufus/scheduler'
require 'thwait'
require 'resque'

module Resque

  class Scheduler

    extend Resque::Helpers

    class << self

      # Schedule all jobs and sleep (never returns)
      def run(wait = true)
        puts "Schedule empty! Set Resque.schedule" if Resque.schedule.empty?

        Resque.schedule.values.each do |config|
          rufus_scheduler.cron config['cron'] do
            enqueue_from_config(config)
          end
        end
        # sleep baby, sleep
        ThreadsWait.all_waits(rufus_scheduler.instance_variable_get("@thread")) if wait
      end

      def enqueue_from_config(config)
        params = config['args'].nil? ? [] : Array(config['args'])
        Resque.enqueue(constantize(config['class']), *params)
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

    end

  end

end