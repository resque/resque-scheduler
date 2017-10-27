require_relative 'scheduler/delaying_extensions_old'

module Resque
  module SchedulerMigrator
    extend self
    def old_resque
      @@old ||= begin
        klass = Resque.dup
        klass.singleton_class.include(Resque::Scheduler::DelayingExtensionsOld)
        klass
      end
    end

    def migrate
      timestamp = old_resque.send(:search_first_delayed_timestamp_in_range, nil, nil)

      if timestamp
        Resque::Scheduler.procline 'Migrating Delayed Items (Old Format)'
        until timestamp.nil?
          enqueue_delayed_items_for_timestamp(timestamp)
          timestamp = old_resque.send(:search_first_delayed_timestamp_in_range, nil, nil)
        end
      end
    end

    def enqueue_next_item(timestamp)
      item = old_resque.next_item_for_timestamp(timestamp)

      if item
        Resque::Scheduler.log "migrating #{item['class']} [delayed] from old format to new format"
        Resque.send(:delayed_push, timestamp, item)
      end

      item
    end

    # Enqueues all delayed jobs for a timestamp
    def enqueue_delayed_items_for_timestamp(timestamp)
      item = nil
      loop do
        Resque::Scheduler.handle_shutdown do
          # Continually check that it is still the master
          item = enqueue_next_item(timestamp)
        end
        # continue processing until there are no more ready items in this
        # timestamp
        break if item.nil?
      end
    end
  end
end
