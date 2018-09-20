# vim:fileencoding=utf-8
require 'resque'
require_relative 'plugin'
require_relative '../scheduler'

module Resque
  module Scheduler
    module DelayingExtensions
      DEFAULT_BATCH_SIZE = 100

      # This method is nearly identical to +enqueue+ only it also
      # takes a timestamp which will be used to schedule the job
      # for queueing.  Until timestamp is in the past, the job will
      # sit in the schedule list.
      def enqueue_at(timestamp, klass, *args)
        validate(klass)
        enqueue_at_with_queue(
          queue_from_class(klass), timestamp, klass, *args
        )
      end

      # Identical to +enqueue_at+, except you can also specify
      # a queue in which the job will be placed after the
      # timestamp has passed. It respects Resque.inline option, by
      # creating the job right away instead of adding to the queue.
      def enqueue_at_with_queue(queue, timestamp, klass, *args)
        return false unless plugin.run_before_schedule_hooks(klass, *args)

        if Resque.inline? || timestamp.to_i < Time.now.to_i
          # Just create the job and let resque perform it right away with
          # inline.  If the class is a custom job class, call self#scheduled
          # on it. This allows you to do things like
          # Resque.enqueue_at(timestamp, CustomJobClass, :opt1 => val1).
          # Otherwise, pass off to Resque.
          if klass.respond_to?(:scheduled)
            klass.scheduled(queue, klass.to_s, *args)
          else
            Resque::Job.create(queue, klass, *args)
          end
        else
          delayed_push(timestamp, job_to_hash_with_queue(queue, klass, args))
        end

        plugin.run_after_schedule_hooks(klass, *args)
      end

      # Identical to enqueue_at but takes number_of_seconds_from_now
      # instead of a timestamp.
      def enqueue_in(number_of_seconds_from_now, klass, *args)
        unless number_of_seconds_from_now.is_a?(Numeric)
          raise ArgumentError, 'Please supply a numeric number of seconds'
        end
        enqueue_at(Time.now + number_of_seconds_from_now, klass, *args)
      end

      # Identical to +enqueue_in+, except you can also specify
      # a queue in which the job will be placed after the
      # number of seconds has passed.
      def enqueue_in_with_queue(queue, number_of_seconds_from_now,
                                klass, *args)
        unless number_of_seconds_from_now.is_a?(Numeric)
          raise ArgumentError, 'Please supply a numeric number of seconds'
        end
        enqueue_at_with_queue(queue, Time.now + number_of_seconds_from_now,
                              klass, *args)
      end

      # Used internally to stuff the item into the schedule sorted list.
      # +timestamp+ can be either in seconds or a datetime object Insertion
      # if O(log(n)).  Returns true if it's the first job to be scheduled at
      # that time, else false
      def delayed_push(timestamp, item, should_encode_item = true)
        encoded_item = should_encode_item ? encode(item) : item
        delayed_key  = delayed_key(timestamp.to_i)

        # First add this item to the list for this timestamp
        redis.rpush(delayed_key, encoded_item)

        # Store the timestamps at with this item occurs
        redis.sadd(timestamp_key(encoded_item), delayed_key)

        # Now, add this timestamp to the zsets.  The score and the value are
        # the same since we'll be querying by timestamp, and we don't have
        # anything else to store.
        redis.zadd :delayed_queue_schedule, timestamp.to_i, timestamp.to_i
      end

      # Returns an array of timestamps based on start and count
      def delayed_queue_peek(start, count)
        result = redis.zrange(:delayed_queue_schedule, start,
                              start + count - 1)
        Array(result).map(&:to_i)
      end

      # Returns the size of the delayed queue schedule
      def delayed_queue_schedule_size
        redis.zcard :delayed_queue_schedule
      end

      # Returns the number of jobs for a given timestamp in the delayed queue
      # schedule
      def delayed_timestamp_size(timestamp)
        redis.llen(delayed_key(timestamp.to_i)).to_i
      end

      # Returns an array of delayed items for the given timestamp
      def delayed_timestamp_peek(timestamp, start, count)
        delayed_key = delayed_key(timestamp.to_i)
        if 1 == count
          r = list_range delayed_key, start, count
          r.nil? ? [] : [r]
        else
          list_range delayed_key, start, count
        end
      end

      # Returns the next delayed queue timestamp
      # (don't call directly)
      def next_delayed_timestamp(at_time = nil)
        search_first_delayed_timestamp_in_range(nil, at_time || Time.now)
      end

      # Returns the next item to be processed for a given timestamp, nil if
      # done. (don't call directly)
      # +timestamp+ can either be in seconds or a datetime
      def next_item_for_timestamp(timestamp)
        key = delayed_key(timestamp.to_i)

        encoded_item = redis.lpop(key)
        redis.srem(timestamp_key(encoded_item), key)
        item = decode(encoded_item)

        # If the list is empty, remove it.
        clean_up_timestamp(key, timestamp)
        item
      end

      # Clears all jobs created with enqueue_at or enqueue_in
      def reset_delayed_queue
        Array(redis.zrange(:delayed_queue_schedule, 0, -1)).each do |item|
          key = delayed_key(item)
          items = redis.lrange(key, 0, -1)
          redis.pipelined do
            items.each { |ts_item| redis.del(timestamp_key(ts_item)) }
          end
          redis.del key
        end

        redis.del :delayed_queue_schedule
      end

      # Given an encoded item, remove it from the delayed_queue
      def remove_delayed(klass, *args)
        search = encode(job_to_hash(klass, args))
        remove_delayed_job(search)
      end

      # Given an encoded item, enqueue it now
      def enqueue_delayed(klass, *args)
        hash = job_to_hash(klass, args)
        remove_delayed(klass, *args).times do
          Resque::Scheduler.enqueue_from_config(hash)
        end
      end

      # Given a block, remove jobs that return true from a block.
      #
      # This allows for removal of delayed jobs that have arguments matching
      # certain criteria.
      #
      # Give you only the arguments passed to the jobs at its creation:
      #
      #   For example, with the following job:
      #
      #     Resque.enqueue_at(
      #       5.days.from_now,
      #       SendFollowUpEmail,
      #       :account_id => 0,
      #       :user_id => 1
      #     )
      #
      #   It gives you this as parameter for your block:
      #
      #     [{"account_id": 0, "user_id": 1}]
      #
      def remove_delayed_selection(klass = nil, &block)
        raise ArgumentError, 'Please supply a block' unless block_given?

        remove_delayed_selection_with_batch_size(DEFAULT_BATCH_SIZE, klass, &block)
      end

      # Given a block, remove jobs that return true from a block.
      #
      # This allows for removal of delayed jobs that have arguments matching
      # certain criteria.
      #
      # Give you only the arguments passed to the jobs at its creation:
      #
      #   For example, with the following job:
      #
      #     Resque.enqueue_at(
      #       5.days.from_now,
      #       SendFollowUpEmail,
      #       :account_id => 0,
      #       :user_id => 1
      #     )
      #
      #   It gives you this as parameter for your block:
      #
      #     [{"account_id": 0, "user_id": 1}]
      #
      def remove_delayed_selection_with_batch_size(batch_size, klass = nil, &block)
        raise ArgumentError, 'Please supply a block' unless block_given?

        do_remove_delayed_selection(
          find_delayed_selection_with_batch_size(batch_size, klass) do |payload|
            block.call(payload['args'])
          end
        )
      end

      # Given a block, remove jobs that return true from a block.
      #
      # This allows for removal of delayed jobs matching certain criteria.
      #
      # Give you all the infos of the job.
      #
      #   For example, with the following job:
      #
      #     Resque.enqueue_at(
      #       5.days.from_now,
      #       SendFollowUpEmail,
      #       :account_id => 0,
      #       :user_id => 1
      #     )
      #
      #   It gives you this as parameter for your block:
      #
      #     {
      #       "class": "SendFollowUpEmail",
      #       "args": [{"account_id": 0, "user_id": 1}],
      #       "queue": "queue_name"
      #     }
      #
      # Useful if, in your passed block, you want to match by
      # class and/or queue (not only args) !
      #
      # For example:
      #
      #   Resque.remove_delayed_selection_with_all_job_infos { |job|
      #     [SendFollowUpEmail, SendFollowUpSms].any? { |klass|
      #       klass.to_s == job["class"]
      #     } && job["args"][0]['account_id'] == current_account.id]
      #   }
      #
      def remove_delayed_selection_with_all_job_infos(&block)
        raise ArgumentError, 'Please supply a block' unless block_given?

        remove_delayed_selection_with_all_job_infos_with_batch_size(DEFAULT_BATCH_SIZE, &block)
      end

      # Given a block, remove jobs that return true from a block.
      #
      # This allows for removal of delayed jobs matching certain criteria.
      #
      # Give you all the infos of the job.
      #
      #   For example, with the following job:
      #
      #     Resque.enqueue_at(
      #       5.days.from_now,
      #       SendFollowUpEmail,
      #       :account_id => 0,
      #       :user_id => 1
      #     )
      #
      #   It gives you this as parameter for your block:
      #
      #     {
      #       "class": "SendFollowUpEmail",
      #       "args": [{"account_id": 0, "user_id": 1}],
      #       "queue": "queue_name"
      #     }
      #
      # Useful if, in your passed block, you want to match by
      # class and/or queue (not only args) !
      #
      # For example:
      #
      #   Resque.remove_delayed_selection_with_all_job_infos(1000) { |job|
      #     [SendFollowUpEmail, SendFollowUpSms].any? { |klass|
      #       klass.to_s == job["class"]
      #     } && job["args"][0]['account_id'] == current_account.id]
      #   }
      #
      def remove_delayed_selection_with_all_job_infos_with_batch_size(batch_size, &block)
        raise ArgumentError, 'Please supply a block' unless block_given?

        do_remove_delayed_selection(find_delayed_selection_with_batch_size(batch_size, &block))
      end

      # Given a block, change the execution date of jobs that return true from a block.
      #
      # Same signature that the #remove_delayed_selection_with_all_job_infos method.
      #
      def change_delayed_selection_timestamp(timestamp, &block)
        raise ArgumentError, 'Please supply a block' unless block_given?

        change_delayed_selection_timestamp_with_batch_size(DEFAULT_BATCH_SIZE, timestamp, &block)
      end

      # Given a block, change the execution date of jobs that return true from a block.
      #
      # Same signature that the #remove_delayed_selection_with_all_job_infos method.
      #
      def change_delayed_selection_timestamp_with_batch_size(batch_size, timestamp, &block)
        raise ArgumentError, 'Please supply a block' unless block_given?

        found_jobs = find_delayed_selection_with_batch_size(batch_size, &block)
        count = do_remove_delayed_selection(found_jobs)
        found_jobs.each { |encoded_job| delayed_push(timestamp, encoded_job, false) }
        count
      end

      # Given a block, enqueue jobs now that return true from a block.
      #
      # This allows for enqueuing of delayed jobs that have arguments matching
      # certain criteria.
      #
      def enqueue_delayed_selection(klass = nil, &block)
        raise ArgumentError, 'Please supply a block' unless block_given?

        enqueue_delayed_selection_with_batch_size(DEFAULT_BATCH_SIZE, klass, &block)
      end

      # Given a block, enqueue jobs now that return true from a block.
      #
      # This allows for enqueuing of delayed jobs that have arguments matching
      # certain criteria.
      #
      def enqueue_delayed_selection_with_batch_size(batch_size, klass = nil, &block)
        raise ArgumentError, 'Please supply a block' unless block_given?

        found_jobs = find_delayed_selection_with_batch_size(batch_size, klass) do |payload|
          block.call(payload['args'])
        end
        found_jobs.reduce(0) do |sum, encoded_job|
          decoded_job = decode(encoded_job)
          klass = Util.constantize(decoded_job['class'])
          sum + enqueue_delayed(klass, *decoded_job['args'])
        end
      end

      # Given a block, find jobs that return true from a block.
      #
      # This allows for finding of delayed jobs that have arguments matching
      # certain criteria.
      #
      def find_delayed_selection(klass = nil, &block)
        raise ArgumentError, 'Please supply a block' unless block_given?

        find_delayed_selection_with_batch_size(DEFAULT_BATCH_SIZE, klass, &block)
      end

      # Given a block, find jobs that return true from a block.
      #
      # This allows for finding of delayed jobs that have arguments matching
      # certain criteria.
      #
      def find_delayed_selection_with_batch_size(batch_size, klass = nil, &block)
        raise ArgumentError, 'Please supply a block' unless block_given?

        timestamps = redis.zrange(:delayed_queue_schedule, 0, -1)
        is_klass_nil = klass.nil?
        klass_s = klass.to_s
        klass_key = 'class'

        # Beyond 100 there's almost no improvement in speed
        found = timestamps.each_slice(batch_size).map do |timestamps_group|
          jobs = redis.pipelined do |r|
            timestamps_group.map do |timestamp|
              r.lrange(delayed_key(timestamp), 0, -1)
            end
          end

          jobs.flatten.select do |payload|
            decoded_payload = decode(payload)
            !decoded_payload.nil? &&
              (is_klass_nil || klass_s == decoded_payload[klass_key]) &&
              block.call(decoded_payload)
          end
        end

        found.flatten
      end

      # Given a timestamp and job (klass + args) it removes all instances and
      # returns the count of jobs removed.
      #
      # O(N) where N is the number of jobs scheduled to fire at the given
      # timestamp
      def remove_delayed_job_from_timestamp(timestamp, klass, *args)
        return 0 if Resque.inline?

        key = delayed_key(timestamp.to_i)
        encoded_job = encode(job_to_hash(klass, args))

        redis.srem(timestamp_key(encoded_job), key)
        count = redis.lrem(key, 0, encoded_job)
        clean_up_timestamp(key, timestamp)

        count
      end

      def count_all_scheduled_jobs
        total_jobs = 0
        Array(redis.zrange(:delayed_queue_schedule, 0, -1)).each do |timestamp|
          total_jobs += redis.llen(delayed_key(timestamp)).to_i
        end
        total_jobs
      end

      # Discover if a job has been delayed.
      # Examples
      #   Resque.delayed?(MyJob)
      #   Resque.delayed?(MyJob, id: 1)
      # Returns true if the job has been delayed
      def delayed?(klass, *args)
        !scheduled_at(klass, *args).empty?
      end

      # Returns delayed jobs schedule timestamp for +klass+, +args+.
      def scheduled_at(klass, *args)
        search = encode(job_to_hash(klass, args))
        redis.smembers(timestamp_key(search)).map do |key|
          key.tr('delayed:', '').to_i
        end
      end

      def last_enqueued_at(job_name, date)
        redis.hset('delayed:last_enqueued_at', job_name, date)
      end

      def get_last_enqueued_at(job_name)
        redis.hget('delayed:last_enqueued_at', job_name)
      end

      private

      def job_to_hash(klass, args)
        { class: klass.to_s, args: args, queue: queue_from_class(klass) }
      end

      def job_to_hash_with_queue(queue, klass, args)
        { class: klass.to_s, args: args, queue: queue }
      end

      def remove_delayed_job(encoded_job)
        return 0 if Resque.inline?

        timestamp_key = timestamp_key(encoded_job)
        timestamps = redis.smembers(timestamp_key)

        replies = redis.pipelined do
          timestamps.each do |key|
            redis.lrem(key, 0, encoded_job)
            redis.srem(timestamp_key, key)
          end
        end

        return 0 if replies.nil? || replies.empty?
        replies.each_slice(2).map(&:first).inject(:+)
      end

      def clean_up_timestamp(key, timestamp)
        # Use a watch here to ensure nobody adds jobs to this delayed
        # queue while we're removing it.
        redis.watch(key) do
          if redis.llen(key).to_i == 0
            # If the list is empty, remove it.
            redis.multi do
              redis.del(key)
              redis.zrem(:delayed_queue_schedule, timestamp.to_i)
            end
          else
            redis.redis.unwatch
          end
        end
      end

      def search_first_delayed_timestamp_in_range(start_at, stop_at)
        start_at = start_at.nil? ? '-inf' : start_at.to_i
        stop_at = stop_at.nil? ? '+inf' : stop_at.to_i

        items = redis.zrangebyscore(
          :delayed_queue_schedule, start_at, stop_at,
          limit: [0, 1]
        )
        timestamp = items.nil? ? nil : Array(items).first
        timestamp.to_i unless timestamp.nil?
      end

      def plugin
        Resque::Scheduler::Plugin
      end

      def do_remove_delayed_selection(found_jobs)
        found_jobs.reduce(0) do |sum, encoded_job|
          sum + remove_delayed_job(encoded_job)
        end
      end

      def delayed_key(timestamp)
        "delayed:#{timestamp}"
      end

      def timestamp_key(object)
        "timestamps:#{object}"
      end
    end
  end
end
