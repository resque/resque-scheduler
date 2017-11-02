require_relative 'scheduler/delaying_extensions_old'

# This module provides functionality to abort a migration to the new scheduler format
# it will copy jobs from the new format to the old one

module Resque
  module SchedulerRevertMigrator
    extend self

    def old_resque
      @@old ||= begin
        klass = Resque.dup
        klass.singleton_class.include(Resque::Scheduler::DelayingExtensionsOld)
        klass
      end
    end

    def revert_migrate
      Resque::Scheduler.procline 'Reverting Delayed Items to Old Format'
      item = nil

      # The new scheduler performs a peek to read the job before processing it.
      # Therefore, we must interrupt it's processing first
      Resque.redis.rename :delayed_queue, :delayed_queue_recovery

      loop do
        Resque::Scheduler.handle_shutdown do
          item, timestamp = next_delayed_item

          if item
            Resque::Scheduler.log "queuing #{item['class']} [delayed]"
            old_resque.delayed_push(timestamp, item)
          end
        end

        break if item.nil?
      end
    end

    def next_delayed_item
      item, time = Resque.redis.zrangebyscore(:delayed_queue_recovery, 0.0, '+inf', limit: [0, 1], with_scores: true).first

      if item
        decoded = Resque.send(:decode_without_nonce, item)

        Resque.redis.zrem(:delayed_queue_recovery, item)
        Resque.redis.srem("timestamps:#{Resque.encode(decoded)}", "delayed:#{time.to_i}")

        [decoded, time]
      end
    end
  end
end
