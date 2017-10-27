# vim:fileencoding=utf-8
require 'resque'
require_relative 'plugin'
require_relative '../scheduler'

module Resque
  module Scheduler
    module DelayingExtensions
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
        enqueue_at(Time.now + number_of_seconds_from_now, klass, *args)
      end

      # Identical to +enqueue_in+, except you can also specify
      # a queue in which the job will be placed after the
      # number of seconds has passed.
      def enqueue_in_with_queue(queue, number_of_seconds_from_now,
                                klass, *args)
        enqueue_at_with_queue(queue, Time.now + number_of_seconds_from_now,
                              klass, *args)
      end

      # Returns an array of timestamps based on start and count
      def delayed_queue_peek(start, count)
        result = redis.zrange(:delayed_queue, start, count, withscores: true)
        result.map(&:last).map(&:to_i)
      end

      # Returns the size of the delayed queue schedule
      def delayed_queue_schedule_size
        redis.zcard(:delayed_queue)
      end

      def next_delayed_item(before:)
        item, time = redis.zrangebyscore(:delayed_queue, 0.0, before.to_i, limit: [0, 1], with_scores: true).first

        if item
          redis.zrem(:delayed_queue, item)
          decode_without_nonce(item)
        end
      end

      # Clears all jobs created with enqueue_at or enqueue_in
      def reset_delayed_queue
        redis.del :delayed_queue
      end

      # Given a block, remove jobs that return true from a block
      #
      # This allows for removal of delayed jobs that have arguments matching
      # certain criteria
      def remove_delayed_selection(klass = nil)
        raise ArgumentError, 'Please supply a block' unless block_given?

        found_jobs = find_delayed_selection(klass) { |args| yield(args) }
        found_jobs.reduce(0) do |sum, encoded_job|
          sum + remove_delayed_job(encoded_job)
        end
      end

      # Given a block, enqueue jobs now that return true from a block
      #
      # This allows for enqueuing of delayed jobs that have arguments matching
      # certain criteria
      def enqueue_delayed_selection(klass = nil)
        raise ArgumentError, 'Please supply a block' unless block_given?

        found_jobs = find_delayed_selection(klass) { |args| yield(args) }
        found_jobs.reduce(0) do |sum, encoded_job|
          sum + enqueue_delayed(encoded_job)
        end
      end

      # Given a block, find jobs that return true from a block
      #
      # This allows for finding of delayed jobs that have arguments matching
      # certain criteria
      def find_delayed_selection(klass = nil, &block)
        raise ArgumentError, 'Please supply a block' unless block_given?

        found = []

        redis.zscan_each(:delayed_queue) do |payload, _|
          if payload_matches_selection?(decode(payload), klass, &block)
            found << payload
          end
        end
        found
      end

      def last_enqueued_at(job_name, date)
        redis.hset('delayed:last_enqueued_at', job_name, date)
      end

      def get_last_enqueued_at(job_name)
        redis.hget('delayed:last_enqueued_at', job_name)
      end

      private

      def enqueue_delayed(blob)
        count = redis.zrem(:delayed_queue, [blob])
        count.times do
          Resque::Scheduler.enqueue_from_config(decode_without_nonce(blob))
        end
        count
      end

      # Used internally to stuff the item into the schedule sorted list.
      # +timestamp+ can be either in seconds or a datetime object Insertion
      # if O(log(n)).  Returns true if it's the first job to be scheduled at
      # that time, else false
      def delayed_push(timestamp, item)
        redis.zadd(:delayed_queue, timestamp.to_i, encode_with_nonce(item))
      end

      def decode_without_nonce(job)
        decode(job)&.delete_if {|k, _| k == 'nonce'}
      end

      def job_to_hash(klass, args)
        job_to_hash_with_queue(queue_from_class(klass), klass, args)
      end

      def job_to_hash_with_queue(queue, klass, args)
        { class: klass.to_s, args: args, queue: queue }
      end

      def encode_with_nonce(hash)
        encode(hash.merge(nonce: rand))
      end

      def remove_delayed_job(encoded_job)
        return 0 if Resque.inline?
        redis.zrem(:delayed_queue, [encoded_job])
      end

      def payload_matches_selection?(decoded_payload, klass)
        return false if decoded_payload.nil?
        job_class = decoded_payload['class']
        relevant_class = (klass.nil? || klass.to_s == job_class)
        relevant_class && yield(decoded_payload['args'])
      end

      def plugin
        Resque::Scheduler::Plugin
      end
    end
  end
end
