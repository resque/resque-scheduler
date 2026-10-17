# vim:fileencoding=utf-8

module Resque
  module Scheduler
    module Plugin
      ENQUEUE_HOOKS = %i[delayed recurring].freeze

      def self.process_schedule_hooks(klass, *args)
        # the documentation states that if any before_schedule hook returns
        # false, the process should not be enqueued
        return unless run_before_schedule_hooks(klass, *args)

        yield
        run_after_schedule_hooks(klass, *args)
      end

      def self.process_recurring_hooks(klass, *args)
        return unless run_before_recurring_hooks(klass, *args)

        enqueued = yield
        run_after_recurring_hooks(klass, *args) if enqueued
        enqueued
      end

      def self.validate_enqueue_hooks(hooks)
        return if hooks.nil? || ENQUEUE_HOOKS.include?(hooks)

        raise ArgumentError, "unknown hooks: #{hooks.inspect}"
      end

      def self.process_enqueue_hooks(hooks, klass, *args, &block)
        case hooks
        when :delayed
          run_before_delayed_enqueue_hooks(klass, *args)
          yield
        when :recurring
          process_recurring_hooks(klass, *args, &block)
        else
          yield
        end
      end

      def self.hooks(job, pattern)
        job.methods.grep(/^#{pattern}/).sort
      end

      def self.run_hooks(job, pattern, *args)
        results = hooks(job, pattern).map do |hook|
          job.send(hook, *args)
        end

        results.all? { |result| result != false }
      end

      def self.run_before_delayed_enqueue_hooks(klass, *args)
        run_hooks(klass, 'before_delayed_enqueue', *args)
      end

      def self.run_before_schedule_hooks(klass, *args)
        run_hooks(klass, 'before_schedule', *args)
      end

      def self.run_after_schedule_hooks(klass, *args)
        run_hooks(klass, 'after_schedule', *args)
      end

      def self.run_before_recurring_hooks(klass, *args)
        run_hooks(klass, 'before_recurring', *args)
      end

      def self.run_after_recurring_hooks(klass, *args)
        run_hooks(klass, 'after_recurring', *args)
      end
    end
  end
end
