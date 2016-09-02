
module Resque
  module Scheduler
    class ScheduledJobMigrator
      def initialize(from_redis_url, to_redis_url)
        @from_redis_url = from_redis_url
        @to_redis_url = to_redis_url
      end

      def migrate!
        start_time = Time.now
        jobs = jobs_to_migrate
        puts "Migrating #{jobs.count} scheduled jobs."
        migrate_jobs(jobs)
        puts "Finished migrating in #{Time.now - start_time} seconds."
      end

      private

      def jobs_to_migrate
        Resque.redis = @from_redis_url

        number_of_timestamps = Resque.delayed_queue_schedule_size
        return [] if number_of_timestamps < 1
        Resque.delayed_queue_peek(0, number_of_timestamps).map do |timestamp|
          number_of_jobs = Resque.delayed_timestamp_size(timestamp)
          Resque.delayed_timestamp_peek(timestamp, 0, number_of_jobs).map do |job|
            job['timestamp'] = timestamp # add timestamp to the job hash
            job
          end
        end.flatten!
      end

      def migrate_jobs(jobs_to_migrate)
        Resque.redis = @to_redis_url

        jobs_to_migrate.each do |job_hash|
          Resque.enqueue_at(job_hash['timestamp'],
                            Util.constantize(job_hash['class']),
                            *job_hash['args'])
        end
      end
    end
  end
end
