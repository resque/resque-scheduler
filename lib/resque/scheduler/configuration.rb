# vim:fileencoding=utf-8

module Resque
  module Scheduler
    module Configuration
      # Allows for block-style configuration
      def configure
        yield self
      end

      attr_writer :environment
      def environment
        @environment ||= ENV
      end

      # Used in `#load_schedule_job`
      attr_writer :env

      def env
        return @env if @env
        @env ||= Rails.env if defined?(Rails) && Rails.respond_to?(:env)
        @env ||= environment['RAILS_ENV']
        @env
      end

      # If true, logs more stuff...
      attr_writer :verbose

      def verbose
        @verbose ||= to_bool(environment['VERBOSE'])
      end

      # If set, produces no output
      attr_writer :quiet

      def quiet
        @quiet ||= to_bool(environment['QUIET'])
      end

      # If set, will write messages to the file
      attr_writer :logfile

      def logfile
        @logfile ||= environment['LOGFILE']
      end

      # Sets whether to log in 'text', 'json' or 'logfmt'
      attr_writer :logformat

      def logformat
        @logformat ||= environment['LOGFORMAT']
      end

      # If set, will try to update the schedule in the loop
      attr_writer :dynamic

      def dynamic
        @dynamic ||= to_bool(environment['DYNAMIC_SCHEDULE'])
      end

      # If set, will append the app name to procline
      attr_writer :app_name

      def app_name
        @app_name ||= environment['APP_NAME']
      end

      def delayed_requeue_batch_size
        @delayed_requeue_batch_size ||= \
          ENV['DELAYED_REQUEUE_BATCH_SIZE'].to_i if environment['DELAYED_REQUEUE_BATCH_SIZE']
        @delayed_requeue_batch_size ||= 100
      end

      # Amount of time in seconds to sleep between polls of the delayed
      # queue.  Defaults to 5
      attr_writer :poll_sleep_amount

      def poll_sleep_amount
        @poll_sleep_amount ||=
          Float(environment.fetch('RESQUE_SCHEDULER_INTERVAL', '5'))
      end

      private

      # Copied from https://github.com/rails/rails/blob/main/activemodel/lib/active_model/type/boolean.rb#L17
      TRUE_VALUES = [
        true, 1,
        '1', :'1',
        't', :t,
        'T', :T,
        'true', :true,
        'TRUE', :TRUE,
        'on', :on,
        'ON', :ON
      ].to_set.freeze

      def to_bool(value)
        TRUE_VALUES.include?(value)
      end
    end
  end
end
