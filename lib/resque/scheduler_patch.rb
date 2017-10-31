require_relative 'scheduler/delaying_extensions_old'
module Resque
  module SchedulerPatch
    def old_resque
      @@old ||= begin
        klass = Resque.dup
        klass.singleton_class.include(Resque::Scheduler::DelayingExtensionsOld)
        klass
      end
    end

    def handle_delayed_items(at_time = nil)
      super

      timestamp = old_resque.next_delayed_timestamp(at_time)
      if timestamp
        procline 'Processing Delayed Items'
        until timestamp.nil?
          enqueue_delayed_items_for_timestamp(timestamp)
          timestamp = old_resque.next_delayed_timestamp(at_time)
        end
      end
    end

    def enqueue_next_item(timestamp)
      item = old_resque.next_item_for_timestamp(timestamp)

      if item
        log "queuing #{item['class']} [delayed]"
        enqueue(item)
      end

      item
    end

    # Enqueues all delayed jobs for a timestamp
    def enqueue_delayed_items_for_timestamp(timestamp)
      item = nil
      loop do
        handle_shutdown do
          # Continually check that it is still the master
          item = enqueue_next_item(timestamp) if master?
        end
        # continue processing until there are no more ready items in this
        # timestamp
        break if item.nil?
      end
    end
  end
end

