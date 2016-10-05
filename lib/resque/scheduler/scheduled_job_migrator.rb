
module Resque
  module Scheduler
    class ScheduledJobMigrator
      def initialize(from_redis_url, to_redis_url)
        @from_redis_url = from_redis_url
        @to_redis_url = to_redis_url
      end

      def migrate!
        start_time = Time.now
        puts 'Migrating scheduled jobs.'
        Resque.redis = @from_redis_url
        jobs_by_timestamp = jobs_for_timestamps(timestamps_to_migrate)
        Resque.redis = @to_redis_url
        migrate_jobs(jobs_by_timestamp)
        puts "Finished migrating in #{Time.now - start_time} seconds."
      end

      private

      def timestamps_to_migrate
        Array(Resque.redis.zrange(:delayed_queue_schedule, 0, -1))
      end

      def jobs_for_timestamps(timestamps)
        jobs_by_timestamp = {}
        Resque.redis.pipelined do
          timestamps.each do |timestamp|
            key = "delayed:#{timestamp}"
            jobs_by_timestamp[timestamp] = Resque.redis.lrange(key, 0, -1)
          end
        end
        jobs_by_timestamp.each { |timestamp, jobs| jobs_by_timestamp[timestamp] = jobs.value }
      end

      def migrate_jobs(timestamps_jobs_hash)
        Resque.redis.pipelined do
          timestamps_jobs_hash.each do |timestamp, jobs|
            key = "delayed:#{timestamp}"
            jobs.each do |job|
              Resque.redis.sadd("timestamps:#{job}", key)
              Resque.redis.rpush(key, job)
            end
            Resque.redis.zadd('delayed_queue_schedule', timestamp, timestamp)
          end
        end
      end
    end
  end
end
