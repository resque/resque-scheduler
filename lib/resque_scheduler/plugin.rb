module ResqueScheduler
  module Plugin
    extend self
    def hooks(job, pattern)
      job.methods.grep(/^#{pattern}/).sort
    end

    def run_hooks(job, pattern, *args)
      results = hooks(job, pattern).collect do |hook|
        job.send(hook, *args)
      end

      results.all? { |result| result != false }
    end

    def run_before_delayed_enqueue_hooks(klass, *args)
      run_hooks(klass, 'before_delayed_enqueue', *args)
    end

    def run_before_schedule_hooks(klass, *args)
      run_hooks(klass, 'before_schedule', *args)
    end

    def run_after_schedule_hooks(klass, *args)
      run_hooks(klass, 'after_schedule', *args)
    end
  end
end
