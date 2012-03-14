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

    def method_missing(method_name, *args, &block)
      if method_name =~ /^run_(.*)_hooks$/
        job = args.shift
        run_hooks job, $1, *args
      else
        super
      end
    end
  end
end
