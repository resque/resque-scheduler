# vim:fileencoding=utf-8

module Resque
  module Scheduler
    module SchedulingExtensions
      # Accepts a new schedule configuration of the form:
      #
      #   {
      #     "MakeTea" => {
      #       "every" => "1m" },
      #     "some_name" => {
      #       "cron"        => "5/* * * *",
      #       "class"       => "DoSomeWork",
      #       "args"        => "work on this string",
      #       "description" => "this thing works it"s butter off" },
      #     ...
      #   }
      #
      # Hash keys can be anything and are used to describe and reference
      # the scheduled job. If the "class" argument is missing, the key
      # is used implicitly as "class" argument - in the "MakeTea" example,
      # "MakeTea" is used both as job name and resque worker class.
      #
      # Any jobs that were in the old schedule, but are not
      # present in the new schedule, will be removed.
      #
      # :cron can be any cron scheduling string
      #
      # :every can be used in lieu of :cron. see rufus-scheduler's 'every'
      # usage for valid syntax. If :cron is present it will take precedence
      # over :every.
      #
      # :class must be a resque worker class. If it is missing, the job name
      # (hash key) will be used as :class.
      #
      # :args can be any yaml which will be converted to a ruby literal and
      # passed in a params. (optional)
      #
      # :rails_envs is the list of envs where the job gets loaded. Envs are
      # comma separated (optional)
      #
      # :description is just that, a description of the job (optional). If
      # params is an array, each element in the array is passed as a separate
      # param, otherwise params is passed in as the only parameter to
      # perform.
      def schedule=(schedule_hash)
        @non_persistent_schedules = nil
        prepared_schedules = prepare_schedules(schedule_hash)

        prepared_schedules.each do |schedule, config|
          set_schedule(schedule, config, false)
        end

        # ensure only return the successfully saved data!
        reload_schedule!
      end

      # Returns the schedule hash
      def schedule
        @schedule ||= all_schedules
        @schedule || {}
      end

      # reloads the schedule from redis and memory
      def reload_schedule!
        @schedule = all_schedules
      end

      # gets the schedules as it exists in redis
      def all_schedules
        non_persistent_schedules.merge(persistent_schedules)
      end

      # Create or update a schedule with the provided name and configuration.
      #
      # Note: values for class and custom_job_class need to be strings,
      # not constants.
      #
      #    Resque.set_schedule('some_job', {:class => 'SomeJob',
      #                                     :every => '15mins',
      #                                     :queue => 'high',
      #                                     :args => '/tmp/poop'})
      #
      # Preventing a reload is optional and available to batch operations
      def set_schedule(name, config, reload = true)
        persist = config.delete(:persist) || config.delete('persist')

        if persist
          redis.hset(:persistent_schedules, name, encode(config))
        else
          non_persistent_schedules[name] = decode(encode(config))
        end

        redis.sadd(:schedules_changed, name)
        reload_schedule! if reload
      end

      # retrive the schedule configuration for the given name
      def fetch_schedule(name)
        schedule[name]
      end

      # remove a given schedule by name
      def remove_schedule(name)
        non_persistent_schedules.delete(name)
        redis.hdel(:persistent_schedules, name)
        redis.sadd(:schedules_changed, name)

        reload_schedule!
      end

      private

      # we store our non-persistent schedules in this hash
      def non_persistent_schedules
        @non_persistent_schedules ||= {}
      end

      # reads the persistent schedules from redis
      def persistent_schedules
        redis.hgetall(:persistent_schedules).tap do |h|
          h.each do |name, config|
            h[name] = decode(config)
          end
        end
      end

      def prepare_schedules(schedule_hash)
        prepared_hash = {}
        schedule_hash.each do |name, job_spec|
          job_spec = job_spec.dup
          unless job_spec.key?('class') || job_spec.key?(:class)
            job_spec['class'] = name
          end
          prepared_hash[name] = job_spec
        end
        prepared_hash
      end
    end
  end
end
