module Resque
  module Scheduler
    class FailureHandler
      def self.on_enqueue_failure(_, e)
        Resque::Scheduler.log_error(
          "#{e.class.name}: #{e.message} #{e.backtrace.inspect}"
        )
      end
    end
  end
end
